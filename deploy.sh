#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy the full helm-example stack to your cluster
#
# Prerequisites:
#   - kubectl configured and pointing at your cluster
#   - helm v3 installed
#   - Docker images built and loaded into the cluster
#     (see README.md for image build instructions)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "═══════════════════════════════════════════════════════════════"
echo "  Deploying helm-example stack"
echo "═══════════════════════════════════════════════════════════════"

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
  --timeout 120s

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
