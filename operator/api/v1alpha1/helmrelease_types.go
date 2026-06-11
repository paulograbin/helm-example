package v1alpha1

import (
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Phase represents the lifecycle state of a HelmRelease.
type Phase string

const (
	PhasePending   Phase = "Pending"
	PhaseDeploying Phase = "Deploying"
	PhaseDeployed  Phase = "Deployed"
	PhaseFailed    Phase = "Failed"
)

// HelmReleaseSpec defines the desired state of a HelmRelease.
type HelmReleaseSpec struct {
	// ChartPath is the chart subdirectory name relative to the charts root
	// mounted inside the operator pod (e.g. "app-a" → /charts/app-a).
	ChartPath string `json:"chartPath"`

	// ReleaseName is the Helm release name passed to upgrade --install.
	ReleaseName string `json:"releaseName"`

	// Namespace is the target Kubernetes namespace for the Helm release.
	Namespace string `json:"namespace"`

	// Values is a free-form map of Helm value overrides merged on top of chart defaults.
	// +optional
	Values map[string]apiextensionsv1.JSON `json:"values,omitempty"`

	// TimeoutSeconds is the per-reconcile Helm operation timeout. Defaults to 120.
	// +optional
	TimeoutSeconds int `json:"timeoutSeconds,omitempty"`
}

// HelmReleaseStatus reflects the observed state of a HelmRelease.
type HelmReleaseStatus struct {
	// Phase is the lifecycle phase of this release.
	Phase Phase `json:"phase,omitempty"`

	// LastDeployed is the timestamp of the most recent successful deployment.
	// +optional
	LastDeployed *metav1.Time `json:"lastDeployed,omitempty"`

	// Message is a human-readable description of the current state.
	// +optional
	Message string `json:"message,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Namespaced,shortName=hr
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Release",type=string,JSONPath=`.spec.releaseName`
// +kubebuilder:printcolumn:name="LastDeployed",type=date,JSONPath=`.status.lastDeployed`

// HelmRelease is the Schema for the helmreleases API.
type HelmRelease struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   HelmReleaseSpec   `json:"spec,omitempty"`
	Status HelmReleaseStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// HelmReleaseList contains a list of HelmRelease.
type HelmReleaseList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []HelmRelease `json:"items"`
}
