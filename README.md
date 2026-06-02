# Helm Example: Two Java Apps + PostgreSQL

A hands-on Helm learning project demonstrating multi-namespace deployments,
cross-service communication, and NetworkPolicy enforcement.

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
```

## Prerequisites

- Docker
- kubectl configured against a cluster
- Helm v3
- A cluster with a NetworkPolicy-capable CNI (e.g., Calico, Cilium)
  - minikube: `minikube start --cni=calico`
  - kind: use Calico or Cilium addon

## Quick Start

### 1. Build Docker images

```bash
docker build -t app-a:latest ./apps/app-a
docker build -t app-b:latest ./apps/app-b
```

### 2. Load images into your local cluster

**kind:**
```bash
kind load docker-image app-a:latest app-b:latest
```

**minikube:**
```bash
minikube image load app-a:latest
minikube image load app-b:latest
```

### 3. Deploy everything

```bash
./deploy.sh
```

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
│   ├── app-a/          Java backend (Javalin + JDBC → PostgreSQL)
│   └── app-b/          Java frontend (Javalin + HttpClient → App A)
├── charts/
│   ├── app-a/          Helm chart: Deployment, Service, ConfigMap, Secret, NetworkPolicy
│   ├── app-b/          Helm chart: Deployment, Service, NetworkPolicy
│   └── postgres/       Helm chart: StatefulSet, Service, Secret, PVC, NetworkPolicy
├── namespaces.yaml     Namespace definitions
├── deploy.sh           One-command deploy
└── README.md           This file
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

## TODO (Your Contributions)

### 1. App A: Implement the database query methods

File: `apps/app-a/src/main/java/com/demo/AppA.java`

Implement `getItems()` and `createItem()` — the JDBC logic to read/write items.
The file has detailed hints and a skeleton to guide you.

### 2. PostgreSQL NetworkPolicy: Fill in the selector

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
| Non-root containers | `apps/*/Dockerfile` (USER appuser) |
