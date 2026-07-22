# 02 — Hands-On Lab Guide

> **Goal:** deploy a demo app, attach an HPA, drive load, and watch
> Kubernetes scale pods **out** and then **in** — all on minikube.
>
> **Time:** ~30–40 minutes. **You need two terminals** for the load phase.
>
> Conventions in this guide:
> - Every command has a one-line comment above it explaining *why*.
> - After important commands you'll see a **Sample output** block — yours
>   won't match exactly (names/numbers differ) but the *shape* should.
> - Where Linux/macOS and Windows differ, both are shown as **Bash** and
>   **PowerShell** tabs.

---

## Step 0 — Prerequisites check

Make sure the three tools are installed and on your PATH.

```bash
# Confirm the CLIs exist and print their versions
minikube version
kubectl version --client
docker version --format '{{.Server.Version}}'   # or your chosen minikube driver
```

**Sample output**
```
minikube version: v1.33.1
Client Version: v1.30.0
27.1.1
```

> If `kubectl` isn't installed separately, you can always use the bundled one
> via `minikube kubectl -- get pods`. This guide assumes a standalone `kubectl`.

---

## Step 1 — Start minikube

```bash
# Boot a single-node Kubernetes cluster locally
minikube start
```

**Sample output**
```
😄  minikube v1.33.1 on Darwin 14.5
✨  Using the docker driver based on existing profile
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

```bash
# Confirm the node is Ready
kubectl get nodes
```

**Sample output**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   45s   v1.30.0
```

**What just happened?** minikube created a one-node cluster (inside Docker/VM)
and pointed your `kubectl` at it. The node reports `Ready`, meaning the
control plane and kubelet are healthy and can schedule pods.

---

## Step 2 — Enable the metrics-server

The HPA reads CPU/memory from the **metrics-server**, which is **not** enabled
by default on minikube. Turn it on:

```bash
# Enable the metrics-server addon (idempotent — safe if already enabled)
minikube addons enable metrics-server
```

**Sample output**
```
💡  metrics-server is an addon maintained by Kubernetes...
🌟  The 'metrics-server' addon is enabled
```

```bash
# Wait until the metrics-server deployment is fully rolled out
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
```

**Sample output**
```
deployment "metrics-server" successfully rolled out
```

**What just happened?** minikube deployed the metrics-server into the
`kube-system` namespace. It scrapes each kubelet for per-pod CPU/memory and
serves it via the `metrics.k8s.io` API — the exact data source the HPA needs.

---

## Step 3 — Verify metrics with `kubectl top`

metrics-server needs **~30–60 seconds** to collect its first samples. Until
then `kubectl top` returns an error — that's expected during warm-up.

```bash
# Ask for node-level metrics; retry if it says "metrics not available yet"
kubectl top nodes
```

**Sample output (after warm-up)**
```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
minikube   210m         2%     1120Mi          14%
```

If you instead see `error: Metrics API not available`, wait 30s and retry.

```bash
# Once nodes work, pod metrics should too (empty until we deploy something)
kubectl top pods -A
```

**What just happened?** `kubectl top` proves the metrics pipeline is live. If
this command works, the HPA will get data. If it never works, **fix this
before continuing** — see [`03-troubleshooting.md`](03-troubleshooting.md).

---

## Step 4 — Deploy the php-apache demo app

We deploy a small PHP app whose every request burns CPU — perfect for
triggering the HPA. It declares CPU **requests: 200m / limits: 500m**.

```bash
# Apply the Deployment + Service from the manifests folder
kubectl apply -f manifests/deployment.yaml
```

**Sample output**
```
deployment.apps/php-apache created
service/php-apache created
```

```bash
# Wait until the single pod is up and Ready
kubectl rollout status deployment/php-apache --timeout=120s
```

**Sample output**
```
deployment "php-apache" successfully rolled out
```

```bash
# Confirm the pod is Running and the Service exists
kubectl get deploy,svc,pods -l app=php-apache
```

**Sample output**
```
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/php-apache   1/1     1            1           30s

NAME                 TYPE        CLUSTER-IP      PORT(S)   AGE
service/php-apache   ClusterIP   10.101.55.12    80/TCP    30s

NAME                          READY   STATUS    RESTARTS   AGE
pod/php-apache-6b7f...-x2k9   1/1     Running   0          30s
```

**What just happened?** Kubernetes created a Deployment (1 replica) and a
ClusterIP Service named `php-apache` reachable inside the cluster at
`http://php-apache`. The pod reserves 200m CPU — the baseline the HPA's
percentage target is measured against.

