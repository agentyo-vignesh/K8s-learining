#!/usr/bin/env bash
# ==========================================================================
# deploy-bitnami.sh — Phase 1: install nginx from the bitnami repo
# --------------------------------------------------------------------------
# Adds the bitnami repo, installs the nginx chart as release "web" into the
# "demo" namespace, then upgrades it to 3 replicas. Idempotent-ish: re-running
# will upgrade the existing release.
#
# Usage:   ./scripts/deploy-bitnami.sh
# ==========================================================================
set -euo pipefail

NS="demo"
RELEASE="web"
CHART="bitnami/nginx"

echo "==> [1/5] Adding + updating the bitnami repo..."
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo update bitnami

echo "==> [2/5] Installing (or upgrading) ${RELEASE} from ${CHART}..."
helm upgrade --install "${RELEASE}" "${CHART}" \
  -n "${NS}" --create-namespace \
  --wait --timeout 5m

echo "==> [3/5] Current state:"
kubectl get all -n "${NS}"

echo "==> [4/5] Scaling to 3 replicas..."
helm upgrade "${RELEASE}" "${CHART}" -n "${NS}" \
  --set replicaCount=3 --reuse-values --wait

kubectl get pods -n "${NS}"

echo "==> [5/5] Release history:"
helm history "${RELEASE}" -n "${NS}"

echo ""
echo "Public URL (AWS ELB, may take ~2-3 min to resolve):"
echo "  http://$(kubectl get svc ${RELEASE}-nginx -n ${NS} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)"
echo ""
echo "Rollback to revision 1 with:  helm rollback ${RELEASE} 1 -n ${NS} --wait"
echo "Tear down with:               ./scripts/cleanup.sh"
