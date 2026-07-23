# 05 — Helm Cheat Sheet

One-page reference. Keep it open while you work.

---

## Install / version

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version                       # verify
helm env                           # show Helm's environment paths
```

## Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update                   # refresh all repo indexes
helm repo list                     # what's registered
helm repo remove bitnami
helm search repo nginx             # search added repos
helm search hub wordpress          # search Artifact Hub (public)
```

## Inspect a chart before installing

```bash
helm show chart bitnami/nginx      # metadata
helm show values bitnami/nginx     # ALL configurable values
helm show readme bitnami/nginx     # the chart's docs
helm pull bitnami/nginx --untar    # download + unpack to read locally
```

## Install / upgrade / rollback

```bash
helm install <rel> <chart> -n <ns> --create-namespace --wait --timeout 5m
helm upgrade --install <rel> <chart> -n <ns>          # install-or-upgrade
helm upgrade <rel> <chart> -n <ns> --set key=val --reuse-values --wait
helm upgrade <rel> <chart> -n <ns> -f custom.yaml --wait
helm rollback <rel> <revision> -n <ns> --wait
helm uninstall <rel> -n <ns>
helm uninstall <rel> -n <ns> --keep-history            # keep the audit trail
```

**Value precedence (low → high):** chart `values.yaml` → `-f file` → `--set`.

**⚠️ `--reuse-values`:** without it, an upgrade resets un-passed values to chart
defaults. With it, prior values are kept and you change only what you pass.

## Inspect releases

```bash
helm list                          # releases in current namespace
helm list -A                       # all namespaces
helm status <rel> -n <ns>          # current status + NOTES
helm history <rel> -n <ns>         # every revision
helm get values <rel> -n <ns>      # values in effect
helm get manifest <rel> -n <ns>    # the actual YAML applied
helm get all <rel> -n <ns>         # everything Helm knows
```

## Authoring your own chart

```bash
helm create mychart                # scaffold a starter chart
helm lint mychart                  # static checks
helm template <rel> mychart        # render to YAML locally (no cluster)
helm template <rel> mychart -f custom.yaml --set k=v      # with overrides
helm install <rel> mychart -n <ns> --dry-run --debug      # server-side validate
helm install <rel> ./mychart -n <ns>                      # install a LOCAL chart by path
helm package mychart               # build a versioned .tgz
helm dependency update mychart     # fetch sub-charts in Chart.yaml
```

## Template built-ins (in `templates/*.yaml`)

```
{{ .Values.key }}                       value from values.yaml / --set
{{ .Release.Name }}                     helm install <name>
{{ .Release.Namespace }}                target namespace
{{ .Chart.Name }} / {{ .Chart.Version }}   from Chart.yaml
{{ .Values.tag | default "latest" }}    value with fallback
{{ .Values.name | quote }}              wrap in quotes
{{- if .Values.x.enabled }}...{{- end }}   conditional
{{- range .Values.list }}...{{- end }}     loop
{{ include "myapp.labels" . | nindent 4 }} reuse a _helpers.tpl snippet
```
`{{-` trims whitespace before the tag; `-}}` trims after. Use `nindent N` to
indent a block correctly inside YAML.

## Release lifecycle mental model

```
install     → rev 1
upgrade      → rev 2, 3, ...      (never edits in place)
rollback N   → new rev that mirrors rev N
uninstall    → release + history gone (unless --keep-history)
```

---

## 14 interview Q&A

1. **What is Helm?** The package manager for Kubernetes — bundles manifests
   into a versioned *chart* and manages the install/upgrade/rollback lifecycle.
2. **Chart vs release vs repo?** Chart = the package; release = one installed
   instance of it; repo = an HTTP server hosting packaged charts.
3. **What changed in Helm 3?** Tiller (the cluster-side component) was removed;
   Helm is now client-only and uses your kubeconfig/RBAC. Release state moved
   to Secrets in the release namespace.
4. **Where is release state stored?** As a Secret (`helm.sh/release.v1`) in the
   release's namespace — one per revision.
5. **`helm install` vs `helm upgrade --install`?** The latter installs if the
   release is absent, upgrades if it exists (idempotent — great for CI).
6. **What does `--reuse-values` do?** Keeps the previous release's values and
   overrides only what you pass now; without it, un-passed values reset to
   chart defaults.
7. **Value precedence order?** `values.yaml` (chart) < `-f file` < `--set`.
8. **How do you preview changes safely?** `helm template` (local render),
   `--dry-run --debug` (server validate), or the `helm diff` plugin.
9. **What is `values.yaml`?** The chart's default configuration; users override
   per install.
10. **How does rollback work?** It creates a *new* revision whose manifests
    match the target revision — history is never deleted.
11. **`helm template` vs `helm install --dry-run`?** `template` renders purely
    client-side (no cluster); `--dry-run` also sends it to the API server for
    validation but creates nothing.
12. **What is `_helpers.tpl`?** A file of named template snippets (`define`/
    `include`) you reuse across manifests to stay DRY (e.g. a common label set).
13. **How do you install a local chart?** By path: `helm install app ./mychart`
    — no repo needed.
14. **How do sub-chart dependencies work?** Declared in `Chart.yaml`
    `dependencies:`, fetched with `helm dependency update` into `charts/`.

---

## Fast paths (this lab's scripts)

```bash
./scripts/install-helm.sh      # install Helm 3 (idempotent)
./scripts/deploy-bitnami.sh    # Phase 1: bitnami/nginx install + upgrade
./scripts/deploy-mychart.sh    # install the custom charts/myapp chart
./scripts/watch.sh             # live view of the demo namespace
./scripts/cleanup.sh           # remove releases + namespace
```
