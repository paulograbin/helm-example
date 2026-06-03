#!/bin/bash
set -euo pipefail

echo "═══════════════════════════════════════════════════════════════"
echo "  Building and pushing Docker images"
echo "═══════════════════════════════════════════════════════════════"

# ─── Build ────────────────────────────────────────────────────────────────────
echo ""
echo "▶ [1/3] Building base image (Maven + all deps)..."
docker build -t base apps/base-image/

echo ""
echo "▶ [2/3] Building app-a..."
docker build -t app-a apps/app-a/

echo ""
echo "▶ [3/3] Building app-b..."
docker build -t app-b apps/app-b/

echo ""
echo "✓ All images built successfully"

# ─── Tag ──────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Tagging images for Artifactory..."
docker tag base app-fnd-public.common.repositories.cloud.sap/base:0.0.1
docker tag app-a app-fnd-public.common.repositories.cloud.sap/app-a:0.0.1
docker tag app-b app-fnd-public.common.repositories.cloud.sap/app-b:0.0.1
echo "✓ Tagged"

# ─── Push ─────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Pushing base:0.0.1..."
docker push app-fnd-public.common.repositories.cloud.sap/base:0.0.1

echo "▶ Pushing app-a:0.0.1..."
docker push app-fnd-public.common.repositories.cloud.sap/app-a:0.0.1

echo "▶ Pushing app-b:0.0.1..."
docker push app-fnd-public.common.repositories.cloud.sap/app-b:0.0.1

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✓ All images pushed to Artifactory"
echo "═══════════════════════════════════════════════════════════════"
