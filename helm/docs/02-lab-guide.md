# 02 — Hands-On Lab Guide (Phase 1: install a public chart)

> **Goal:** install Helm on your kOps admin box, then install, upgrade,
> roll back, and uninstall the **bitnami/nginx** chart on your AWS cluster.
>
> **Time:** ~25 minutes.
>
> Conventions:
> - Every command has a one-line comment above it explaining *why*.
> - **Sample output** blocks show the *shape* to expect — names/numbers differ.
> - Commands are **Bash** (kOps admin box is Linux). Windows users: run inside
>   Git Bash / WSL, or use the Windows notes in [`04-troubleshooting.md`](04-troubleshooting.md).

---

## Step 0 — Cluster check

Confirm your kOps cluster exists and `kubectl` is pointed at it.

```bash
# List the kOps-managed cluster(s)
kops get cluster
```

**Sample output**
```
NAME                    CLOUD   ZONES
mycluster.k8s.local     aws     ap-south-1a
```

```bash
# Confirm nodes are Ready (this proves kubectl talks to the cluster)
kubectl get nodes
```

**Sample output**
```
NAME                STATUS   ROLES           AGE   VERSION
i-0abc...           Ready    control-plane   1h    v1.29.x
i-0def...           Ready    node            1h    v1.29.x
```

> No nodes / connection refused? `kops validate cluster --wait 10m` and make
> sure your kubeconfig is exported. See [`04-troubleshooting.md`](04-troubleshooting.md).

---

## Step 1 — Install Helm 3

```bash
# Download and run the official Helm 3 installer
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh
chmod +x get_helm.sh
./get_helm.sh
```

```bash
# Verify the binary is on PATH
helm version
```

**Sample output**
```
version.BuildInfo{Version:"v3.15.x", GitCommit:"...", GoVersion:"go1.22"}
```

> Fast path: `./scripts/install-helm.sh` does exactly this and is idempotent.

**What just happened?** Helm 3 is a single client-side binary — no Tiller, no
cluster-side install. It reuses your kubeconfig, so it can already reach the
cluster.

---

## Step 2 — Connection verify

```bash
# List releases in ALL namespaces (empty is fine — proves Helm can reach the API)
helm list -A
```

**Sample output**
```
NAME    NAMESPACE   REVISION    STATUS    CHART    APP VERSION
```

An empty table = Helm authenticated successfully and found no releases yet.

---

## Step 3 — Add a chart repository

```bash
# Register the bitnami repo, then refresh the local index cache
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

**Sample output**
```
"bitnami" has been added to your repositories
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
```

**What just happened?** Helm downloaded the repo's `index.yaml` (the catalog of
available charts + versions) to your machine so you can search and install.

---

## Step 4 — Search + inspect the chart

```bash
# Find the nginx chart in the repos you've added
helm search repo nginx
```

**Sample output**
```
NAME            CHART VERSION   APP VERSION   DESCRIPTION
bitnami/nginx   18.x.x          1.27.x        NGINX Open Source web server
```

```bash
# Read the first 40 lines of the chart's configurable values
helm show values bitnami/nginx | head -40
```

**What just happened?** `helm show values` prints the chart's `values.yaml` —
the full menu of what you can override (`replicaCount`, `service.type`,
`image.tag`, …). Always read this before installing something new.

---

## Step 5 — Install

```bash
# Install the chart as release "web" into a fresh "demo" namespace
helm install web bitnami/nginx -n demo --create-namespace --wait --timeout 5m
```

**Sample output**
```
NAME: web
LAST DEPLOYED: ...
NAMESPACE: demo
STATUS: deployed
REVISION: 1
NOTES:
  ...how to reach the service...
```

- `--create-namespace` makes `demo` if it doesn't exist.
- `--wait` blocks until pods/services are actually Ready (fails fast otherwise).

```bash
# See everything the chart created
kubectl get all -n demo
```

**What just happened?** Helm rendered the chart's templates with default values
and applied them. This is **revision 1** of release `web`, tracked by a Secret
in the `demo` namespace.

---

## Step 6 — Upgrade (1 → 3 replicas)

```bash
# Change ONE value and re-deploy; --reuse-values keeps all other prior settings
helm upgrade web bitnami/nginx -n demo --set replicaCount=3 --reuse-values --wait
```

```bash
# Confirm 3 pods now exist
kubectl get pods -n demo
```

**Sample output**
```
NAME                        READY   STATUS    RESTARTS   AGE
web-nginx-6b7f...-x2k9       1/1     Running   0          3m
web-nginx-6b7f...-4dlp       1/1     Running   0          25s
web-nginx-6b7f...-9wqz       1/1     Running   0          25s
```

**What just happened?** This is **revision 2**. Helm computed the diff and only
scaled the Deployment. `--reuse-values` means "keep everything from the last
release and change only what I pass now."

> ⚠️ **`--reuse-values` vs `--set` alone:** without `--reuse-values`, an
> upgrade resets un-passed values back to the chart defaults. Get this wrong in
> prod and you silently revert config. See the cheatsheet.

---

## Step 7 — Inspect history

```bash
# Show every revision of this release
helm history web -n demo
```

**Sample output**
```
REVISION   STATUS       CHART          APP VERSION   DESCRIPTION
1          superseded   nginx-18.x.x   1.27.x        Install complete
2          deployed     nginx-18.x.x   1.27.x        Upgrade complete
```

**What just happened?** Helm keeps every revision so you can audit changes and
roll back to any of them.

---

## Step 8 — Get the browser URL

The chart's Service is a `LoadBalancer`, so AWS provisions an ELB.

```bash
# Print the public URL (the ELB hostname takes ~2-3 min to resolve)
echo "http://$(kubectl get svc web-nginx -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

**Sample output**
```
http://a1b2c3d4e5-1234567890.ap-south-1.elb.amazonaws.com
```

> If the URL prints as `http://` with nothing after it, the ELB isn't ready
> yet — wait 2-3 min and re-run. Also confirm the node/ELB security group
> allows port 80.

---

## Step 9 — Rollback

```bash
# Return to revision 1 (back to 1 replica). This creates a NEW revision.
helm rollback web 1 -n demo --wait
```

```bash
# Prove we're back to 1 pod, and that a new revision was recorded
kubectl get pods -n demo
helm history web -n demo
```

**Sample output (history)**
```
REVISION   STATUS       DESCRIPTION
1          superseded   Install complete
2          superseded   Upgrade complete
3          deployed     Rollback to 1
```

**What just happened?** Rollback re-applied revision 1's manifests as a **new
revision 3**. Nothing was destroyed — the whole timeline is preserved.

---

## Step 10 — Cleanup

```bash
# Remove the release (all its objects) and then the namespace
helm uninstall web -n demo
kubectl delete ns demo
```

```bash
# Confirm nothing is left
helm list -A
```

Or run the script:

```bash
./scripts/cleanup.sh
```

**What just happened?** `helm uninstall` deleted every object the release
created **and** its history Secret. Deleting the namespace cleans up anything
namespace-scoped that remained.

---

## ✅ You did it

You installed Helm, deployed a public chart, upgraded and rolled it back, and
tore it down — the full release lifecycle. Next, build **your own** chart →
[`03-create-chart.md`](03-create-chart.md).
