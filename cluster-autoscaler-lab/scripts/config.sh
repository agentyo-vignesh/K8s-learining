#!/usr/bin/env bash
# ==========================================================================
# config.sh — shared settings for all cluster-autoscaler-lab scripts
# --------------------------------------------------------------------------
# Every other script does `source config.sh`, so edit your cluster details
# HERE in one place. You can also override any value with an environment
# variable, e.g.:  CLUSTER_NAME=my.k8s.local ./04-deploy.sh
# ==========================================================================

# Your kOps cluster name (matches the CA --node-group-auto-discovery tag).
export CLUSTER_NAME="${CLUSTER_NAME:-kops.k8s.local}"

# AWS region your cluster runs in.
export AWS_REGION="${AWS_REGION:-us-east-1}"

# The node ASGs (kOps instance groups) to enable autoscaling on.
# kOps names them <ig-name>.<cluster-name>. Space-separated list.
export ASG_NAMES="${ASG_NAMES:-nodes-${AWS_REGION}a.${CLUSTER_NAME} nodes-${AWS_REGION}b.${CLUSTER_NAME}}"

# Path to the CA manifest, relative to this scripts/ directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MANIFEST="${MANIFEST:-${SCRIPT_DIR}/../manifests/cluster-autoscaler.yaml}"

# Print the resolved config whenever a script starts (handy for students).
print_config() {
  echo "------------------------------------------------------------"
  echo " CLUSTER_NAME = ${CLUSTER_NAME}"
  echo " AWS_REGION   = ${AWS_REGION}"
  echo " ASG_NAMES    = ${ASG_NAMES}"
  echo "------------------------------------------------------------"
}
