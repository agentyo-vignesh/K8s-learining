# 07 — Real-Time Scenarios (1-hour session runbook)

> **Goal:** turn the basic `commands.txt` flow into the habits people actually
> use on the job. Every scenario is a real "day-2 ops" situation.
>
> **Format:** a tight **60-minute** session. Times are a guide.
>
> **Base commands (your `commands.txt`)** are correct for a first look — this
> doc shows the *production* version of each.

---

## Why the basic flow isn't "real-world" yet

| `commands.txt` line | Problem in production | Fix used below |
|---|---|---|
| `helm install my-nginx bitnami/nginx` | No namespace → lands in `default` | `-n demo --create-namespace` |
| (install, then separate upgrade) | Not idempotent; CI can't re-run it | `helm upgrade --install` |
| `helm upgrade ... bitnami/nginx` | No `--atomic` → a failed deploy leaves a broken release | `--atomic --wait --timeout` |
| upgrade with no values | Changes nothing; real upgrades change config | `-f values.yaml` / `--set` |
| straight to `install` | No pre-flight check | `helm template` / `--dry-run` first |
| `rollback 1` | Manual; you won't always be watching | `--atomic` auto-rolls-back |

**The one habit to internalize:** `helm upgrade --install <rel> <chart> -n <ns>
--create-namespace --atomic --wait --timeout 5m`. That single line is
idempotent, waits for health, and **auto-rolls-back on failure**.

---

## The 60-minute plan

| Time | Block | Scenario |
|---|---|---|
| 00–08 | Warm-up | S0 — the basic flow (their commands.txt) |
| 08–18 | Deploy like CI | S1 — idempotent install to a namespace |
| 18–30 | Safe deploys | S2 — `--atomic` auto-rollback on a bad image |
| 30–42 | Config per env | S3 — dev vs prod with values files |
| 42–52 | Debugging | S4 — inspect + roll back a live release |
| 52–60 | Preview + wrap | S5 — see changes before applying, then cleanup |

> Short on time? Do **S1, S2, S3** — that's the 80/20 of real Helm.

---

## S0 — Warm-up (their basic flow) · 8 min

Run it once so everyone sees the lifecycle, then we improve it.

```bash
helm version
helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
helm search repo nginx
helm show values bitnami/nginx | head -30
helm install my-nginx bitnami/nginx        # <- we'll fix this next
helm list && helm status my-nginx
helm uninstall my-nginx                     # clean slate before the real scenarios
```

Ask the room: *what's wrong with that install for production?* (namespace,
no wait, not idempotent.)

---

## S1 — Deploy like CI does (idempotent, namespaced) · 10 min

**Scenario:** a pipeline deploys the same release repeatedly. It must work
whether the release exists or not, and never touch other namespaces.

```bash
# upgrade --install = "create if missing, upgrade if present" (idempotent)
helm upgrade --install web bitnami/nginx \
  -n demo --create-namespace \
  --wait --timeout 5m
```

```bash
# Run the EXACT same line again — no error, it's a no-op/upgrade
helm upgrade --install web bitnami/nginx -n demo --create-namespace --wait
helm list -n demo
```

> **Interview:** "Why `upgrade --install`?" → It's idempotent, so CI/CD can run
> the same command every time without branching on 'does it exist'.

---

## S2 — Safe deploys with `--atomic` (auto-rollback) · 12 min

**Scenario:** you ship a bad image tag. In prod you want Helm to **notice the
pods never go Ready and automatically roll back** — not leave a half-broken
release.

```bash
# Deploy a deliberately broken image with --atomic
helm upgrade --install web bitnami/nginx -n demo \
  --set image.tag=this-tag-does-not-exist \
  --atomic --wait --timeout 90s
```

**What you'll see:** the pods go `ImagePullBackOff`, `--wait` times out, and
because of `--atomic` Helm **rolls the release back to the last good revision
automatically**. Confirm:

