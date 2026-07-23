# 01 — Helm Concepts

> **Goal:** understand *what* Helm is and *why* it exists before typing a
> single command. Read this once; keep [`05-cheatsheet.md`](05-cheatsheet.md)
> open while you work.

---

## What problem does Helm solve?

Plain `kubectl apply -f` works, but a real app is rarely one file. A typical
service ships a Deployment, Service, Ingress, ConfigMap, Secret, HPA,
ServiceAccount… That's 7+ YAMLs you must:

- apply **in the right order**,
- keep **consistent** (same labels, same image tag, same namespace),
- **parameterize** per environment (dev = 1 replica, prod = 5),
- **version**, **upgrade**, and **roll back** as one unit.

Helm is the **package manager for Kubernetes**. It bundles all those manifests
into one versioned artifact and manages its whole lifecycle with single
commands — like `apt` / `yum` / `npm`, but for clusters.

---

## The four words you must know

| Term | What it is | Analogy |
|---|---|---|
| **Chart** | A package: a folder of templated K8s manifests + default values. | The installable package (`.deb`) |
| **Release** | One *installed instance* of a chart in a cluster, with a name. | An installed program |
| **Repository** | An HTTP server hosting packaged charts (`.tgz`) + an index. | apt/npm registry |
| **Values** | The config that fills the template blanks (`values.yaml` / `--set`). | A config file passed at install |

> You can install the **same chart** many times as **different releases**
> (`web-blue`, `web-green`) — each is tracked independently.

---

## Helm 3 architecture (no Tiller!)

Helm 2 had a cluster-side component called **Tiller** — a security headache.
**Helm 3 removed it.** Now Helm is a **client-only** binary:

```
   your machine                         Kubernetes cluster
 ┌───────────────┐   templates render   ┌────────────────────┐
 │  helm (CLI)   │ ───────────────────▶ │  API server         │
 │  + values     │   plain manifests    │  (normal RBAC auth) │
 └───────────────┘                      │                     │
        │  stores release state as      │  Secrets in the     │
        └──────────────────────────────▶│  release namespace  │
                                         └────────────────────┘
```

- Helm renders templates **locally** into plain Kubernetes YAML.
- It sends that YAML to the API server using **your kubeconfig / RBAC** — same
  auth as `kubectl`. If you can `kubectl apply`, Helm can install.
- **Release state is stored in the cluster as a Secret** (type
  `helm.sh/release.v1`) in the release's namespace. That's how `helm history`
  and `helm rollback` know every past revision.

---

## Chart anatomy (`helm create` output)

```
mychart/
├── Chart.yaml          # metadata: name, version, appVersion
├── values.yaml         # DEFAULT configuration values
├── charts/             # sub-charts (dependencies) live here
├── templates/          # the templated manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── _helpers.tpl    # reusable template snippets (helpers)
│   ├── NOTES.txt       # message printed after install
│   └── tests/          # `helm test` hooks
└── .helmignore         # files to exclude when packaging
```

- **`Chart.yaml`** — `version` is the *chart* version; `appVersion` is the
  version of the *app* inside. Bump `version` every time you change the chart.
- **`values.yaml`** — every default lives here. Users override with their own
  `-f custom.yaml` or `--set key=value`.
- **`templates/`** — Go-templated YAML. `{{ .Values.x }}` pulls from values,
  `{{ .Release.Name }}` from the install context.
- **`_helpers.tpl`** — define once (e.g. a standard name/label block), reuse
  everywhere. Keeps templates DRY.

---

## Templating in 60 seconds

| Syntax | Pulls from | Example |
|---|---|---|
| `{{ .Values.replicaCount }}` | `values.yaml` (or `--set`) | `3` |
| `{{ .Release.Name }}` | the `helm install <name>` name | `web` |
| `{{ .Release.Namespace }}` | the target namespace | `demo` |
| `{{ .Chart.Name }}` / `{{ .Chart.Version }}` | `Chart.yaml` | `myapp` / `0.1.0` |
| `{{ .Values.tag | default "latest" }}` | value **with a fallback** | `latest` if unset |

Control flow:

```yaml
{{- if .Values.ingress.enabled }}
# ...render ingress only when enabled...
{{- end }}

{{- range .Values.env }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
```

> The leading `{{-` trims the whitespace/newline before the tag so the rendered
> YAML stays clean. Always render with `helm template` to see the real output.

---

## The release lifecycle (what each command does)

```
helm install    → revision 1   (create the release)
helm upgrade     → revision 2   (change values / chart version)
helm upgrade     → revision 3
helm rollback 2  → revision 4   (re-applies rev 2's manifests as a NEW revision)
helm uninstall   → gone         (removes the release + its history)
```

- Every `install`/`upgrade`/`rollback` creates a **new revision** — nothing is
  edited in place, so you can always go back.
- `helm history` lists every revision; `helm rollback <rev>` returns to one.
- **Rollback does not delete revisions** — it creates a *new* one that matches
  an old one. (So rolling back rev 3 → rev 1 produces rev 4.)

---

## Helm vs `kubectl` vs Kustomize

| | `kubectl apply` | Kustomize | **Helm** |
|---|---|---|---|
| Packaging | ❌ loose files | ⚠️ overlays | ✅ versioned chart |
| Parameterize | ❌ | ✅ patches | ✅ values + templates |
| Install/upgrade/rollback | ❌ manual | ❌ manual | ✅ one command |
| Share / distribute | ❌ | ⚠️ | ✅ repos (`.tgz`) |
| Learning curve | low | medium | medium-high |

Helm wins when you need **packaging + lifecycle + distribution**. For a couple
of static manifests, plain `kubectl` is fine.

---

Next: run the hands-on lab → [`02-lab-guide.md`](02-lab-guide.md).
