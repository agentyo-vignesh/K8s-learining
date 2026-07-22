#!/usr/bin/env bash
# ==========================================================================
# 02-create-secret.sh — create the aws-credentials Secret in kube-system
# --------------------------------------------------------------------------
# The Deployment reads AWS keys from a Secret named 'aws-credentials'.
# This script reads your keys from the environment (preferred) or falls back
# to `aws configure get`. Idempotent: it recreates the Secret each run.
#
# SECURITY: static keys are the beginner path. For production use IRSA or the
# node IAM role instead and DELETE this Secret (see docs/02-setup-guide.md).
#
# Usage:
#   AWS_ACCESS_KEY_ID=AKIA... AWS_SECRET_ACCESS_KEY=... ./02-create-secret.sh
#   # or, if `aws configure` is already set up, just:
#   ./02-create-secret.sh
# ==========================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Prefer env vars; otherwise pull from the local aws CLI profile.
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-$(aws configure get aws_access_key_id || true)}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-$(aws configure get aws_secret_access_key || true)}"

if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
  echo "ERROR: AWS keys not found. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY" >&2
  echo "       or configure the aws CLI first (aws configure)." >&2
  exit 1
fi

echo "==> Creating/updating Secret 'aws-credentials' in kube-system..."
# --dry-run|apply pattern = idempotent create-or-update (no error if it exists)
kubectl create secret generic aws-credentials \
  --namespace kube-system \
  --from-literal=aws_access_key_id="${AWS_ACCESS_KEY_ID}" \
  --from-literal=aws_secret_access_key="${AWS_SECRET_ACCESS_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Done. Verify (values are base64, not shown here):"
kubectl -n kube-system get secret aws-credentials
