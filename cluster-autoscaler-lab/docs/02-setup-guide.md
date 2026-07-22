# 02 — kOps Cluster Autoscaler Setup (Step by Step)

> The hands-on part. Follow each step in order. Every command has a one-line
> comment above it and an expected-output sample where it matters.
>
> Throughout, replace `kops.k8s.local` with your cluster name and `us-east-1`
> with your region. The scripts in `scripts/` do all of this for you — this
> guide explains what each script does so you understand it.

---

## Prerequisites

You need:
- ✅ A running kOps cluster (example: `kops.k8s.local`)
- ✅ `kubectl` connected to it
- ✅ AWS admin credentials configured for the `aws` CLI
- ✅ `kops` and `aws` CLIs installed

```bash
# Confirm the cluster is healthy and reachable
kops validate cluster --name kops.k8s.local
kubectl get nodes
```
**Sample output**
```
NAME                          STATUS   ROLES           AGE   VERSION
i-0abc... (control-plane)     Ready    control-plane   1h    v1.32.1
i-0def... (nodes-us-east-1a)  Ready    node            1h    v1.32.1
```
> 💡 Script shortcut: `./scripts/01-prereqs-check.sh`

---

## STEP 1 — Set Min/Max on the instance groups

CA can only scale **within** the ASG's min/max. If `maxSize == minSize` there
is no room to grow, so **`maxSize` must be larger than `minSize`.**

```bash
# Open the instance group in your editor (repeat for each nodes-* IG)
kops edit ig --name=kops.k8s.local nodes-us-east-1a
```
Change the spec and save (`:wq`):
```yaml
spec:
  minSize: 1
  maxSize: 5        # <-- MUST be larger than minSize, not 1
```
Do the same for `nodes-us-east-1b`, then apply:
```bash
# Push the min/max change to AWS
kops update cluster --name kops.k8s.local --yes
```
> ⚠️ If `minSize == maxSize == 1`, the autoscaler will **never** scale. This is
> the #1 "why isn't it working" cause.

---

## STEP 2 — Get the manifest

This lab already ships the ready-to-use manifest at
[`../manifests/cluster-autoscaler.yaml`](../manifests/cluster-autoscaler.yaml),
with the three kOps fixes already applied (SSL dir mount, `AWS_REGION`,
credentials Secret). So you can **skip the download** and go to Step 3.

For reference, the upstream template comes from:
```bash
# (Reference only — our manifest is already prepared)
curl -o cluster-autoscaler.yaml \
  https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

---

## STEP 3 — Point the manifest at YOUR cluster

The `--node-group-auto-discovery` flag and `AWS_REGION` must match your cluster.
In our manifest they're set to `kops.k8s.local` / `us-east-1`. If yours differ:

```bash
# Replace the cluster name everywhere in the manifest
sed -i 's|kops.k8s.local|YOUR.CLUSTER.NAME|g' manifests/cluster-autoscaler.yaml
```
```bash
# Verify the discovery line looks right (no leftover placeholder)
grep "node-group-auto-discovery" manifests/cluster-autoscaler.yaml
```
**Expected**
```
- --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/kops.k8s.local
```
> 💡 On Windows/macOS, `sed -i` differs — just open the file in an editor and
> replace the two values (`kops.k8s.local`, `us-east-1`) by hand.

---

## STEP 4 — Understand the three kOps fixes (already applied)

The plain upstream YAML fails on kOps. Our manifest fixes all three:

| Fix | Field | Why |
|---|---|---|
| **1. SSL as a directory** | `hostPath.path: /etc/ssl/certs` | Mounting the *file* `ca-bundle.crt` → CrashLoop |
| **2. Region** | `env: AWS_REGION=us-east-1` | Missing → `MissingRegion` error |
| **3. Credentials** | `env: ...secretKeyRef: aws-credentials` | Missing → `NoCredentialProviders` error |

No action needed — this is just so you know *why* the file looks the way it does.

---

## STEP 5 — Create the AWS credentials Secret

CA reads AWS keys from a Secret named `aws-credentials` in `kube-system`.

```bash
# See your current credentials (or use env vars)
cat ~/.aws/credentials
```
```bash
# Create the Secret (replace with your real keys)
kubectl create secret generic aws-credentials \
  --from-literal=aws_access_key_id=YOUR_ACCESS_KEY \
  --from-literal=aws_secret_access_key=YOUR_SECRET_KEY \
  -n kube-system
