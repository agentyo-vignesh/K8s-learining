# 03 — Set Up & Install a Local Chart (your own YAML files)

> **Goal:** the chart already exists as **local YAML files** in
> [`../charts/myapp`](../charts/myapp). This doc shows exactly how those files
> fit together and how to **set up and install** the chart from them — no repo,
> no download, everything local.
>
> **Time:** ~20 minutes.
>
> Conventions: every command has a one-line *why* comment above it, and
> important commands show **Sample output**.

---

## Step 1 — Look at the local chart

Everything Helm needs is these four files in one folder:

```bash
# See the whole chart on disk
ls -R charts/myapp
```

**Sample output**
```
charts/myapp:
Chart.yaml   values.yaml   templates

charts/myapp/templates:
deployment.yaml   service.yaml   NOTES.txt
```

That's the minimum a chart needs:

| File | Job |
|---|---|
| `Chart.yaml` | Chart metadata — name + version. **Required.** |
| `values.yaml` | The default values that fill the template blanks. |
| `templates/deployment.yaml` | Your Deployment, with `{{ }}` placeholders. |
| `templates/service.yaml` | Your Service, with `{{ }}` placeholders. |
| `templates/NOTES.txt` | Message Helm prints after install (optional). |

> **This is the whole trick:** a folder with `Chart.yaml` + `values.yaml` +
> `templates/` **is** a chart. Nothing else is required.

---

## Step 2 — Understand each file

### `Chart.yaml` — the label on the package

```bash
cat charts/myapp/Chart.yaml
```
```yaml
apiVersion: v2              # v2 = Helm 3 chart format
name: myapp                 # the chart's name
description: My own custom Helm chart
type: application
version: 0.1.0              # CHART version — bump this every time you change the chart
appVersion: "1.0"           # version of the app inside (informational)
```

### `values.yaml` — the knobs (defaults)

```bash
cat charts/myapp/values.yaml
```
```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.27"
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80
```
Every value here is a **default**. Users override them at install time
(`--set` or `-f`). Nothing is hard-coded in the templates.

### `templates/deployment.yaml` — the manifest with blanks

```bash
cat charts/myapp/templates/deployment.yaml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-myapp          # <- filled from `helm install <name>`
  labels:
    app: {{ .Release.Name }}-myapp
spec:
  replicas: {{ .Values.replicaCount }}     # <- filled from values.yaml (2)
  selector:
    matchLabels:
      app: {{ .Release.Name }}-myapp
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-myapp
    spec:
      containers:
        - name: myapp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"   # nginx:1.27
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
```

### `templates/service.yaml`

```bash
cat charts/myapp/templates/service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-myapp
spec:
  type: {{ .Values.service.type }}         # LoadBalancer
  selector:
    app: {{ .Release.Name }}-myapp          # must match the Deployment's pod labels
  ports:
    - port: {{ .Values.service.port }}      # 80
      targetPort: 80
```

---

## Step 3 — How the blanks get filled (the key idea)

Each `{{ }}` placeholder is replaced at install time from one of two sources:

| Placeholder in the YAML | Filled from | Example result |
|---|---|---|
| `{{ .Release.Name }}` | the name you pass: `helm install `**`app`**` ...` | `app` |
| `{{ .Release.Namespace }}` | the `-n` namespace | `demo` |
| `{{ .Values.replicaCount }}` | `values.yaml` (or `--set`) | `2` |
| `{{ .Values.image.repository }}` | `values.yaml` `image.repository` | `nginx` |
| `{{ .Values.service.type }}` | `values.yaml` `service.type` | `LoadBalancer` |

So if you run `helm install app charts/myapp`, every `{{ .Release.Name }}`
becomes `app` and the Deployment is named `app-myapp` with 2 replicas of
`nginx:1.27`. **You never edit the templates to change config — you change
`values.yaml` (or pass `--set`).**

---

## Step 4 — Validate offline (before touching the cluster)

Two commands prove the chart is correct without installing anything.

```bash
# 1) Static check: is the chart well-formed?
helm lint charts/myapp
```
**Sample output**
```
==> Linting charts/myapp
1 chart(s) linted, 0 chart(s) failed
```

