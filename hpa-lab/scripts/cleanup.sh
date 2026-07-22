#!/usr/bin/env bash
# ==========================================================================
# cleanup.sh — remove everything this lab created
# --------------------------------------------------------------------------
# Deletes the HPAs, the load-generator pod, and the php-apache deployment +
# service. Idempotent: uses --ignore-not-found so re-running is harmless.
#
# The minikube cluster and the metrics-server addon are LEFT RUNNING so you
# can immediately re-run ./scripts/setup.sh. To also stop the cluster, run:
#   minikube stop        (keeps the VM, fast restart)
#   minikube delete      (destroys the VM entirely)
#
# Usage:   ./scripts/cleanup.sh
# ==========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$(cd "${SCRIPT_DIR}/../manifests" && pwd)"

echo "==> [1/3] Deleting the load-generator pod (if present)..."
kubectl delete pod load-generator --ignore-not-found --now

echo "==> [2/3] Deleting HPAs (basic + advanced)..."
kubectl delete hpa php-apache --ignore-not-found
kubectl delete hpa php-apache-advanced --ignore-not-found

echo "==> [3/3] Deleting the php-apache deployment and service..."
kubectl delete -f "${MANIFESTS_DIR}/deployment.yaml" --ignore-not-found

echo ""
echo "============================================================"
echo " Cleanup complete. Remaining lab resources (should be empty):"
echo "============================================================"
kubectl get deploy,svc,hpa,pods -l app=php-apache || true
echo ""
echo "The minikube cluster is still running. To stop it: minikube stop"
