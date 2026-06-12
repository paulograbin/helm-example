REGISTRY := app-fnd-public.common.repositories.cloud.sap
VERSION  := 0.0.4
PLATFORM := linux/amd64
IMG      := $(REGISTRY)/helm-operator:$(VERSION)

.PHONY: fmt vet test run install uninstall deploy undeploy apply-samples \
        docker-build docker-push all-operator status-operator logs help

# ─── Development ──────────────────────────────────────────────────────────────

fmt:           ## Run gofmt on all Go files
	go fmt ./...

vet:           ## Run go vet
	go vet ./...

test:          ## Run unit tests
	go test ./... -v -count=1

run:           ## Run the operator locally (uses current KUBECONFIG)
	go run ./main.go \
		--charts-root=../charts \
		--metrics-bind-address=:8082 \
		--health-probe-bind-address=:8083

# ─── CRD & RBAC ──────────────────────────────────────────────────────────────

install:       ## Apply the CRD and RBAC manifests to the cluster
	kubectl apply -f config/crd/
	kubectl apply -f config/rbac/

uninstall:     ## Remove the CRD from the cluster (destroys all HelmRelease objects)
	kubectl delete -f config/crd/ --ignore-not-found

# ─── Docker ───────────────────────────────────────────────────────────────────

docker-build:  ## Build the operator image (build context = repo root)
	docker build \
		--platform $(PLATFORM) \
		-f Dockerfile \
		-t $(IMG) \
		..

docker-push: docker-build  ## Build and push the operator image
	docker push $(IMG)

# ─── Cluster deployment ───────────────────────────────────────────────────────

deploy: install  ## Deploy the operator Deployment to the cluster
	kubectl apply -f config/manager/

undeploy:      ## Remove the operator Deployment from the cluster
	kubectl delete -f config/manager/ --ignore-not-found

apply-samples: ## Apply all three sample HelmRelease CRs
	kubectl apply -f config/samples/

all-operator: docker-push deploy apply-samples  ## Full cycle: build, push, deploy, apply samples

# ─── Status / debug ───────────────────────────────────────────────────────────

status-operator:  ## Show HelmRelease objects and operator pod status
	@echo "── HelmRelease objects ──"
	@kubectl get helmreleases -n helm-operator-system
	@echo ""
	@echo "── Operator pods ──"
	@kubectl get pods -n helm-operator-system

logs:          ## Tail operator logs
	kubectl logs -n helm-operator-system \
		deploy/helm-operator-controller-manager -f

# ─── Help ─────────────────────────────────────────────────────────────────────

help:          ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
