#!/usr/bin/env bash
# ==========================================================================
# setup.sh — bring up the whole lab environment
# --------------------------------------------------------------------------
# Idempotent: safe to run again. It will start minikube only if it is not
# already running, enable metrics-server only if needed, wait until
# `kubectl top` returns real data, then (re)apply the demo manifests.
#
# Usage:   ./scripts/setup.sh
# ==========================================================================
set -euo pipefail

# Resolve the repo root so the script works no matter where it is called from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$(cd "${SCRIPT_DIR}/../manifests" && pwd)"

echo "==> [1/5] Checking minikube status..."
if minikube status --format '{{.Host}}' 2>/dev/null | grep -q "Running"; then
  echo "    minikube is already running. Skipping start."
else
  echo "    Starting minikube..."
  minikube start
fi

echo "==> [2/5] Enabling the metrics-server addon (safe if already enabled)..."
minikube addons enable metrics-server

echo "==> [3/5] Waiting for the metrics-server deployment to become Available..."
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s

echo "==> [4/5] Waiting until 'kubectl top nodes' returns metrics..."
echo "    (metrics-server needs ~30-60s to collect its first samples)"
for i in $(seq 1 30); do
  if kubectl top nodes >/dev/null 2>&1; then
    echo "    Metrics are flowing. 'kubectl top' works."
    break
  fi
  echo "    ...still warming up (attempt ${i}/30), sleeping 10s"
  sleep 10
  if [ "${i}" -eq 30 ]; then
    echo "    ERROR: metrics-server never became ready. See docs/03-troubleshooting.md" >&2
    exit 1
  fi
done

echo "==> [5/5] Applying demo manifests (deployment + service + basic HPA)..."
kubectl apply -f "${MANIFESTS_DIR}/deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/hpa-basic.yaml"

echo "    Waiting for the php-apache deployment to become Available..."
kubectl rollout status deployment/php-apache --timeout=120s

echo ""
echo "============================================================"
echo " Setup complete! Current state:"
echo "============================================================"
kubectl get deployment php-apache
kubectl get hpa php-apache
echo ""
echo "Next: run  ./scripts/watch.sh   in one terminal, then"
echo "      run  ./scripts/load-test.sh   in another to trigger scaling."