```
**Sample output**
```
secret/aws-credentials created
```
> 💡 Script shortcut: `./scripts/02-create-secret.sh` (reads keys from env or
> your aws CLI and is safe to re-run).

> 🔐 **Production note:** static keys in a Secret are the beginner path. In
> production use **IRSA** (IAM Roles for Service Accounts) or attach the CA IAM
> policy to the node role, then delete both the Secret *and* the two
> `AWS_*_KEY` env blocks from the Deployment. Keys can't leak or rotate-out
> if they don't exist. See the "Production hardening" box at the bottom.

---

## STEP 6 — Tag the ASGs (do NOT skip this!)

CA discovers ASGs by **tags**. No tags → `NotTriggerScaleUp / 0 ASGs` → no node
is ever added.

```bash
# Find your ASG names
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --query 'AutoScalingGroups[*].AutoScalingGroupName' \
  --output table
```
```bash
# Add the two discovery tags to each node ASG
for ASG in nodes-us-east-1a.kops.k8s.local nodes-us-east-1b.kops.k8s.local; do
  aws autoscaling create-or-update-tags \
    --region us-east-1 \
    --tags \
      ResourceId=$ASG,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=true \
      ResourceId=$ASG,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/kops.k8s.local,Value=owned,PropagateAtLaunch=true
  echo "Tags added for $ASG"
done
```
```bash
# Verify the two tags are present
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names nodes-us-east-1a.kops.k8s.local \
  --region us-east-1 \
  --query 'AutoScalingGroups[*].Tags[*].[Key,Value]' \
  --output table
```
**Expected — these two tags must appear**
```
k8s.io/cluster-autoscaler/enabled          true
k8s.io/cluster-autoscaler/kops.k8s.local   owned
```
> 💡 Script shortcut: `./scripts/03-tag-asgs.sh`

---

## STEP 7 — Deploy

```bash
# Apply all 6 objects
kubectl apply -f manifests/cluster-autoscaler.yaml
```
**Sample output**
```
serviceaccount/cluster-autoscaler created
clusterrole.rbac.authorization.k8s.io/cluster-autoscaler created
role.rbac.authorization.k8s.io/cluster-autoscaler created
clusterrolebinding.rbac.authorization.k8s.io/cluster-autoscaler created
rolebinding.rbac.authorization.k8s.io/cluster-autoscaler created
deployment.apps/cluster-autoscaler created
```
```bash
# Confirm the pod is Running
kubectl get pods -n kube-system | grep cluster-autoscaler
```
**Sample output**
```
cluster-autoscaler-7d9c...-k2f8   1/1   Running   0   30s
```
> 💡 Script shortcut: `./scripts/04-deploy.sh` (applies, waits, and tails logs).

---

## STEP 8 — Check the logs (is it actually working?)

```bash
# Tail CA logs, hiding the huge instance-type dump
kubectl logs -f -n kube-system deployment/cluster-autoscaler 2>&1 | grep -v "static instance"
```
> 💡 `grep -v "static instance"` hides the 1000+ EC2 instance types CA logs at
> startup — otherwise your terminal is flooded.

**Success looks like**
```
Successfully load 1307 EC2 Instance Types
AWS SDK Version: ...
Regenerating instance to ASG cache ... Registered ASGs
Starting main loop
```
If you see `MissingRegion` or `NoCredentialProviders` → see
[`04-troubleshooting.md`](04-troubleshooting.md).

---

## ✅ You're set up

CA is running and watching for `Pending` pods. Now prove it works live with the
demo: [`03-live-demo.md`](03-live-demo.md).

---

### 🔐 Production hardening (optional but recommended)

The PDF/beginner path uses static AWS keys. For a real cluster:

1. **Use IRSA** — create an IAM policy with the CA actions
   (`autoscaling:Describe*`, `autoscaling:SetDesiredCapacity`,
   `autoscaling:TerminateInstanceInAutoScalingGroup`, `ec2:Describe*`), attach
   it to an IAM role, and annotate the `cluster-autoscaler` ServiceAccount with
   `eks.amazonaws.com/role-arn` (EKS) or configure the equivalent kOps IAM
   additionalPolicies for the node role.
2. **Delete the credentials** — remove the `aws-credentials` Secret and the two
   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env blocks from the Deployment.
3. **Pin the image to your K8s minor version** — CA `v1.32.x` for cluster 1.32.
4. Consider `--balance-similar-node-groups` and `--scale-down-utilization-threshold`
   tuning for multi-AZ workloads.

Want the full IRSA-based manifest generated? Ask and it can be added here.
