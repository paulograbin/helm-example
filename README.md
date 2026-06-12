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
- A cluster with a NetworkPolicy-capable CNI (Kyma uses Calico/Cilium by default)

## Quick Start

### 1. Build Docker images

Images use a shared base layer that provides the JRE and non-root user setup.
The base image **must be built and pushed first** — app images depend on it.

```bash
# Login to SAP Artifactory
docker login common.repositories.cloud.sap

# Build and push the shared base image
docker build -t common.repositories.cloud.sap/artifactory/app-fnd-public/base:0.0.1 ./apps/base-image
docker push common.repositories.cloud.sap/artifactory/app-fnd-public/base:0.0.1

# Build and push the app images (they FROM the base image above)
docker build -t common.repositories.cloud.sap/artifactory/app-fnd-public/app-a:0.0.1 ./apps/app-a
docker build -t common.repositories.cloud.sap/artifactory/app-fnd-public/app-b:0.0.1 ./apps/app-b
docker push common.repositories.cloud.sap/artifactory/app-fnd-public/app-a:0.0.1
docker push common.repositories.cloud.sap/artifactory/app-fnd-public/app-b:0.0.1
```

### 2. Create registry pull secrets

The cluster needs credentials to pull from Artifactory:

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

## Project Structure

```
.
├── apps/
│   ├── base-image/     Shared base Docker image (JRE 17 + non-root user)
│   ├── app-a/          Java backend (Javalin + JDBC → PostgreSQL)
│   └── app-b/          Java frontend (Javalin + HttpClient → App A)
├── charts/
│   ├── app-a/          Helm chart: Deployment, Service, ConfigMap, Secret, NetworkPolicy
│   ├── app-b/          Helm chart: Deployment, Service, NetworkPolicy
│   └── postgres/       Helm chart: StatefulSet, Service, Secret, PVC, NetworkPolicy
├── operator/           HelmRelease Kubernetes operator (Go + controller-runtime)
├── namespaces.yaml     Namespace definitions
├── deploy.sh           Verbose step-by-step deploy script
├── Makefile            Build, push, deploy, and operator targets
└── README.md           This file
```

## Components

| Component | What it does | Status |
|-----------|-------------|--------|
| **base-image** | Maven build stage with all deps pre-cached (eclipse-temurin:17) | Complete |
| **App A** | Backend REST API — owns DB access (`/health`, `/items` GET+POST) | Complete |
| **App B** | Frontend proxy — forwards `/data` to App A over HTTP | Complete |
| **Postgres chart** | StatefulSet, PVC, Secret, NetworkPolicy | TODO: NetworkPolicy selector is empty |
| **App-A chart** | Deployment, Service, ConfigMap, Secret, NetworkPolicy | Complete |
| **App-B chart** | Deployment, Service, egress NetworkPolicy | Complete |
| **Makefile** | Builds/pushes images, renders templates, deploys, operator targets | Complete |
| **deploy.sh** | Verbose step-by-step deploy with cluster connectivity check | Complete |
| **Operator** | HelmRelease CRD + controller — watches CRs and runs helm upgrade | Complete |

## Docker Image Strategy

```
┌─────────────────────────────────────────────┐
│         eclipse-temurin:17-jre-jammy         │  ← upstream (Adoptium)
└─────────────────────┬───────────────────────┘
                      │
┌─────────────────────▼───────────────────────┐
│              base:0.0.1                      │  ← our shared base
│  (WORKDIR /app, non-root user, EXPOSE 8080) │     apps/base-image/Dockerfile
└───────────┬─────────────────────┬───────────┘
            │                     │
┌───────────▼───────────┐  ┌─────▼─────────────────┐
│     app-a:0.0.1       │  │     app-b:0.0.1       │
│  (+ app-a-1.0.0.jar)  │  │  (+ app-b-1.0.0.jar)  │
└───────────────────────┘  └───────────────────────┘
```

**Why a shared base image?**
- **Single point of update**: upgrade JRE or patch a CVE in one place
- **Faster pulls**: K8s nodes cache shared layers — only the thin app JAR layer differs
- **Consistency**: all services run with identical runtime configuration

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

## TODO

### PostgreSQL NetworkPolicy: Fill in the selector

File: `charts/postgres/templates/networkpolicy.yaml`

Complete the NetworkPolicy that restricts Postgres access to only App A.
The file has a TODO section explaining what's needed.

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
| Shared base image | `apps/base-image/Dockerfile` → used by app-a and app-b |
| Non-root containers | `apps/base-image/Dockerfile` (USER appuser) |
| SAP Artifactory registry | `charts/*/values.yaml` (image.repository) |
| Istio sidecar opt-out | `charts/postgres/templates/statefulset.yaml` |
| Custom Kubernetes operator | `operator/` — HelmRelease CRD + controller-runtime |
| Operator RBAC | `operator/config/rbac/` |
| GitOps-style release workflow | `operator/config/samples/` + HelmRelease CRs |