> ⚠️ **Requests are what make HPA work.** Peek at the manifest:
> ```bash
> # Show the resource requests/limits the HPA depends on
> kubectl get deployment php-apache -o jsonpath='{.spec.template.spec.containers[0].resources}'
> ```
> If `requests.cpu` is missing, the HPA can't compute a percentage.

---

## Step 5 — Create the HPA

You'll do this **two ways**. Pick either for the live run — both produce an
`autoscaling/v2` HPA. Understanding both is an exam favorite.

### Option A — Imperative (quick, one command)

```bash
# Create an HPA: target 50% CPU, between 1 and 10 replicas
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

**Sample output**
```
horizontalpodautoscaler.autoscaling/php-apache autoscaled
```

> Modern `kubectl` creates this as an **`autoscaling/v2`** object even though
> the flags look "v1-ish". Verify with:
> ```bash
> # Confirm the API version of the created HPA
> kubectl get hpa php-apache -o jsonpath='{.apiVersion}{"\n"}'
> ```
> Expected: `autoscaling/v2`

### Option B — Declarative (YAML, the real-world way)

If you used Option A, delete it first so the names don't clash:

```bash
# Remove the imperative HPA before applying the YAML version
kubectl delete hpa php-apache --ignore-not-found
```

```bash
# Apply the version-controlled HPA manifest (autoscaling/v2)
kubectl apply -f manifests/hpa-basic.yaml
```

**Sample output**
```
horizontalpodautoscaler.autoscaling/php-apache created
```

### Inspect the HPA either way

```bash
# Show the HPA; TARGETS is current% / target%
kubectl get hpa php-apache
```

**Sample output (right after creation)**
```
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%     1         10        1          20s
```

> If `TARGETS` shows `cpu: <unknown>/50%` for the first 15–30s, that's normal
> — the HPA hasn't completed its first metrics read yet. If it stays
> `<unknown>`, see [`03-troubleshooting.md`](03-troubleshooting.md).

**What just happened?** The HPA is now watching the Deployment. `0%/50%`
means current CPU is 0% of request and the target is 50%. With 1 idle pod and
no traffic, the HPA is content at `minReplicas: 1`.

---

## Step 6 — Open the live watch (Terminal 1)

Keep this running in a dedicated terminal for the rest of the lab.

**Bash / macOS / Linux**
```bash
# Live-update the HPA row whenever the recommendation or replica count changes
kubectl get hpa php-apache --watch
```

**PowerShell (Windows)**
```powershell
# Same idea on PowerShell — --watch works identically
kubectl get hpa php-apache --watch
```

> Prefer a combined dashboard? If you have the `watch` utility
> (Linux/macOS: `brew install watch` / usually preinstalled):
> ```bash
> # Refresh HPA + pods every 2 seconds
> watch -n 2 'kubectl get hpa,pods -l app=php-apache'
> ```
> On Windows PowerShell there is no `watch`; use a loop instead:
> ```powershell
> # Poor-man's watch: clear + print every 2 seconds
> while ($true) { Clear-Host; kubectl get hpa,pods -l app=php-apache; Start-Sleep 2 }
> ```

**What just happened?** `--watch` streams updates. You'll see the `TARGETS`
percentage climb and `REPLICAS` increase live once load starts.

---

## Step 7 — Generate load (Terminal 2)

In a **second terminal**, launch a busybox pod that hammers the service in a
tight loop.

```bash
# Start a load generator that requests the service forever (Ctrl-C to stop)
kubectl run load-generator --image=busybox:1.36 --restart=Never --rm -it \
  -- /bin/sh -c "while true; do wget -q -O- http://php-apache; done"