```bash
# 2) Render the templates to REAL YAML on screen (no cluster involved).
#    This is where you SEE the blanks getting filled in.
helm template app charts/myapp
```
**Sample output (note how `{{ .Release.Name }}` became `app`, replicas = 2)**
```yaml
---
# Source: myapp/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-myapp
spec:
  type: LoadBalancer
  selector:
    app: app-myapp
  ports:
    - port: 80
      targetPort: 80
---
# Source: myapp/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-myapp
  labels:
    app: app-myapp
spec:
  replicas: 2
  ...
          image: "nginx:1.27"
```

> `helm template` is your **#1 tool**. Always run it first — what you see here
> is *exactly* what gets sent to Kubernetes.

---

## Step 5 — Install the local chart

The one difference from Phase 1: a local chart is installed **by its folder
path**, not by `repo/name`. No `helm repo add`, no download.

```bash
# Install the LOCAL chart (the path to the folder) as release "app"
helm install app charts/myapp -n demo --create-namespace --wait --timeout 5m
```
**Sample output**
```
NAME: app
NAMESPACE: demo
STATUS: deployed
REVISION: 1
NOTES:
✅  myapp deployed as release "app" ...
```

> Compare:
> - Phase 1 (repo chart): `helm install web `**`bitnami/nginx`**
> - This lab (local chart): `helm install app `**`charts/myapp`** ← a **path**

---

## Step 6 — Verify

```bash
# Everything the chart created
kubectl get all -n demo
```
```bash
# Public URL (AWS ELB — takes ~2-3 min to resolve)
echo "http://$(kubectl get svc app-myapp -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

**What just happened?** Helm rendered your local templates with the defaults
from `values.yaml` and applied them as **revision 1** of release `app`.

---

## Step 7 — Change config WITHOUT editing templates

You override values three ways. **Notice you never touch the YAML templates.**

```bash
# A) One value on the command line
helm upgrade app charts/myapp -n demo --set replicaCount=3 --wait
kubectl get pods -n demo          # now 3 pods
```

```bash
# B) A whole values file (the real-world way for prod/dev config)
cat > prod-values.yaml <<'EOF'
replicaCount: 4
image:
  repository: nginx
  tag: "1.27"
service:
  type: LoadBalancer
  port: 80
EOF

helm upgrade app charts/myapp -n demo -f prod-values.yaml --wait
```

**Precedence (low → high):** `values.yaml` → `-f prod-values.yaml` → `--set`.
The most specific one wins.

---

## Step 8 — Package, rollback, cleanup

```bash
# Bundle the local chart into a shareable versioned .tgz (version from Chart.yaml)
helm package charts/myapp
# -> Successfully packaged chart and saved it to: .../myapp-0.1.0.tgz
```
```bash
# History, then roll back to the first revision (creates a NEW revision)
helm history app -n demo
helm rollback app 1 -n demo --wait
```
```bash
# Tear everything down
helm uninstall app -n demo
kubectl delete ns demo
helm list -A
```

Fast path for the whole thing: `./scripts/deploy-mychart.sh`.

---

## ✅ You did it

You read a local chart's four files, understood how `{{ }}` blanks fill from
`values.yaml` and the release name, validated it offline with `lint` +
`template`, installed it **by path**, and changed config without ever editing a
template. Test yourself → [`../student-worksheet.md`](../student-worksheet.md).

---

## Appendix — generating a chart with `helm create` (optional)

Don't want to hand-write the files? Helm can scaffold a full starter chart:

```bash
# Generate a production-shaped chart (Deployment, Service, Ingress, HPA, helpers)
helm create mychart
ls -R mychart
```
```
mychart/
├── Chart.yaml
├── values.yaml
├── charts/
├── templates/
│   ├── deployment.yaml   service.yaml   ingress.yaml   hpa.yaml
│   ├── serviceaccount.yaml   _helpers.tpl   NOTES.txt   tests/
└── .helmignore
```

To use the scaffold but **your own** manifests, delete the defaults and drop
yours in:

```bash
rm -rf mychart/templates/*        # remove ALL generated templates
# ...copy your deployment.yaml / service.yaml into mychart/templates/
helm lint mychart && helm template app mychart
```

Either way — hand-written (`charts/myapp`) or scaffolded — the install command
is identical: `helm install <name> <path-to-chart-folder>`.
