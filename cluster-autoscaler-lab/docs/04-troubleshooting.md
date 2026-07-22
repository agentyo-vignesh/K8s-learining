# 04 — Troubleshooting (Common Errors + Fixes)

> Every error you're likely to hit during CA setup, with its cause and fix.
> This is gold for students — deliberately trigger each one, then fix it.

---

## Quick triage — run these first

```bash
# 1) Is the CA pod even running?
kubectl get pods -n kube-system | grep cluster-autoscaler

# 2) Why is it unhappy? (read the events at the bottom)
kubectl describe pod -n kube-system <cluster-autoscaler-pod-name>

# 3) What is CA actually doing/complaining about?
kubectl logs -n kube-system deployment/cluster-autoscaler 2>&1 \
  | grep -v "static instance" | tail -30
```

---

## Common errors table

| # | Error / symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `CrashLoopBackOff`, `error mounting ".../ca-bundle.crt" ... not a directory` | SSL cert mounted as a **file** instead of a directory | Mount the **directory** `/etc/ssl/certs` (already fixed in our manifest) |
| 2 | `MissingRegion: could not find region configuration` | CA doesn't know the AWS region | Add `env: AWS_REGION=us-east-1` (already in our manifest) |
| 3 | `NoCredentialProviders: no valid providers in chain` | CA has no AWS credentials | Create the `aws-credentials` Secret + env refs (Step 5), or use IRSA |
| 4 | `pod didn't trigger scale-up: NotTriggerScaleUp`, `0 ASGs` | ASGs have no CA discovery tags | Add the two tags (Step 6), then restart CA |
| 5 | `Skipping node group ... max size reached` | ASG already at its `maxSize` | Raise `maxSize` (Step 1) — but this means CA is **working**! |
| 6 | Pods stay `Pending`, CA log silent | `maxSize == minSize`, or requests too big for any node type | Set `maxSize > minSize`; check pod requests vs node capacity |
| 7 | Nodes never scale **down** | Scale-down is slow by design (~10 min), or pods block it | Wait; check for pods without controllers / PDBs / local storage |

---

## Error 1 — CrashLoopBackOff (SSL mount)

```
error mounting "/etc/ssl/certs/ca-bundle.crt" ... not a directory
```
**Cause:** the SSL path in the YAML points to a *file*, but a *directory* is
needed. **Fix (already applied in our manifest):**
```yaml
volumeMounts:
  - name: ssl-certs
    mountPath: /etc/ssl/certs      # not a file path
    readOnly: true
volumes:
  - name: ssl-certs
    hostPath:
      path: "/etc/ssl/certs"       # directory only
```

## Error 2 — MissingRegion

```
MissingRegion: could not find region configuration
Failed to regenerate ASG cache
```
**Cause:** no region set. **Fix:**
```yaml
env:
  - name: AWS_REGION
    value: us-east-1
```

## Error 3 — NoCredentialProviders

```
NoCredentialProviders: no valid providers in chain
Failed to create AWS Manager
```
**Cause:** CA can't authenticate to AWS. **Fix — create the Secret:**
```bash
# Create the credentials Secret CA reads from
kubectl create secret generic aws-credentials \
  --from-literal=aws_access_key_id=YOUR_KEY \
  --from-literal=aws_secret_access_key=YOUR_SECRET \
  -n kube-system
```
and reference it in the Deployment env (already in our manifest):
```yaml
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef: { name: aws-credentials, key: aws_access_key_id }
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef: { name: aws-credentials, key: aws_secret_access_key }
```
> Better long-term fix: **IRSA / node IAM role** so no static keys exist at all.

## Error 4 — NotTriggerScaleUp (No expansion options)

```
pod didn't trigger scale-up: NotTriggerScaleUp
No expansion options
Successfully queried instance requirements for 0 ASGs
```
**Cause:** the ASGs have no CA tags, so CA discovers **0 ASGs** — it doesn't
know which group to grow. **Fix — add tags, then restart CA:**
```bash
# Tag both node ASGs
for ASG in nodes-us-east-1a.kops.k8s.local nodes-us-east-1b.kops.k8s.local; do
  aws autoscaling create-or-update-tags --region us-east-1 --tags \
    ResourceId=$ASG,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=true \
    ResourceId=$ASG,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/kops.k8s.local,Value=owned,PropagateAtLaunch=true
done
```
```bash
# Restart CA so it re-discovers the ASGs
kubectl rollout restart deployment/cluster-autoscaler -n kube-system
```

## Error 5 — max size reached

```
Skipping node group nodes-us-east-1a.kops.k8s.local - max size reached
```
**Cause:** you've hit the maximum node count — no room to grow further.
✅ **This is actually GOOD news: CA is working, it just hit the ceiling.**
**Fix (only if you want more nodes) — raise maxSize:**
```bash
# In kOps
kops edit ig --name=kops.k8s.local nodes-us-east-1a   # set maxSize: 5
kops update cluster --name kops.k8s.local --yes
```
```bash
# And immediately on the live ASG
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name nodes-us-east-1a.kops.k8s.local \
  --max-size 5 \
  --region us-east-1
```

---

## Quick debug commands (any error)

```bash
# Pod status
kubectl get pods -n kube-system | grep cluster-autoscaler

# Pod details / events
kubectl describe pod -n kube-system <pod-name>

# Logs (hide the static instance list)
kubectl logs -n kube-system deployment/cluster-autoscaler 2>&1 \
  | grep -v "static instance" | tail -30

# Logs from a PREVIOUS crash
kubectl logs -n kube-system <pod-name> --previous

# Confirm ASG tags exist
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <asg-name> \
  --region us-east-1 \
  --query 'AutoScalingGroups[*].Tags[*].[Key,Value]' \
  --output table

# See CA's own status ConfigMap (what it thinks the world looks like)
kubectl -n kube-system get configmap cluster-autoscaler-status -o yaml
```
