package helm

import (
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/client-go/discovery"
	"k8s.io/client-go/discovery/cached/memory"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/restmapper"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

// restClientGetter implements genericclioptions.RESTClientGetter using an
// in-cluster *rest.Config. Helm's action.Configuration.Init() requires this
// interface rather than a raw rest.Config.
type restClientGetter struct {
	config    *rest.Config
	namespace string
}

func newRESTClientGetter(config *rest.Config, namespace string) *restClientGetter {
	return &restClientGetter{config: config, namespace: namespace}
}

func (r *restClientGetter) ToRESTConfig() (*rest.Config, error) {
	return r.config, nil
}

func (r *restClientGetter) ToDiscoveryClient() (discovery.CachedDiscoveryInterface, error) {
	dc, err := discovery.NewDiscoveryClientForConfig(r.config)
	if err != nil {
		return nil, err
	}
	return memory.NewMemCacheClient(dc), nil
}

func (r *restClientGetter) ToRESTMapper() (meta.RESTMapper, error) {
	dc, err := r.ToDiscoveryClient()
	if err != nil {
		return nil, err
	}
	mapper := restmapper.NewDeferredDiscoveryRESTMapper(dc)
	return mapper, nil
}

func (r *restClientGetter) ToRawKubeConfigLoader() clientcmd.ClientConfig {
	return &namespaceClientConfig{namespace: r.namespace, config: r.config}
}

// namespaceClientConfig is a minimal clientcmd.ClientConfig that returns the
// operator's namespace for Helm's namespace-scoped operations.
type namespaceClientConfig struct {
	namespace string
	config    *rest.Config
}

func (n *namespaceClientConfig) RawConfig() (clientcmdapi.Config, error) {
	return clientcmdapi.Config{}, nil
}

func (n *namespaceClientConfig) ClientConfig() (*rest.Config, error) {
	return n.config, nil
}

func (n *namespaceClientConfig) Namespace() (string, bool, error) {
	return n.namespace, false, nil
}

func (n *namespaceClientConfig) ConfigAccess() clientcmd.ConfigAccess {
	return nil
}
