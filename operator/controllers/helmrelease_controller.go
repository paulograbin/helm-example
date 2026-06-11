package controllers

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-logr/logr"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	helmv1alpha1 "github.com/pgrabin/helm-example/operator/api/v1alpha1"
	helmrunner "github.com/pgrabin/helm-example/operator/internal/helm"
)

// HelmReleaseReconciler reconciles HelmRelease objects.
type HelmReleaseReconciler struct {
	client.Client
	Scheme *runtime.Scheme
	Log    logr.Logger
	Runner *helmrunner.Runner
}

func (r *HelmReleaseReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := r.Log.WithValues("helmrelease", req.NamespacedName)

	// 1. Fetch the HelmRelease object.
	var hr helmv1alpha1.HelmRelease
	if err := r.Get(ctx, req.NamespacedName, &hr); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// 2. Set status → Deploying immediately so observers see progress.
	patch := client.MergeFrom(hr.DeepCopy())
	hr.Status.Phase = helmv1alpha1.PhaseDeploying
	hr.Status.Message = ""
	if err := r.Status().Patch(ctx, &hr, patch); err != nil {
		return ctrl.Result{}, err
	}

	// 3. Decode spec.values from apiextensionsv1.JSON → map[string]interface{}.
	helmValues := make(map[string]interface{})
	for key, rawJSON := range hr.Spec.Values {
		var val interface{}
		if err := json.Unmarshal(rawJSON.Raw, &val); err != nil {
			log.Error(err, "Failed to decode values key", "key", key)
			return ctrl.Result{}, r.setStatus(ctx, &hr, helmv1alpha1.PhaseFailed,
				"failed to decode values["+key+"]: "+err.Error())
		}
		helmValues[key] = val
	}

	// 4. Determine timeout.
	timeout := time.Duration(hr.Spec.TimeoutSeconds) * time.Second
	if timeout == 0 {
		timeout = 120 * time.Second
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	// 5. Run helm upgrade --install via Helm SDK.
	log.Info("Running helm upgrade --install",
		"release", hr.Spec.ReleaseName,
		"chart", hr.Spec.ChartPath,
		"namespace", hr.Spec.Namespace,
	)
	if err := r.Runner.UpgradeInstall(
		runCtx,
		hr.Spec.ReleaseName,
		hr.Spec.ChartPath,
		hr.Spec.Namespace,
		helmValues,
		timeout,
	); err != nil {
		log.Error(err, "Helm upgrade --install failed")
		return ctrl.Result{}, r.setStatus(ctx, &hr, helmv1alpha1.PhaseFailed, err.Error())
	}

	// 6. Write final status → Deployed.
	log.Info("Helm release deployed successfully", "release", hr.Spec.ReleaseName)
	now := metav1.Now()
	patch = client.MergeFrom(hr.DeepCopy())
	hr.Status.Phase = helmv1alpha1.PhaseDeployed
	hr.Status.LastDeployed = &now
	hr.Status.Message = "Release " + hr.Spec.ReleaseName + " deployed successfully"
	return ctrl.Result{}, r.Status().Patch(ctx, &hr, patch)
}

// setStatus is a helper that patches the status and returns nil so the caller
// can return its result in one line without a requeue.
func (r *HelmReleaseReconciler) setStatus(ctx context.Context, hr *helmv1alpha1.HelmRelease, phase helmv1alpha1.Phase, msg string) error {
	patch := client.MergeFrom(hr.DeepCopy())
	hr.Status.Phase = phase
	hr.Status.Message = msg
	return r.Status().Patch(ctx, hr, patch)
}

func (r *HelmReleaseReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&helmv1alpha1.HelmRelease{}).
		Complete(r)
}
