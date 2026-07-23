#!/usr/bin/env bash
# ==========================================================================
# deploy-mychart.sh — install the custom local chart (charts/myapp)
# --------------------------------------------------------------------------
# Lints, renders, dry-runs, then installs your own chart as release "app"
# into the "demo" namespace.
#
# Usage:   ./scripts/deploy-mychart.sh
# ==========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/../charts/myapp" && pwd)"
NS="demo"
RELEASE="app"

echo "==> [1/4] Linting the chart..."
helm lint "${CHART_DIR}"

echo "==> [2/4] Rendering templates locally (no cluster needed)..."
helm template "${RELEASE}" "${CHART_DIR}" | head -60

echo "==> [3/4] Dry-run against the cluster..."
helm install "${RELEASE}" "${CHART_DIR}" -n "${NS}" --create-namespace --dry-run --debug >/dev/null
echo "    dry-run OK."

echo "==> [4/4] Installing for real..."
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  -n "${NS}" --create-namespace \
  --wait --timeout 5m

kubectl get all -n "${NS}"

echo ""
echo "Override a value:   helm upgrade ${RELEASE} ${CHART_DIR} -n ${NS} --set replicaCount=3 --wait"
echo "Tear down with:     ./scripts/cleanup.sh"
