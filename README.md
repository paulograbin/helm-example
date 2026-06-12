# Helm Example: Two Java Apps + PostgreSQL

A hands-on Helm learning project demonstrating multi-namespace deployments,
cross-service communication, NetworkPolicy enforcement, and a custom Kubernetes operator.

## Architecture

```
┌─────────────────── namespace: backend ───────────────────┐
│                                                           │
│  ┌───────────┐   JDBC    ┌──────────────────┐            │
│  │  App A    │──────────▶│   PostgreSQL     │            │
│  │  (2 pods) │           │  (StatefulSet)   │            │
│  └─────▲─────┘           └──────────────────┘            │
│        │                          ▲                       │
└────────│──────────────────────────│───────────────────────┘
         │ HTTP :8080               │ ✗ BLOCKED
         │                          │   (NetworkPolicy)
┌────────│──────────────────────────│───────────────────────┐
│        │                          │                       │
│  ┌─────┴─────┐                    │                       │
│  │  App B    │────────────────────┘                       │
│  │  (2 pods) │  (cannot reach postgres)                   │
│  └───────────┘                                            │
│                                                           │
└─────────────────── namespace: frontend ──────────────────┘

┌─────────────────── namespace: helm-operator-system ───────┐
│  ┌──────────────────────────────────────────────┐         │
│  │  HelmRelease Operator                        │         │
│  │  watches HelmRelease CRs → helm upgrade      │         │
│  └──────────────────────────────────────────────┘         │
└───────────────────────────────────────────────────────────┘
```

## Prerequisites

- Docker
- kubectl configured against a Kyma cluster (`export KUBECONFIG=...`)
- Helm v3
- Go 1.22+ (for building the operator)
- Access to SAP Artifactory (`docker login app-fnd-public.common.repositories.cloud.sap`)

## Quick Start

### 1. Build and push Docker images

```bash
# Login to SAP Artifactory
docker login app-fnd-public.common.repositories.cloud.sap

# Build and push app-a and app-b
make push
```

### 2. Create registry pull secrets

The cluster needs credentials to pull from Artifactory.
**Important:** use `app-fnd-public.common.repositories.cloud.sap` as the server — not the root domain.

```bash
# Create namespaces first
kubectl apply -f namespaces.yaml

# Create the pull secret in both namespaces
kubectl create secret docker-registry artifactory-credentials \
  --docker-server=common.repositories.cloud.sap \
  --docker-username=YOUR_I_NUMBER \
  --docker-password=YOUR_ARTIFACTORY_TOKEN \
  -n backend

kubectl create secret docker-registry artifactory-credentials \
  --docker-server=common.repositories.cloud.sap \
  --docker-username=YOUR_I_NUMBER \
  --docker-password=YOUR_ARTIFACTORY_TOKEN \
  -n frontend
```

### 3. Deploy everything

```bash
make deploy
```

