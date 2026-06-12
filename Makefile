PLATFORM := linux/amd64
REGISTRY := app-fnd-public.common.repositories.cloud.sap
VERSION  := 0.0.2

.PHONY: all build push deploy clean help \
        build-base build-app-a build-app-b \
        push-base push-app-a push-app-b \
        restart status

# ─── Top-level targets ────────────────────────────────────────────────────────

all: render push deploy           ## Build, push, and deploy everything

build: build-base build-app-a build-app-b  ## Build all images

push: push-base push-app-a push-app-b     ## Push all images to registry

render: render-a render-b

#deploy:                    ## Deploy all charts to the cluster
#	kubectl apply -f namespaces.yaml
#	helm upgrade --install postgres ./charts/postgres --namespace backend --wait --timeout 180s
#	helm upgrade --install app-a ./charts/app-a --namespace backend --wait --timeout 120s
#	helm upgrade --install app-b ./charts/app-b --namespace frontend --wait --timeout 120s

# ─── Base image ───────────────────────────────────────────────────────────────

build-base:                ## Build the shared base image
	@echo "▶ Building base image..."
	docker build --platform $(PLATFORM) -t $(REGISTRY)/base:$(VERSION) apps/base-image/

push-base: build-base      ## Push base image (builds first if needed)
	@echo "▶ Pushing base image..."
	docker push $(REGISTRY)/base:$(VERSION)

# ─── App A ────────────────────────────────────────────────────────────────────

build-app-a: push-base     ## Build app-a (pushes base first — app-a pulls it from registry)
	@echo "▶ Building app-a..."
	docker build --platform $(PLATFORM) -t $(REGISTRY)/app-a:$(VERSION) apps/app-a/

push-app-a: build-app-a    ## Push app-a
	@echo "▶ Pushing app-a..."
	docker push $(REGISTRY)/app-a:$(VERSION)

render-a:
	@echo "Rendering CRD for app-a..."
	helm template app-a ./charts/app-a/ -n backend -f charts/app-a/values.yaml > rendered-a.yml

# ─── App B ────────────────────────────────────────────────────────────────────

build-app-b: push-base     ## Build app-b (pushes base first)
	@echo "▶ Building app-b..."
	docker build --platform $(PLATFORM) -t $(REGISTRY)/app-b:$(VERSION) apps/app-b/

push-app-b: build-app-b    ## Push app-b
	@echo "▶ Pushing app-b..."
	docker push $(REGISTRY)/app-b:$(VERSION)

render-b:
	helm template app-b ./charts/app-b/ -n backend -f charts/app-b/values.yaml > rendered-b.yml

# ─── Cluster operations ──────────────────────────────────────────────────────

restart:                   ## Restart all deployments to pick up new images
	kubectl rollout restart deployment app-a -n backend
	kubectl rollout restart deployment app-b -n frontend

status:                    ## Show pod status across both namespaces
	@echo "── backend ──"
	@kubectl get pods -n backend
	@echo ""
	@echo "── frontend ──"
	@kubectl get pods -n frontend

# ─── Operator ─────────────────────────────────────────────────────────────────

operator-install:          ## Install operator CRD + RBAC
	$(MAKE) -C operator install

operator-deploy:           ## Build, push, deploy operator and apply sample CRs
	$(MAKE) -C operator all-operator

operator-status:           ## Show HelmRelease objects and operator pod status
	$(MAKE) -C operator status-operator

operator-logs:             ## Tail operator logs
	$(MAKE) -C operator logs

# ─── Cleanup ──────────────────────────────────────────────────────────────────

clean:                     ## Uninstall all releases and delete namespaces
	-helm uninstall app-b -n frontend
	-helm uninstall app-a -n backend
	-helm uninstall postgres -n backend
	-kubectl delete -f namespaces.yaml

# ─── Help ─────────────────────────────────────────────────────────────────────

help:                      ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
