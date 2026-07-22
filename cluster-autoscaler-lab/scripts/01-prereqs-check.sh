#!/usr/bin/env bash
# ==========================================================================
# 01-prereqs-check.sh — confirm the cluster & tools are ready
# --------------------------------------------------------------------------
# Idempotent: read-only checks, safe to run any time.
# Usage:   ./01-prereqs-check.sh
# ==========================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
print_config

echo "==> [1/4] Checking required CLIs are installed..."
for cli in kops kubectl aws; do
  if command -v "$cli" >/dev/null 2>&1; then
    echo "    OK: $cli found"
  else
    echo "    MISSING: $cli is not on your PATH" >&2
    exit 1
  fi
done

echo "==> [2/4] Validating the kOps cluster..."
kops validate cluster --name "${CLUSTER_NAME}"

echo "==> [3/4] Listing nodes..."
kubectl get nodes

echo "==> [4/4] Checking AWS credentials work..."
aws sts get-caller-identity --region "${AWS_REGION}" --output table

echo ""
echo "All prerequisites look good. Next: set maxSize>minSize (see docs/02),"
echo "then run ./02-create-secret.sh"
