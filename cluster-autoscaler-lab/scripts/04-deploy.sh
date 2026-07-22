#!/usr/bin/env bash
# ==========================================================================
# 04-deploy.sh — deploy Cluster Autoscaler and confirm it is healthy
# --------------------------------------------------------------------------
# Applies the manifest, waits for the rollout, and tails the startup logs so
# you can confirm success. Idempotent: apply is safe to re-run.
#
# Usage:   ./04-deploy.sh
# ==========================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Guard: the manifest must reference THIS cluster name, or discovery fails.
if ! grep -q "${CLUSTER_NAME}" "${MANIFEST}"; then
  echo "WARNING: '${CLUSTER_NAME}' not found in ${MANIFEST}." >&2
  echo "         Edit the --node-group-auto-discovery line to match your cluster." >&2
fi

echo "==> [1/3] Applying the Cluster Autoscaler manifest..."
kubectl apply -f "${MANIFEST}"

echo "==> [2/3] Waiting for the deployment to roll out..."
kubectl -n kube-system rollout status deployment/cluster-autoscaler --timeout=120s

echo "==> [3/3] Pod status:"
kubectl -n kube-system get pods -l app=cluster-autoscaler

echo ""
echo "============================================================"
echo " Tailing startup logs (Ctrl-C to stop). Look for:"
echo "   'Registered ASGs' / 'Starting main loop'  = SUCCESS"
echo "   'MissingRegion' / 'NoCredentialProviders' = see docs/04"
echo "============================================================"
# 'static instance' lines are the 1000+ EC2 instance-type dump — hide them.
kubectl -n kube-system logs -f deployment/cluster-autoscaler \
  | grep -v "static instance"
