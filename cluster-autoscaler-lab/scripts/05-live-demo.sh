#!/usr/bin/env bash
# ==========================================================================
# 05-live-demo.sh — force Pending pods so a new NODE gets added, live
# --------------------------------------------------------------------------
# Creates a deployment big enough that the current nodes can't fit it, so
# some pods go Pending -> Cluster Autoscaler adds a node -> pods become
# Running. Watch it in the other terminals (see docs/03-live-demo.md).
#
# Idempotent: re-running just re-applies the same deployment.
#
# Usage:   ./05-live-demo.sh [replicas]      (default 30)
#          ./05-live-demo.sh --down          (remove the load, trigger scale-in)
# ==========================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

NAME="stress-test"

if [ "${1:-}" = "--down" ]; then
  echo "==> Removing '${NAME}' deployment. Nodes scale back in after ~10 min."
  kubectl delete deployment "${NAME}" --ignore-not-found
  exit 0
fi

REPLICAS="${1:-30}"

echo "==> Creating '${NAME}' with ${REPLICAS} replicas, each requesting cpu=200m mem=256Mi"
# create-or-update via apply so re-runs don't error.
kubectl create deployment "${NAME}" --image=nginx --replicas="${REPLICAS}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Setting resource requests (this is what makes pods unschedulable)..."
kubectl set resources deployment "${NAME}" --requests=cpu=200m,memory=256Mi

echo ""
echo "Now watch:"
echo "  Terminal 1:  watch -n 2 kubectl get nodes"
echo "  Terminal 2:  watch -n 2 'kubectl get pods'"
echo "  Terminal 3:  kubectl logs -f -n kube-system deployment/cluster-autoscaler \\"
echo "                 | grep -v 'static instance' | grep -iE 'scale|unschedul|node group'"
echo ""
echo "When done, scale in with:  ./05-live-demo.sh --down"
