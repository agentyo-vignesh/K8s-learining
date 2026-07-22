#!/usr/bin/env bash
# ==========================================================================
# cleanup.sh — remove everything this lab created
# --------------------------------------------------------------------------
# Deletes the demo load, the Cluster Autoscaler, and the credentials Secret.
# Idempotent (--ignore-not-found). Does NOT change your ASG min/max or tags,
# and does NOT touch your cluster nodes.
#
# Usage:   ./cleanup.sh
# ==========================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

echo "==> [1/3] Deleting the stress-test demo deployment..."
kubectl delete deployment stress-test --ignore-not-found

echo "==> [2/3] Deleting the Cluster Autoscaler (all 6 objects)..."
kubectl delete -f "${MANIFEST}" --ignore-not-found

echo "==> [3/3] Deleting the aws-credentials Secret..."
kubectl -n kube-system delete secret aws-credentials --ignore-not-found

echo ""
echo "Cleanup complete."
echo "NOTE: ASG tags and instance-group min/max were left as-is."
echo "      To reset node counts, edit them in kOps or the AWS console."
