#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy the full helm-example stack to a Kyma cluster
#
# Prerequisites:
#   - kubectl configured and pointing at your Kyma cluster
#     (export KUBECONFIG=path/to/kubeconfig.yaml)
#   - helm v3 installed
#   - Docker images pushed to SAP Artifactory:
#     docker login common.repositories.cloud.sap
#     docker build -t common.repositories.cloud.sap/artifactory/app-fnd-public/app-a:1.0.0 ./apps/app-a
#     docker build -t common.repositories.cloud.sap/artifactory/app-fnd-public/app-b:1.0.0 ./apps/app-b
#     docker push common.repositories.cloud.sap/artifactory/app-fnd-public/app-a:1.0.0
#     docker push common.repositories.cloud.sap/artifactory/app-fnd-public/app-b:1.0.0
#   - Registry secret created in both namespaces (run once after namespaces exist):
#     kubectl create secret docker-registry artifactory-credentials \
#       --docker-server=common.repositories.cloud.sap \
#       --docker-username=I841059 \
#       --docker-password=REDACTED \
#       -n backend
#     kubectl create secret docker-registry artifactory-credentials \
#       --docker-server=common.repositories.cloud.sap \
#       --docker-username=I841059 \
#       --docker-password=REDACTED \
#       -n frontend
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Verify cluster connectivity ─────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  Deploying helm-example stack to Kyma"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "▶ Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot reach cluster. Check your KUBECONFIG."; exit 1; }

# ─── Step 1: Create namespaces ────────────────────────────────────────────────
echo ""
echo "▶ Creating namespaces..."
kubectl apply -f namespaces.yaml

# ─── Step 2: Deploy PostgreSQL ────────────────────────────────────────────────
echo ""
echo "▶ Deploying PostgreSQL to 'backend' namespace..."
helm upgrade --install postgres ./charts/postgres \
  --namespace backend \
  --wait \
  --timeout 180s

# ─── Step 3: Deploy App A ─────────────────────────────────────────────────────
echo ""
echo "▶ Deploying App A to 'backend' namespace..."
helm upgrade --install app-a ./charts/app-a \
  --namespace backend \
  --wait \
  --timeout 120s

# ─── Step 4: Deploy App B ─────────────────────────────────────────────────────
echo ""
echo "▶ Deploying App B to 'frontend' namespace..."
helm upgrade --install app-b ./charts/app-b \
  --namespace frontend \
  --wait \
  --timeout 120s

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✓ All components deployed!"
echo ""
echo "  Verify with:"
echo "    kubectl get pods -n backend"
echo "    kubectl get pods -n frontend"
echo ""
echo "  Test connectivity:"
echo "    # App B → App A (should work):"
echo "    kubectl exec -n frontend deploy/app-b -- wget -qO- http://app-a.backend.svc.cluster.local:8080/health"
echo ""
echo "    # App B → Postgres (should FAIL/timeout — blocked by NetworkPolicy):"
echo "    kubectl exec -n frontend deploy/app-b -- nc -zv -w3 postgres.backend.svc.cluster.local 5432"
echo ""
echo "    # App A → Postgres (should work):"
echo "    kubectl exec -n backend deploy/app-a -- nc -zv -w3 postgres.backend.svc.cluster.local 5432"
echo "═══════════════════════════════════════════════════════════════"
