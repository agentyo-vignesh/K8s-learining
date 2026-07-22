#!/usr/bin/env bash
# ==========================================================================
# watch.sh — live view of the HPA and the pods it manages
# --------------------------------------------------------------------------
# Runs `kubectl get --watch` so the terminal updates every time the HPA
# recommendation or the pod count changes. Leave this open in one terminal
# while you run load-test.sh in another and watch pods appear and disappear.
#
# Usage:   ./scripts/watch.sh              (watches the HPA, default)
#          ./scripts/watch.sh pods         (watches the pods instead)
# --------------------------------------------------------------------------
# TIP: For a combined dashboard that refreshes on a timer, use instead:
#   watch -n 2 'kubectl get hpa,pods'      (needs the 'watch' utility)
# `kubectl get --watch` (below) needs no extra tools and works everywhere.
# ==========================================================================
set -euo pipefail

TARGET="${1:-hpa}"

case "${TARGET}" in
  hpa)
    echo "==> Watching HPA 'php-apache' (Ctrl-C to stop). Columns: TARGETS shows current%/target%"
    kubectl get hpa php-apache --watch
    ;;
  pods)
    echo "==> Watching php-apache pods (Ctrl-C to stop)."
    kubectl get pods -l app=php-apache --watch
    ;;
  *)
    echo "Usage: $0 [hpa|pods]" >&2
    exit 1
    ;;
esac
