#!/usr/bin/env bash
# ==========================================================================
# deploy-webapp.sh — install the PRODUCTION-GRADE chart (charts/webapp)
# --------------------------------------------------------------------------
# Lints, renders, dry-runs, installs, then runs the chart's own helm test.
#
# Usage:   ./scripts/deploy-webapp.sh
# ==========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/../charts/webapp" && pwd)"
NS="demo"
RELEASE="web"

echo "==> [1/5] Linting..."
helm lint "${CHART_DIR}"

echo "==> [2/5] Rendering (default) — object kinds produced:"
helm template "${RELEASE}" "${CHART_DIR}" | grep -E '^kind:'

echo "==> [3/5] Dry-run against the cluster..."
helm install "${RELEASE}" "${CHART_DIR}" -n "${NS}" --create-namespace --dry-run --debug >/dev/null
echo "    dry-run OK."

echo "==> [4/5] Installing..."
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  -n "${NS}" --create-namespace \
  --wait --timeout 5m

kubectl get all -n "${NS}"

echo "==> [5/5] Running the chart's helm test..."
helm test "${RELEASE}" -n "${NS}" || echo "    (test pod result above)"

echo ""
echo "Prod mode (HPA + Ingress):"
echo "  helm upgrade ${RELEASE} ${CHART_DIR} -n ${NS} --set autoscaling.enabled=true --set ingress.enabled=true --wait"
echo "Public URL (AWS ELB, ~2-3 min):"
echo "  echo \"http://\$(kubectl get svc ${RELEASE}-webapp -n ${NS} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')\""
echo "Tear down:  ./scripts/cleanup.sh"
