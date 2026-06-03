#!/bin/bash
set -euo pipefail

PLATFORM="linux/amd64"
REGISTRY="app-fnd-public.common.repositories.cloud.sap"

echo "═══════════════════════════════════════════════════════════════"
echo "  Building and pushing Docker images (target: ${PLATFORM})"
echo "═══════════════════════════════════════════════════════════════"

# ─── Step 1: Build, tag, and push the base image FIRST ────────────────────────
# Apps reference the base via FROM <registry>/base:0.0.1, so it must be in the
# registry before the app builds can pull it.
echo ""
echo "▶ [1/5] Building base image (Maven + all deps)..."
docker build --platform ${PLATFORM} -t ${REGISTRY}/base:0.0.1 apps/base-image/

echo ""
echo "▶ [2/5] Pushing base image to registry..."
docker push ${REGISTRY}/base:0.0.1

# ─── Step 2: Build app images (they pull base from the registry) ──────────────
echo ""
echo "▶ [3/5] Building app-a..."
docker build --platform ${PLATFORM} -t ${REGISTRY}/app-a:0.0.1 apps/app-a/

echo ""
echo "▶ [4/5] Building app-b..."
docker build --platform ${PLATFORM} -t ${REGISTRY}/app-b:0.0.1 apps/app-b/

# ─── Step 3: Push app images ──────────────────────────────────────────────────
echo ""
echo "▶ [5/5] Pushing app images..."
docker push ${REGISTRY}/app-a:0.0.1
docker push ${REGISTRY}/app-b:0.0.1

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✓ All images pushed to ${REGISTRY}"
echo "═══════════════════════════════════════════════════════════════"
