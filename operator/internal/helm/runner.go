package helm

import (
	"context"
	"path/filepath"
	"time"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
	"helm.sh/helm/v3/pkg/storage/driver"
	"k8s.io/client-go/rest"
)

// ChartsRoot is the base directory under which chart subdirectories live.
// Set from the --charts-root CLI flag in main.go.
var ChartsRoot string

// Runner wraps the Helm SDK and exposes a single UpgradeInstall method.
// Keeping all Helm SDK imports here makes the controller itself mockable in tests.
type Runner struct {
	restConfig *rest.Config
}

// NewRunner creates a Runner using the given in-cluster REST config.
func NewRunner(restConfig *rest.Config) *Runner {
	return &Runner{restConfig: restConfig}
}

// UpgradeInstall performs a helm upgrade --install for the given release.
// chartSubPath is spec.chartPath (e.g. "app-a"), resolved against ChartsRoot.
// values is the decoded map[string]interface{} from spec.values.
func (r *Runner) UpgradeInstall(
	ctx context.Context,
	releaseName string,
	chartSubPath string,
	namespace string,
	values map[string]interface{},
	timeout time.Duration,
) error {
	actionCfg := new(action.Configuration)
	if err := actionCfg.Init(
		newRESTClientGetter(r.restConfig, namespace),
		namespace,
		"secret",                                 // store release history in Secrets (standard Helm behaviour)
		func(format string, v ...interface{}) {}, // discard Helm's internal log
	); err != nil {
		return err
	}

	chartPath := filepath.Join(ChartsRoot, chartSubPath)
	chart, err := loader.Load(chartPath)
	if err != nil {
		return err
	}

	// Check whether the release already exists to choose Install vs Upgrade.
	histClient := action.NewHistory(actionCfg)
	histClient.Max = 1
	_, histErr := histClient.Run(releaseName)

	if histErr == driver.ErrReleaseNotFound {
		install := action.NewInstall(actionCfg)
		install.ReleaseName = releaseName
		install.Namespace = namespace
		install.Wait = true
		install.Timeout = timeout
		install.CreateNamespace = true
		_, err = install.RunWithContext(ctx, chart, values)
	} else if histErr == nil {
		upgrade := action.NewUpgrade(actionCfg)
		upgrade.Namespace = namespace
		upgrade.Wait = true
		upgrade.Timeout = timeout
		_, err = upgrade.RunWithContext(ctx, releaseName, chart, values)
	} else {
		err = histErr
	}

	return err
}