```

> ℹ️ In PowerShell this exact command works as-is (kubectl parses the args).
> The provided script `scripts/load-test.sh` does the same with auto-cleanup.

**Sample output** (the PHP app replies `OK!` over and over)
```
If you don't see a command prompt, try pressing enter.
OK!OK!OK!OK!OK!OK!OK!OK!OK!...
```

**What just happened?** Each `wget` triggers a CPU-heavy PHP calculation.
Multiply that by an infinite loop and CPU usage on the single pod shoots past
100% of its request — far above the 50% target.

---

## Step 8 — Watch it scale OUT

Flip back to **Terminal 1**. Within ~15–60 seconds you'll see the magic.

**Sample output (evolving over ~1–2 minutes)**
```
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%     1         10        1          3m
php-apache   Deployment/php-apache   cpu: 250%/50%   1         10        1          3m
php-apache   Deployment/php-apache   cpu: 250%/50%   1         10        4          3m
php-apache   Deployment/php-apache   cpu: 108%/50%   1         10        4          4m
php-apache   Deployment/php-apache   cpu: 62%/50%    1         10        7          5m
php-apache   Deployment/php-apache   cpu: 51%/50%    1         10        7          6m
```

```bash
# In a third terminal (or pause load-watch) see the new pods
kubectl get pods -l app=php-apache
```

**Sample output**
```
NAME                          READY   STATUS    RESTARTS   AGE
php-apache-6b7f...-x2k9        1/1     Running   0          6m
php-apache-6b7f...-4dlp        1/1     Running   0          90s
php-apache-6b7f...-9wqz        1/1     Running   0          90s
php-apache-6b7f...-tt7m        1/1     Running   0          40s
... (up to 7)
```

**What just happened?** CPU hit ~250% of request. Plug into the formula:
`ceil(1 × 250/50) = 5`. As pods spread the load, per-pod CPU drops but is
still above 50%, so the HPA keeps adding pods until the fleet average settles
near the 50% target (here, 7 pods). This is the scaling formula from
[`01-concepts.md`](01-concepts.md) playing out live.

---

## Step 9 — Stop the load and watch it scale IN

Go to **Terminal 2** and stop the generator:

```
Press Ctrl-C
```

The `--rm` flag deletes the load-generator pod automatically. If it lingers:

```bash
# Force-remove the load generator if it didn't self-delete
kubectl delete pod load-generator --ignore-not-found --now
```

Now watch **Terminal 1**. CPU drops to ~0% quickly, but **replicas stay high
for ~5 minutes** — this is the scale-down **stabilization window** at work.

**Sample output (over several minutes)**
```
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        7          8m
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        7          11m   <- still 7 (window)
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          13m   <- scaled back to 1
```

**What just happened?** The HPA *immediately* knew it only needed 1 pod
(`ceil(7 × 0/50) = 0`, clamped up to `minReplicas: 1`). But the default
**300-second scale-down stabilization window** makes it wait, using the
highest recommendation from the last 5 minutes. This deliberate slowness
prevents "flapping" — tearing down pods that a brief traffic dip would
otherwise have needed again seconds later. **Scale out fast, scale in slow.**

You can watch the countdown reasoning in the events:

```bash
# See the HPA's own decisions and reasons
kubectl describe hpa php-apache
```

**Sample output (Events section)**
```
Events:
  Type    Reason             Age    From                       Message
  ----    ------             ----   ----                       -------
  Normal  SuccessfulRescale  5m     horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization above target
  Normal  SuccessfulRescale  4m     horizontal-pod-autoscaler  New size: 7; reason: cpu resource utilization above target
  Normal  SuccessfulRescale  30s    horizontal-pod-autoscaler  New size: 1; reason: All metrics below target
```

---

## Step 10 — (Optional) Try the advanced HPA

Swap the basic HPA for the multi-metric + behavior version and re-run the load.

```bash
# Remove the basic HPA and apply the advanced (CPU+memory, custom behavior)
kubectl delete hpa php-apache --ignore-not-found
kubectl apply -f manifests/hpa-advanced.yaml
```

**Sample output**
```
horizontalpodautoscaler.autoscaling/php-apache-advanced created
```

```bash
# Inspect both metrics at once
kubectl get hpa php-apache-advanced
```

**Sample output**
```
NAME                  REFERENCE               TARGETS                        MINPODS   MAXPODS   REPLICAS
php-apache-advanced   Deployment/php-apache   cpu: 0%/50%, memory: 12%/70%   1         10        1
```

**What just happened?** Now the HPA tracks **two** metrics and applies custom
`behavior` policies (scale up fast, scale down slowly). It scales on whichever
metric demands the most pods — the "max wins" rule from the concepts doc.
Re-run the load test and watch scale-**up** react faster than before.

---

## Step 11 — Clean up

```bash
# Remove all lab resources (idempotent)
kubectl delete hpa php-apache php-apache-advanced --ignore-not-found
kubectl delete -f manifests/deployment.yaml --ignore-not-found
kubectl delete pod load-generator --ignore-not-found --now
```

Or just run the script:

```bash
# One-shot cleanup
./scripts/cleanup.sh
```

To stop the cluster entirely:

```bash
# Keep the VM for a fast restart later...
minikube stop
# ...or destroy it completely
minikube delete
```

**What just happened?** You removed the workload, HPAs, and load pod. The
cluster stays up so you can re-run the lab instantly, or stop/delete it to
reclaim resources.

---

## ✅ You did it

You deployed a workload, attached an HPA, watched Kubernetes scale from 1 → 7
pods under load and back to 1 when idle, and saw *why* scale-in is slow.
Now test yourself with [`../student-worksheet.md`](../student-worksheet.md)
and keep [`04-cheatsheet.md`](04-cheatsheet.md) handy.
