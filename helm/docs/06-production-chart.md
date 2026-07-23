# 06 — Production-Grade Chart (interview walkthrough)

> **Goal:** understand every production pattern in [`../charts/webapp`](../charts/webapp)
> so you can **build it, run it, and explain it in an interview**.
>
> `charts/myapp` (docs 03) teaches the *basics*. `charts/webapp` is what a
> *real* chart looks like — the same shape `helm create` produces, hand-written
> so you understand every line.

---

## What makes it "production-grade"?

| Pattern | Why prod needs it | The interview soundbite |
|---|---|---|
| `_helpers.tpl` + `include` | DRY names/labels across every manifest | "Named templates defined once and included everywhere, so names and labels never drift." |
| Standard `app.kubernetes.io/*` labels | Tooling (kubectl, Prometheus, ArgoCD) relies on them | "I use the recommended label set so every object is discoverable and consistent." |
| Separate **selectorLabels** | A Deployment's `selector` is **immutable** | "Selector labels are a stable subset — name + instance only. I never put version there, or upgrades break." |
| Non-root **securityContext** | Least privilege; blocks container breakout | "Runs as non-root uid 101, `allowPrivilegeEscalation: false`, all capabilities dropped." |
| **resources** requests/limits | Scheduling + the HPA needs requests | "Requests let the scheduler bin-pack and are the denominator the HPA's % CPU is measured against." |
| **liveness** + **readiness** probes | Self-healing + safe rollouts | "Liveness restarts a hung pod; readiness gates traffic so we don't route to a pod that isn't ready." |
| Gated **HPA** (`if autoscaling.enabled`) | One chart, many environments | "The same chart does dev (fixed replicas) and prod (HPA) via a values flag." |
| Gated **Ingress** | Not every env exposes HTTP the same way | "Ingress renders only when enabled, with host/path/TLS all driven from values." |
| Dedicated **ServiceAccount** | Least-privilege identity (IRSA on AWS) | "A per-release SA so I can attach an IAM role via IRSA instead of using `default`." |
| **helm test** hook | Ships a smoke test with the chart | "`helm test` runs a pod that curls the Service — post-deploy verification baked in." |
| Pinned image tag + SemVer chart `version` | Reproducible, auditable releases | "Never `latest`; the chart `version` bumps on every change, `appVersion` tracks the app." |

---

## Line-by-line: the pieces interviewers ask about

### 1. `_helpers.tpl` — define once, reuse everywhere

```gotemplate
{{- define "webapp.fullname" -}}
{{- printf "%s-%s" .Release.Name (default .Chart.Name .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}
```
- `define` names a snippet; `{{ include "webapp.fullname" . }}` renders it (the
  `.` passes scope so it can read `.Release`, `.Values`).
- `trunc 63 | trimSuffix "-"` — K8s names max out at 63 chars (DNS label limit).

> **Q: `include` vs `template`?** `include` is a *function* — its output can be
> piped (`| nindent 4`, `| indent`). The `template` *action* can't be piped.
> Always use `include` when you need indentation control.

### 2. Labels vs selectorLabels

```gotemplate
{{- define "webapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```
`webapp.labels` includes `selectorLabels` **plus** chart/version/managed-by.

> **Q: Why split them?** The Deployment's `spec.selector.matchLabels` is
> **immutable** after creation. If `version` were in the selector, every
> `appVersion` bump would make the selector change → the upgrade fails. So the
> selector holds only the stable `name`+`instance`, while the fuller label set
> (with version) goes on metadata.

### 3. Non-root security context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 101
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```
That's why the image is `nginxinc/nginx-unprivileged` (serves on **8080**, runs
as uid 101) — the stock `nginx` image wants root to bind port 80.

> **Q: Why 8080 not 80?** Non-root processes can't bind ports < 1024. The
> unprivileged image listens on 8080; the Service maps port **80 → targetPort
> http (8080)**, so users still hit `:80`.

### 4. Resources + the HPA link

```yaml
resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { cpu: 250m, memory: 256Mi }
```
> **Q: Why do requests matter for the HPA?** The HPA computes
> `currentCPU / requestedCPU`. **No request = no denominator = `<unknown>`
> target = no scaling.** Requests are mandatory for CPU-based autoscaling.

### 5. Gated HPA (one chart, many envs)

```gotemplate
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
```
When `autoscaling.enabled=true`, the chart **omits `replicas`** (the HPA owns
it) and renders `hpa.yaml`.

> **Q: Why omit replicas instead of setting it?** If both the Deployment and the
> HPA set replicas, they fight on every reconcile (flapping). Let the HPA be the
> single owner.

### 6. `helm test` hook

```yaml
metadata:
  annotations:
    "helm.sh/hook": test
```
`helm test <release>` runs this pod; a zero exit = pass.

---

## Build → run → prove it (the lab)

```bash
# 1) Static + offline validation
helm lint charts/webapp
helm template app charts/webapp                    # see the default render
helm template app charts/webapp --set autoscaling.enabled=true --set ingress.enabled=true
```

```bash
# 2) Install (default: fixed replicas, LoadBalancer, non-root)
helm install web charts/webapp -n demo --create-namespace --wait --timeout 5m
kubectl get all -n demo
```

```bash
# 3) Prove non-root + labels (great things to show live)
kubectl get pod -n demo -l app.kubernetes.io/name=webapp \
  -o jsonpath='{.items[0].spec.securityContext}{"\n"}{.items[0].spec.containers[0].securityContext}{"\n"}'
kubectl get all -n demo --show-labels
```

```bash
# 4) Run the chart's own smoke test
helm test web -n demo
```

```bash
# 5) Flip to prod mode: autoscaling + ingress from a values file
cat > prod.yaml <<'EOF'
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 8
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: webapp.demo.example.com
      paths: [{ path: /, pathType: Prefix }]
EOF

helm upgrade web charts/webapp -n demo -f prod.yaml --wait
kubectl get hpa,ingress -n demo
```

```bash
# 6) Public URL (LoadBalancer / AWS ELB, ~2-3 min)
echo "http://$(kubectl get svc web-webapp -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

```bash
# 7) Cleanup
helm uninstall web -n demo && kubectl delete ns demo
```

Fast path: `./scripts/deploy-webapp.sh`.

---

## Rapid-fire interview Q&A (webapp-specific)

1. **Walk me through your chart.** Helpers define name/labels once; Deployment +
   Service always render; ServiceAccount, HPA, and Ingress are gated by values;
   a test hook ships a smoke test. Config is 100% in `values.yaml`.
2. **How does one chart serve dev and prod?** Values flags — dev uses fixed
   `replicaCount`; prod sets `autoscaling.enabled=true` and `ingress.enabled=true`.
3. **Why is the selector minimal?** It's immutable; only `name`+`instance` go
   there so version bumps don't break upgrades.
4. **How do you secure the pod?** Non-root uid, no privilege escalation, all caps
   dropped, unprivileged image on 8080.
5. **Where would the AWS IAM role go?** `serviceAccount.annotations` (IRSA).
6. **How do you validate before deploying?** `helm lint`, `helm template`,
   `--dry-run --debug`, then `helm test` after install.
7. **What's `toYaml . | nindent 8`?** Serialize a values sub-tree to YAML and
   indent it 8 spaces so it slots into the manifest correctly.
8. **`{{- with .Values.x }}`?** Render the block only if `x` is non-empty, and
   set scope to `x` inside — avoids emitting empty keys.

---

Next / reference: [`05-cheatsheet.md`](05-cheatsheet.md) ·
troubleshooting [`04-troubleshooting.md`](04-troubleshooting.md).