```bash
helm history web -n demo          # note the automatic 'Rollback to ...' revision
kubectl get pods -n demo          # back to the healthy pods
```

> **Interview:** "`--wait` vs `--atomic`?" → `--wait` blocks until resources are
> Ready (or times out and *fails*, leaving the change). `--atomic` implies
> `--wait` **and undoes the change** on failure. Always `--atomic` in prod.

---

## S3 — Config per environment (values files) · 12 min

**Scenario:** same chart, different settings for dev and prod. Never edit the
chart — keep env config in versioned values files.

```bash
# dev: 1 replica, ClusterIP (no ELB cost)
cat > values-dev.yaml <<'EOF'
replicaCount: 1
service:
  type: ClusterIP
EOF

# prod: 3 replicas, LoadBalancer
cat > values-prod.yaml <<'EOF'
replicaCount: 3
service:
  type: LoadBalancer
EOF
```

```bash
# Deploy dev
helm upgrade --install web bitnami/nginx -n demo -f values-dev.yaml --atomic --wait
kubectl get svc,pods -n demo

# Promote to prod config (one flag change)
helm upgrade web bitnami/nginx -n demo -f values-prod.yaml --atomic --wait
kubectl get svc,pods -n demo
```

> **Precedence:** chart defaults < `-f values-prod.yaml` < `--set`.
> **Interview:** "How do you manage dev/stage/prod?" → one chart, a values file
> per environment, selected in the pipeline. And show the **`--reuse-values`
> gotcha**: `--set` alone on an upgrade resets un-passed values to defaults;
> keep config in files to avoid it.

---

## S4 — Debug + roll back a live release · 10 min

**Scenario:** "the release is misbehaving — what's actually deployed, and get
me back to the last good state."

```bash
helm status web -n demo             # overall state + NOTES
helm get values web -n demo         # values currently in effect (add -a for all)
helm get manifest web -n demo | head -40   # the EXACT YAML Helm applied
helm history web -n demo            # every revision + status
```

```bash
# Roll back to a specific known-good revision (creates a NEW revision)
helm rollback web 1 -n demo --wait
helm history web -n demo
```

> **Interview:** "How do you debug a Helm release?" → `helm get manifest` to see
> what's really applied, `helm get values` for the effective config, `helm
> history` for the timeline, then `helm rollback <rev>`.

---

## S5 — Preview changes + your own chart + cleanup · 8 min

**Scenario:** never apply blind — see the diff first. Then show it works with a
local chart too.

```bash
# See the fully-rendered YAML WITHOUT touching the cluster
helm template web bitnami/nginx -f values-prod.yaml | head -40

# Ask the API server "is this valid?" without creating anything
helm upgrade web bitnami/nginx -n demo -f values-prod.yaml --dry-run --debug | tail -20

# (optional) exact change set, if the diff plugin is installed
# helm plugin install https://github.com/databus23/helm-diff
# helm diff upgrade web bitnami/nginx -n demo -f values-prod.yaml
```

```bash
# Same habits work on YOUR chart (installed by PATH, not repo/name)
helm upgrade --install app charts/myapp -n demo --atomic --wait
# ...or the production-grade one:
helm upgrade --install app charts/webapp -n demo --atomic --wait
```

```bash
# Cleanup (ELB costs money — always do this)
helm uninstall web app -n demo
kubectl delete ns demo
```

---

## Cheat card — the flags that make it "real-world"

```
--create-namespace     never deploy into default
upgrade --install      idempotent (CI-safe)
--wait --timeout 5m    block until Ready, then fail
--atomic               auto-rollback on failure  ← the big one
-f values-<env>.yaml   per-environment config, version-controlled
--dry-run --debug      server-side validation, creates nothing
helm template          client-side render, your #1 debug tool
helm get manifest      what's ACTUALLY applied
```

If a student remembers only one line from the whole hour, make it:

```bash
helm upgrade --install <rel> <chart> -n <ns> --create-namespace \
  -f values-<env>.yaml --atomic --wait --timeout 5m
```
