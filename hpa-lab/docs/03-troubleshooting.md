# 03 — Troubleshooting HPA

> 90% of "my HPA won't scale" problems come from just a few causes. Work
> down this page top-to-bottom — the issues are ordered by how often they bite.

---

## Quick triage — run these three first

```bash
# 1) Is the metrics pipeline alive? (must return numbers, not an error)
kubectl top pods

# 2) What does the HPA itself say? (look at TARGETS and the Events section)
kubectl describe hpa php-apache

# 3) Does the target workload declare resource requests? (must be non-empty)
kubectl get deployment php-apache -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

If `kubectl top` errors → it's a metrics-server problem (rows 1 & 4 below).
If `top` works but TARGETS is `<unknown>` → it's usually missing requests (row 3).

---

## Common issues table

| # | Symptom | Root cause | Fix (command) |
|---|---|---|---|
| 1 | `TARGETS` shows `cpu: <unknown>/50%` and stays that way | HPA can't read metrics — metrics-server missing/not ready **or** target has no CPU request | Enable metrics-server & confirm requests: `minikube addons enable metrics-server` then re-check `kubectl top pods` |
| 2 | `Warning FailedGetResourceMetric ... unable to get metrics` in `describe hpa`, only for ~30–60s after startup | **Warm-up**: metrics-server hasn't collected the first sample yet, or a new pod has no metrics window yet | Just wait ~1 minute, then `kubectl get hpa php-apache` again. Not an error if it clears. |
| 3 | `TARGETS` is `<unknown>` even though `kubectl top pods` works | The Deployment has **no `resources.requests.cpu`** — utilization % is undefined | Add requests and re-apply: `kubectl apply -f manifests/deployment.yaml` (this file sets `cpu: 200m`) |
| 4 | `error: Metrics API not available` from `kubectl top` | metrics-server not enabled, still starting, or crash-looping | `minikube addons enable metrics-server` → `kubectl -n kube-system rollout status deployment/metrics-server` |
| 5 | HPA `REPLICAS` won't grow past a number even under heavy load | Hit `maxReplicas`, or pods are `Pending` (no node capacity), or `Unready` pods are excluded from the average | Check `kubectl get pods -l app=php-apache` and `kubectl describe hpa`; raise `maxReplicas` or free capacity |
| 6 | Pods stuck `Pending` after scale-out | Node out of allocatable CPU/memory for the new pods' requests | `kubectl describe pod <name>` (see `FailedScheduling`); lower requests or add nodes/`minikube stop && minikube start --cpus/--memory` |
| 7 | New pods `Running` but `0/1 READY` and HPA ignores them | Failing readiness probe → HPA only averages **Ready** pods | `kubectl describe pod <name>` and fix the probe/app; unready pods don't count toward scaling |
| 8 | HPA scales down way slower than expected | Default **300s scale-down stabilization window** — this is intended | Wait it out, or tune `behavior.scaleDown.stabilizationWindowSeconds` (see `hpa-advanced.yaml`) |
| 9 | `the HPA was unable to compute the replica count: failed to get memory utilization` | Using a memory metric but the container has no **memory request** | Add `resources.requests.memory` (deployment.yaml sets `128Mi`) and re-apply |
| 10 | `no matches for kind "HorizontalPodAutoscaler" in version "autoscaling/v2beta2"` | Using a **deprecated/removed** API version | Change `apiVersion` to `autoscaling/v2` (all manifests in this lab already use it) |

---

## Deep dives on the top offenders

### A. `<unknown>` targets

This is *the* classic HPA symptom. It means the HPA could not turn raw usage
into a percentage. Two independent causes — check both:

```bash
# Cause 1: is metrics-server serving data at all?
kubectl top pods -l app=php-apache
```
- **Errors** → metrics-server problem → go to section **B**.
- **Works, shows CPU** → metrics are fine; the problem is requests:

```bash
# Cause 2: does the container declare a CPU request? (empty output = the bug)
kubectl get deploy php-apache \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
```
- Empty / no `cpu` → **add requests** and re-apply the deployment:
```bash
# Re-apply the manifest that sets cpu: 200m / limit 500m
kubectl apply -f manifests/deployment.yaml
```

> Remember: `Utilization` is a percentage **of the request**. No request ⇒ no
> denominator ⇒ `<unknown>`.

---

### B. `FailedGetResourceMetric` warnings during warm-up

Right after you enable metrics-server, or right after a new pod starts, you
may see this in `kubectl describe hpa`:

```
Warning  FailedGetResourceMetric       unable to get metrics for resource cpu:
         no metrics returned from resource metrics API
Warning  FailedComputeMetricsReplicas  invalid metrics (1 invalid out of 1)
```

```bash
# Watch it clear on its own — check the HPA every few seconds
kubectl get hpa php-apache --watch
```

- **If it clears within ~1 minute:** normal warm-up, ignore it. metrics-server
  scrapes on an interval (~15s) and needs a couple of cycles.
- **If it persists > 2 minutes:** it's a real metrics-server problem →
  section **C**.

---

### C. metrics-server not ready / crash-looping

```bash
# Is the metrics-server pod actually Running and Ready?
kubectl -n kube-system get pods -l k8s-app=metrics-server
```
**Healthy sample output**
```
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-7d4b...-c8k2f      1/1     Running   0          2m
```

If it's `CrashLoopBackOff` or `0/1`, read its logs:

```bash
# Inspect why metrics-server is unhappy
kubectl -n kube-system logs deploy/metrics-server
```

**On minikube specifically**, the most common fix is simply enabling the
addon (don't hand-install upstream metrics-server, which needs a TLS flag):

```bash
# The minikube addon is preconfigured for minikube's kubelet certs
minikube addons enable metrics-server
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
```

> On a **non-minikube** cluster you may see `x509: cannot validate certificate`.
> There the (dev-only) fix is adding `--kubelet-insecure-tls` to the
> metrics-server args. The minikube addon already handles this for you.

---

### D. Missing resource requests (memory metric)

The advanced HPA also scales on memory, which needs a **memory request**:

```bash
# Verify both cpu and memory requests are present
kubectl get deploy php-apache \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
```
**Expected**
```
{"cpu":"200m","memory":"128Mi"}
```
If `memory` is missing, `hpa-advanced.yaml` will report it can't compute the
memory metric. Re-apply `manifests/deployment.yaml` to restore both requests.

---

### E. Unready pods are excluded from the average

The HPA only averages metrics over **Ready** pods. If scaled-out pods fail
readiness, they don't lower the average, so the HPA may keep adding pods or
appear "stuck".

```bash
# Look for pods that are Running but not Ready (READY column shows 0/1)
kubectl get pods -l app=php-apache
```
```bash
# Find out why a specific pod isn't Ready
kubectl describe pod <pod-name>
```
Fix the underlying readiness issue (probe path, port, app boot time). Until a
pod is Ready its metrics don't count toward scaling decisions.

---

## Still stuck? Collect this before asking for help

```bash
# One bundle of everything a reviewer needs to diagnose an HPA
kubectl get hpa -o wide
kubectl describe hpa php-apache
kubectl top pods -l app=php-apache
kubectl get deploy php-apache -o yaml | grep -A6 resources
kubectl -n kube-system get pods -l k8s-app=metrics-server
```
