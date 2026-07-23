#!/usr/bin/env bash
# ==========================================================================
# install-helm.sh — install Helm 3 on the kOps admin box / VM
# --------------------------------------------------------------------------
# Idempotent: if helm is already on PATH it just prints the version and exits.
# Uses the official get-helm-3 script.
#
# Usage:   ./scripts/install-helm.sh
# ==========================================================================
set -euo pipefail

echo "==> [1/3] Checking for an existing helm..."
if command -v helm >/dev/null 2>&1; then
  echo "    helm already installed: $(helm version --short)"
  exit 0
fi

echo "==> [2/3] Downloading and running the official Helm 3 installer..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh
chmod +x get_helm.sh
./get_helm.sh

echo "==> [3/3] Verifying..."
helm version

echo ""
echo "Helm is ready. Next:  ./scripts/deploy-bitnami.sh"
