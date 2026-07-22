#!/usr/bin/env bash
# ==========================================================================
# 03-tag-asgs.sh — tag the node ASGs so Cluster Autoscaler can discover them
# --------------------------------------------------------------------------
# CA finds ASGs via two tags. Without them you get "NotTriggerScaleUp /
# 0 ASGs" and no node is ever added. create-or-update-tags is idempotent.
#
# Usage:   ./03-tag-asgs.sh
# ==========================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
print_config

echo "==> Tagging ASGs for cluster '${CLUSTER_NAME}'..."
for ASG in ${ASG_NAMES}; do
  echo "    -> ${ASG}"
  aws autoscaling create-or-update-tags \
    --region "${AWS_REGION}" \
    --tags \
      "ResourceId=${ASG},ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=true" \
      "ResourceId=${ASG},ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/${CLUSTER_NAME},Value=owned,PropagateAtLaunch=true"
  echo "       tags added for ${ASG}"
done

echo ""
echo "==> Verifying tags on the first ASG..."
FIRST_ASG="$(echo ${ASG_NAMES} | awk '{print $1}')"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${FIRST_ASG}" \
  --region "${AWS_REGION}" \
  --query 'AutoScalingGroups[*].Tags[?starts_with(Key, `k8s.io/cluster-autoscaler`)].[Key,Value]' \
  --output table

echo ""
echo "Expected two tags: .../enabled=true  and  .../${CLUSTER_NAME}=owned"
