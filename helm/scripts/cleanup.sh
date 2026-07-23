#!/usr/bin/env bash
# ==========================================================================
# cleanup.sh — remove every release + the demo namespace
# --------------------------------------------------------------------------
# Idempotent: safe to run even if nothing is installed.
#
# Usage:   ./scripts/cleanup.sh
# ==========================================================================
set -euo pipefail
NS="demo"

echo "==> Uninstalling Helm releases in ${NS} (if any)..."
for rel in web app; do
  if helm status "${rel}" -n "${NS}" >/dev/null 2>&1; then
    echo "    uninstalling ${rel}..."
    helm uninstall "${rel}" -n "${NS}"
  fi
done

echo "==> Deleting namespace ${NS} (if it exists)..."
kubectl delete ns "${NS}" --ignore-not-found

echo "==> Remaining releases across all namespaces:"
helm list -A

echo ""
echo "Cleanup complete."
