# 05 — Cluster Autoscaler Cheat Sheet (One Page)

> Print this. The whole workflow, the key commands, and interview Q&A.

---

## 🗺️ Setup flow (quick recap)

```
1. Set Min/Max          → maxSize > minSize on each node IG
2. Get the manifest     → use manifests/cluster-autoscaler.yaml
3. Point at your cluster→ fix cluster name + region
4. (3 kOps fixes)       → SSL dir, AWS_REGION, credentials (already applied)
5. Create the Secret    → aws-credentials in kube-system
6. Tag the ASGs         → k8s.io/cluster-autoscaler/enabled + /<cluster>  ← DON'T FORGET
7. Deploy               → kubectl apply -f
8. Check the logs       → "Starting main loop" = success
9. Live demo            → stress-test deployment → node appears
```

## 🧰 Everyday commands

```bash
# Deploy / update CA
kubectl apply -f manifests/cluster-autoscaler.yaml

# Is the CA pod running?
kubectl get pods -n kube-system | grep cluster-autoscaler

# Live logs (hide the instance-type dump)
kubectl logs -f -n kube-system deployment/cluster-autoscaler 2>&1 | grep -v "static instance"

# Only scaling-related log lines
kubectl logs -f -n kube-system deployment/cluster-autoscaler 2>&1 \
  | grep -v "static instance" | grep -iE "scale|unschedul|node group"

# Restart CA (e.g. after adding ASG tags)
kubectl rollout restart deployment/cluster-autoscaler -n kube-system

# CA's status ConfigMap (its view of the world)
kubectl -n kube-system get configmap cluster-autoscaler-status -o yaml

# Watch nodes appear/disappear
watch -n 2 kubectl get nodes
```

## ☁️ AWS / kOps commands

```bash
# Set node group min/max
kops edit ig --name=<cluster> nodes-<az>          # maxSize > minSize
kops update cluster --name <cluster> --yes

# List ASG names
aws autoscaling describe-auto-scaling-groups --region <region> \
  --query 'AutoScalingGroups[*].AutoScalingGroupName' --output table

# Tag an ASG for CA discovery
aws autoscaling create-or-update-tags --region <region> --tags \
  ResourceId=<asg>,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=true \
  ResourceId=<asg>,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/<cluster>,Value=owned,PropagateAtLaunch=true

# Raise max size on the live ASG
aws autoscaling update-auto-scaling-group --region <region> \
  --auto-scaling-group-name <asg> --max-size 5
```

## 🏷️ The two discovery tags (must exist on every node ASG)

| Tag key | Value |
|---|---|
| `k8s.io/cluster-autoscaler/enabled` | `true` |
| `k8s.io/cluster-autoscaler/<cluster-name>` | `owned` |

## 🔑 Key CA flags (in the Deployment `command`)

| Flag | Meaning |
|---|---|
| `--cloud-provider=aws` | Run in AWS mode |
| `--node-group-auto-discovery=asg:tag=...` | Find ASGs by tag (must match the tags above) |
| `--expander=least-waste` | Pick the ASG that wastes the least capacity |
| `--skip-nodes-with-local-storage=false` | Allow scaling down nodes that have local storage |
| `--v=4` | Log verbosity |

---

## 🧠 The 4 autoscalers in one line each

| Tool | One-liner |
|---|---|
| **ASG (alone)** | Scales EC2 by CPU — knows nothing about Kubernetes |
| **Cluster Autoscaler** | Adds a **node** when there are `Pending` pods |
| **HPA** | Adds more **pods** when load goes up |
| **VPA** | Gives a **pod** more CPU/memory |

## ⛔ The 3 things you must not forget

1. `maxSize` must be **larger** than `minSize` (else it can't scale).
2. **ASG tags are mandatory** (`k8s.io/cluster-autoscaler/enabled=true`).
3. On kOps: add **Region + Credentials** to the manifest (or use IRSA).

---

## 💬 Interview questions & answers

**1. What does the Cluster Autoscaler scale, and based on what?**
It scales the **number of nodes** based on **unschedulable (`Pending`) pods** —
not on CPU. If pods can't be placed, it adds a node; if nodes are underused, it
removes them.

**2. How is CA different from an AWS ASG on its own?**
An ASG scales EC2 on CloudWatch CPU and is **not** Kubernetes-aware — a
`Pending` pod doesn't raise CPU, so the ASG won't react. CA **is**
Kubernetes-aware and *uses* the ASG as its mechanism to add/remove nodes.

**3. CA vs HPA vs VPA?**
CA = more **nodes**; HPA = more **pods**; VPA = **bigger** pods. CA is node-level,
HPA/VPA are pod-level.

**4. How does CA discover which ASGs to manage?**
Via tags, using `--node-group-auto-discovery=asg:tag=...`. The ASGs must carry
`k8s.io/cluster-autoscaler/enabled=true` and
`k8s.io/cluster-autoscaler/<cluster>=owned`. No tags → 0 ASGs → no scale-up.

**5. Why must `maxSize > minSize`?**
CA can only change desired capacity **within** the ASG's min/max. If they're
equal there's no headroom, so it can never add a node.

**6. Why is scale-down slower than scale-up?**
Safety. CA waits until a node has been underutilized for a cooldown (~10 min by
default) before draining and removing it, so brief lulls don't destroy capacity
you'll immediately need again.

**7. What stops CA from removing a node?**
Nodes with pods that have no controller, pods with restrictive PodDisruption
Budgets, pods using local storage (unless `--skip-nodes-with-local-storage=false`),
or `kube-system` pods without the right annotations.

**8. The three kOps-specific fixes for the CA manifest?**
(1) mount `/etc/ssl/certs` as a **directory**, (2) set `AWS_REGION`, (3) provide
AWS **credentials** (Secret or IRSA). Missing them → CrashLoop / MissingRegion /
NoCredentialProviders.

**9. How does CA authenticate to AWS in production (not static keys)?**
**IRSA** (IAM Roles for Service Accounts) or an IAM role on the node — no
long-lived keys stored in a Secret.

**10. HPA scaled pods but they're stuck `Pending` — whose job is it now?**
The **Cluster Autoscaler's**. HPA only creates pods; if there's no node capacity,
CA must add a node. They're designed to work together.

**11. Why should the CA image version match the cluster version?**
CA talks to the Kubernetes API and scheduler internals that change between minor
versions; a mismatched CA can misbehave or error. Use CA `v1.32.x` for a 1.32
cluster.

**12. `NotTriggerScaleUp: 0 ASGs` — what's wrong and how do you fix it?**
CA found no ASGs to scale because the discovery tags are missing. Add the two
`k8s.io/cluster-autoscaler/...` tags to the node ASGs and restart CA.
