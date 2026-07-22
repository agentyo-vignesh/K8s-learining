#!/usr/bin/env bash
# ==========================================================================
# load-test.sh — generate CPU load against the php-apache service
# --------------------------------------------------------------------------
# Launches a busybox pod named "load-generator" that hammers the php-apache
# Service in a tight loop. Each request runs a CPU-heavy PHP calculation, so
# the fleet's CPU utilization climbs and the HPA scales php-apache out.
#
# Idempotent: if a previous load-generator pod exists, it is deleted first.
# Stop the test at any time with Ctrl-C (the pod is cleaned up on exit).
#
# Usage:   ./scripts/load-test.sh
# ==========================================================================
set -euo pipefail

POD_NAME="load-generator"
TARGET_URL="http://php-apache"

# If an old load generator is hanging around, remove it so we start clean.
if kubectl get pod "${POD_NAME}" >/dev/null 2>&1; then
  echo "==> Removing existing '${POD_NAME}' pod for a clean run..."
  kubectl delete pod "${POD_NAME}" --ignore-not-found --now
fi

# Make sure we clean up the pod if the user presses Ctrl-C.
cleanup() {
  echo ""
  echo "==> Stopping load test and deleting '${POD_NAME}'..."
  kubectl delete pod "${POD_NAME}" --ignore-not-found --now || true
}
trap cleanup INT TERM

echo "==> Starting load generator against ${TARGET_URL}"
echo "    Watch scaling in another terminal with: ./scripts/watch.sh"
echo "    Press Ctrl-C here to stop generating load."
echo ""

# -it + --rm gives us a foreground pod that is deleted when the command ends.
# The inner shell loop sends requests forever with no delay = maximum pressure.
kubectl run "${POD_NAME}" \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -it \
  -- /bin/sh -c "while true; do wget -q -O- ${TARGET_URL}; done"