Or use the operator (see [Operator](#operator) section below).

### 4. Verify

```bash
# Check all pods are running
kubectl get pods -n backend
kubectl get pods -n frontend

# Test: App B → App A (should return "OK")
kubectl exec -n frontend deploy/app-b -- wget -qO- http://app-a.backend.svc.cluster.local:8080/health

# Test: App B → Postgres (should TIMEOUT — blocked by NetworkPolicy)
kubectl exec -n frontend deploy/app-b -- nc -zv -w3 postgres.backend.svc.cluster.local 5432

# Test: App A → Postgres (should SUCCEED)
kubectl exec -n backend deploy/app-a -- nc -zv -w3 postgres.backend.svc.cluster.local 5432
```

### 5. Monitor locally

Port-forward both apps and run the monitoring page:

```bash
kubectl port-forward svc/app-a 8080:8080 -n backend &
kubectl port-forward svc/app-b 8081:8080 -n frontend &
python3 proxy.py
# Open http://localhost:3000/monitor.html
```

## Project Structure

```
.
├── apps/
│   ├── app-a/          Java backend (Javalin + JDBC → PostgreSQL)
│   └── app-b/          Java frontend (Javalin + HttpClient → App A)
├── charts/
│   ├── app-a/          Helm chart: Deployment, Service, ConfigMap, Secret, NetworkPolicy
│   ├── app-b/          Helm chart: Deployment, Service, NetworkPolicy
│   └── postgres/       Helm chart: StatefulSet, Service, Secret, PVC, NetworkPolicy
├── operator/           HelmRelease Kubernetes operator (Go + controller-runtime)
├── namespaces.yaml     Namespace definitions
├── monitor.html        Local monitoring dashboard (polls /health, /version, /java)
├── proxy.py            Local proxy server — serves monitor.html and proxies to port-forwarded apps
├── deploy.sh           Verbose step-by-step deploy script
├── Makefile            Build, push, deploy, and operator targets
└── README.md           This file
```

## Components

| Component | What it does | Status |
|-----------|-------------|--------|
| **App A** | Backend REST API — owns DB access (`/health`, `/items` GET+POST) | Complete |
| **App B** | Frontend proxy — forwards `/data` to App A over HTTP | Complete |
| **Postgres chart** | StatefulSet, PVC, Secret, NetworkPolicy | TODO: NetworkPolicy selector is empty |
| **App-A chart** | Deployment, Service, ConfigMap, Secret, NetworkPolicy | Complete |
| **App-B chart** | Deployment, Service, egress NetworkPolicy | Complete |
| **Makefile** | Builds/pushes images, renders templates, deploys, operator targets | Complete |
| **deploy.sh** | Verbose step-by-step deploy with cluster connectivity check | Complete |
| **Operator** | HelmRelease CRD + controller — watches CRs and runs helm upgrade | Complete |

## Operator

The `operator/` directory contains a Kubernetes operator that manages Helm releases via a custom `HelmRelease` CRD. It enables a GitOps-style workflow: the app team bumps an image tag in a `HelmRelease` YAML, commits it, and the operator reconciles the change automatically.

### How it works

```
App team commits HelmRelease CR
        ↓
Operator watches for CR changes
        ↓
Runs helm upgrade --install via Helm SDK
        ↓
Updates CR status (Deploying → Deployed / Failed)
```

Charts are **bundled inside the operator image** at `/charts/` — updating a chart requires rebuilding and pushing the operator image.

### Operator structure

```
operator/
├── api/v1alpha1/           HelmRelease CRD Go types
├── controllers/            Reconcile loop
├── internal/helm/          Helm SDK wrapper (runner + RESTClientGetter)
├── config/
│   ├── crd/                CRD YAML manifest
│   ├── rbac/               ServiceAccount, ClusterRole, ClusterRoleBinding
│   ├── manager/            Operator Deployment
│   └── samples/            Example HelmRelease CRs for all three apps
├── main.go
└── Dockerfile              Multi-stage build, bundles charts/ from repo root
```

### Installing the operator

```bash
# 1. Build and push the operator image (build context = repo root)
make operator-deploy

# Or step by step:
cd operator
make docker-push       # build + push image
make install           # apply CRD + RBAC
kubectl apply -f config/manager/deployment.yaml
make apply-samples     # create HelmRelease CRs
```

**Prerequisites for the operator namespace:**

```bash
kubectl create namespace helm-operator-system

kubectl create secret docker-registry artifactory-credentials \
  --docker-server=app-fnd-public.common.repositories.cloud.sap \
  --docker-username=YOUR_I_NUMBER \
  --docker-password=YOUR_ARTIFACTORY_TOKEN \
  -n helm-operator-system
```

### Triggering a release (app team workflow)

Edit a sample CR and apply it:

```bash
# Bump the image tag for app-a
kubectl patch helmrelease app-a -n helm-operator-system \
  --type=merge -p '{"spec":{"values":{"image":{"tag":"0.0.2"}}}}'

# Watch reconciliation
kubectl get hr -n helm-operator-system -w
```

### Operator status

```bash
make operator-status    # show HelmRelease objects + operator pod
make operator-logs      # tail operator logs
```

## Common Helm Operations

```bash
# See what's deployed
helm list -A

# Check a specific release
helm status app-a -n backend

# View generated YAML without deploying (great for debugging)
helm template app-a ./charts/app-a -n backend

# Upgrade with new values (e.g., scale to 3 replicas)
helm upgrade app-a ./charts/app-a -n backend --set replicas=3

# Rollback to previous version
helm rollback app-a 1 -n backend

# View release history
helm history app-a -n backend

# Uninstall everything
helm uninstall app-b -n frontend
helm uninstall app-a -n backend
helm uninstall postgres -n backend
kubectl delete -f namespaces.yaml
```

## Endpoints

### External

No external endpoints are currently exposed. All services are `ClusterIP`.
To expose externally, create an Istio VirtualService pointing at `kyma-system/kyma-gateway`.
Cluster domain: `*.c-4a62d63.stage.kyma.ondemand.com`

### Internal

| Service | DNS | Port |
|---------|-----|------|
| App A | `app-a.backend.svc.cluster.local` | 8080 |
| App B | `app-b.frontend.svc.cluster.local` | 8080 |
| PostgreSQL | `postgres.backend.svc.cluster.local` | 5432 |

### App A API (`app-a.backend.svc.cluster.local:8080`)

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| `GET` | `/health` | Liveness/readiness probe | `200 OK` |
| `GET` | `/version` | Image tag | `200 {"version": "1.0.0"}` |
| `GET` | `/java` | JVM version | `200 {"java": "25.x.x"}` |
| `GET` | `/items` | List all items from PostgreSQL | `200` JSON array |
| `POST` | `/items` | Create item `{"name": "..."}` | `201` JSON object |

### App B API (`app-b.frontend.svc.cluster.local:8080`)

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| `GET` | `/health` | Liveness/readiness probe | `200 OK` |
| `GET` | `/version` | Image tag | `200 {"version": "1.0.0"}` |
| `GET` | `/java` | JVM version | `200 {"java": "25.x.x"}` |
| `GET` | `/data` | Proxy to App A `GET /items` | `200` JSON array |
| `POST` | `/data` | Proxy to App A `POST /items` | `201` JSON object |

## Key Concepts Demonstrated

| Concept | Where |
|---------|-------|
| Helm values + templating | `charts/*/values.yaml` → `templates/*.yaml` |
| ConfigMaps (non-sensitive config) | `charts/app-a/templates/configmap.yaml` |
| Secrets (sensitive config) | `charts/*/templates/secret.yaml` |
| StatefulSet (for databases) | `charts/postgres/templates/statefulset.yaml` |
| Cross-namespace DNS | App B → `app-a.backend.svc.cluster.local` |
| NetworkPolicy (ingress) | `charts/postgres/templates/networkpolicy.yaml` |
| NetworkPolicy (egress) | `charts/app-b/templates/networkpolicy.yaml` |
| Liveness/readiness probes | All deployment templates |
| Multi-stage Docker builds | `apps/*/Dockerfile` |
| Non-root containers | `apps/*/Dockerfile` (USER appuser) |
| SAP Artifactory registry | `charts/*/values.yaml` (image.repository) |
| Istio sidecar opt-out | `charts/postgres/templates/statefulset.yaml` |
| Custom Kubernetes operator | `operator/` — HelmRelease CRD + controller-runtime |
| Operator RBAC | `operator/config/rbac/` |
| GitOps-style release workflow | `operator/config/samples/` + HelmRelease CRs |
