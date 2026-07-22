# 04 — HPA Cheat Sheet (One-Page Quick Reference)

> Print this. Everything you need for the lab, the job, and the interview.

---

## 🔧 Everyday HPA commands

```bash
# Create an HPA imperatively (target 50% CPU, 1–10 replicas) — makes autoscaling/v2
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

# Create/update an HPA from YAML (the GitOps way)
kubectl apply -f manifests/hpa-basic.yaml

# List HPAs — TARGETS column is current% / target%
kubectl get hpa

# Wide view with more columns
kubectl get hpa -o wide

# Live-update as the HPA recommendation / replica count changes
kubectl get hpa php-apache --watch

# Full detail + the Events log (WHY it scaled — read this first when debugging)
kubectl describe hpa php-apache

# Dump the HPA as YAML (see computed status, current metrics)
kubectl get hpa php-apache -o yaml

# Confirm the API version actually in use
kubectl get hpa php-apache -o jsonpath='{.apiVersion}{"\n"}'

# Delete an HPA
kubectl delete hpa php-apache
```

## 📊 Metrics & verification

```bash
# Node-level usage (proves metrics-server is alive)
kubectl top nodes

# Pod-level usage for our app
kubectl top pods -l app=php-apache

# Enable metrics-server on minikube (required!)
minikube addons enable metrics-server

# Is metrics-server healthy?
kubectl -n kube-system get pods -l k8s-app=metrics-server
```

## 🧪 Load & scale demo

```bash
# Generate CPU load in a throwaway pod (Ctrl-C to stop; --rm auto-deletes)
kubectl run load-generator --image=busybox:1.36 --restart=Never --rm -it \
  -- /bin/sh -c "while true; do wget -q -O- http://php-apache; done"

# Watch pods appear/disappear
kubectl get pods -l app=php-apache --watch

# Manually set replicas (HPA will override on its next tick — for testing only)
kubectl scale deployment php-apache --replicas=3
```

---

## 🧬 `autoscaling/v2` spec — key fields

```yaml
apiVersion: autoscaling/v2            # ALWAYS v2 (v1 = CPU-only, v2beta* = removed)
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:                     # WHAT to scale (must already exist)
    apiVersion: apps/v1
    kind: Deployment                  # or ReplicaSet / StatefulSet
    name: php-apache
  minReplicas: 1                      # floor
  maxReplicas: 10                     # ceiling
  metrics:                            # LIST — HPA takes the max desired across all
    - type: Resource                  # Resource | Pods | Object | External | ContainerResource
      resource:
        name: cpu                     # cpu | memory
        target:
          type: Utilization           # Utilization (% of request) | AverageValue | Value
          averageUtilization: 50      # the target number
  behavior:                           # optional — control scaling SPEED (v2 only)
    scaleUp:
      stabilizationWindowSeconds: 0   # 0 = react instantly
      selectPolicy: Max               # Max | Min | Disabled
      policies:
        - type: Percent               # Percent | Pods
          value: 100
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300 # default; damps flapping on scale-in
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
```

### Field quick-reference

| Field | What it does | Default |
|---|---|---|
| `minReplicas` / `maxReplicas` | Hard floor / ceiling | max required |
| `metrics[].type` | `Resource`, `Pods`, `Object`, `External`, `ContainerResource` | — |
| `target.type` | `Utilization` (% of request), `AverageValue`, `Value` | — |
| `behavior.scaleUp/scaleDown` | Rate-limit scaling | up=fast, down=300s window |
| `stabilizationWindowSeconds` | Look-back to smooth decisions | up 0s / down 300s |
| `selectPolicy` | Which policy wins when several apply | `Max` |

### The formula (memorize it)

```
desiredReplicas = ceil( currentReplicas × currentMetric / targetMetric )
```
Plus a **±10% tolerance** dead-band and clamping to `[minReplicas, maxReplicas]`.

---

## 💬 Interview questions & answers

**1. What does the HPA scale, and how is that different from the VPA?**
The HPA scales the **number of pod replicas** (horizontal). The VPA changes a
pod's **CPU/memory requests** (vertical). HPA = more pods; VPA = bigger pods.
Don't run both on CPU/memory for the same workload — they conflict.

**2. What is the HPA scaling formula?**
`desiredReplicas = ceil(currentReplicas × currentMetricValue / targetMetricValue)`,
then clamped to min/max and subject to a ±10% tolerance and behavior policies.

**3. Why does my HPA show `<unknown>` for the target?**
Either metrics-server isn't running/ready, or the target pods don't declare
resource **requests** (so utilization % can't be computed). Fix metrics-server
and/or add `resources.requests`.

**4. Why is the metrics-server required?**
The HPA reads CPU/memory from the `metrics.k8s.io` API, which metrics-server
provides by scraping each kubelet. No metrics-server ⇒ no data ⇒ no scaling.

**5. How often does the HPA make decisions?**
Every **15 seconds** by default (the controller's sync period).

**6. Why does scale-down take so long compared to scale-up?**
The default scale-down **stabilization window is 300s (5 min)**: the HPA uses
the highest recommendation from the look-back window to avoid flapping. Scale-up
has a 0s window by default, so it reacts immediately.

**7. What API version should HPA manifests use, and what changed in v2?**
Use **`autoscaling/v2`**. v2 adds multi-metric support, memory/custom/external
metrics, and the `behavior` block. `autoscaling/v1` is CPU-only; `v2beta1/2` are
deprecated/removed.

**8. If an HPA has multiple metrics, how does it decide the replica count?**
It computes a desired replica count for **each** metric and uses the **highest**
one ("max wins"), so no single metric is ever under-provisioned.

**9. What is `Utilization` vs `AverageValue` for a target?**
`Utilization` is a **percentage of the pod's request** (needs a request).
`AverageValue` is an **absolute per-pod amount** (e.g. `500m`, no request needed).
`Value` is a raw total for Object/External metrics.

**10. HPA is scaling out but pods stay `Pending` — what's happening and who fixes it?**
The nodes have no room for the new pods' requests. The HPA's job is done; the
**Cluster Autoscaler** (or you) must add node capacity. HPA scales pods, CA scales nodes.

**11. Do unready pods count toward the HPA's metric average?**
No. The HPA averages only **Ready** pods. Unready/starting pods are excluded so
a slow-booting pod doesn't skew the decision.

**12. Can the HPA and a fixed `replicas:` field coexist?**
Once an HPA manages a Deployment, it **owns** `.spec.replicas`. Setting replicas
manually is overridden on the next tick. Manage the count via the HPA, not the
Deployment. (Also don't let two HPAs target the same workload.)

**13. How would you make an HPA scale up aggressively but down gently?**
Use `behavior`: `scaleUp.stabilizationWindowSeconds: 0` with a high Percent/Pods
policy, and `scaleDown.stabilizationWindowSeconds: 300+` with a small
Percent/Pods policy. (See `manifests/hpa-advanced.yaml`.)

**14. What's the ±10% tolerance for?**
A dead-band around the target: if `current/target` is within 0.9–1.1, the HPA
makes **no change**, preventing constant ±1 pod churn near the target.
