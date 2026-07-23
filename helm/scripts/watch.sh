#!/usr/bin/env bash
# ==========================================================================
# watch.sh — live view of everything in the demo namespace
# --------------------------------------------------------------------------
# Uses the `watch` utility if present, otherwise falls back to a plain loop.
#
# Usage:   ./scripts/watch.sh
# ==========================================================================
set -euo pipefail
NS="demo"

if command -v watch >/dev/null 2>&1; then
  watch -n 2 "kubectl get deploy,rs,pods,svc -n ${NS}"
else
  while true; do
    clear
    kubectl get deploy,rs,pods,svc -n "${NS}"
    sleep 2
  done
fi
