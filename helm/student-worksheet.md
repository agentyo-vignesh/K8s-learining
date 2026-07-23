# 🎓 Helm — Student Worksheet

> Fill this in as you work through the lab. Answers are at the bottom — try
> before you peek. Write your own answers in the blanks.

**Name:** ______________________   **Date:** ______________

---

## Part 1 — Fill in the blanks

1. Helm is the ________________ ________________ for Kubernetes.

2. The four core terms:
   - A ________________ is the package (templated manifests + defaults).
   - A ________________ is one installed instance of that package.
   - A ________________ is an HTTP server hosting packaged charts.
   - ________________ are the config that fills the template blanks.

3. Helm 3 removed the cluster-side component called ________________.

4. Helm stores each release's state as a ________________ in the release's
   namespace.

5. The value-precedence order (lowest → highest) is:
   `______________` → `______________` → `______________`.

6. To install a **local** chart you pass a ________________ instead of a
   `repo/name`.

7. `{{ .Release.Name }}` comes from ________________, while
   `{{ .Values.replicaCount }}` comes from ________________.

---

## Part 2 — Predict before you run

Before running each command, write what you expect, then check.

| Command | Your prediction | What actually happened |
|---|---|---|
| `helm list -A` (before installing anything) | | |
| `helm install web bitnami/nginx ...` → what REVISION? | | |
| `helm upgrade ... --set replicaCount=3` → REVISION? | | |
| `helm rollback web 1` → what new REVISION number? | | |
| `helm template app charts/myapp` (does it touch the cluster?) | | |

---

## Part 3 — Tasks

**Task 1.** Install Helm and prove it can reach your cluster. Paste the two
commands you used:
```
________________________________________________
________________________________________________
```

**Task 2.** Install `bitnami/nginx` as release `web` in namespace `demo`, then
scale it to 3 replicas **keeping all other values**. Write the upgrade command
(mind the flag that preserves prior values):
```
________________________________________________
```

**Task 3.** Print the release history and write how many revisions exist after
the upgrade: ________

**Task 4.** Roll back to revision 1. What revision number does `helm history`
now show as `deployed`? ________ (Why isn't it revision 1?) __________________

**Task 5.** For `charts/myapp`, override the replica count to 4 using a **values
file** (not `--set`). Write the two commands:
```
________________________________________________
________________________________________________
```

**Task 6.** Package `charts/myapp` into a `.tgz`. What is the exact filename
produced, and where does the version in it come from? ______________________

---

## Part 4 — Challenge (optional)

- Add an `ingress.yaml` template to `charts/myapp`, gated behind
  `{{- if .Values.ingress.enabled }}`, defaulting to `false` in `values.yaml`.
  Prove with `helm template` that it renders only when you pass
  `--set ingress.enabled=true`.
- Add a `_helpers.tpl` that defines a common label block and `include` it in
  both `deployment.yaml` and `service.yaml`.

---

## ✅ Answer key (no peeking!)

**Part 1**
1. package manager
2. chart / release / repository / values
3. Tiller
4. Secret (type `helm.sh/release.v1`)
5. chart `values.yaml` → `-f file.yaml` → `--set`
6. path (e.g. `helm install app ./charts/myapp`)
7. the install/release context (`helm install <name>`) / `values.yaml` (or `--set`)

**Part 2**
- `helm list -A` before anything → an **empty table** (headers only).
- First install → **REVISION 1**.
- Upgrade → **REVISION 2**.
- Rollback to 1 → creates **REVISION 3** (rollback makes a *new* revision).
- `helm template` → **no**, it renders locally and never touches the cluster.

**Part 3**
1. `helm version` and `helm list -A` (after installing via the get-helm-3 script).
2. `helm upgrade web bitnami/nginx -n demo --set replicaCount=3 --reuse-values --wait`
3. **2** revisions (install = 1, upgrade = 2).
4. `helm history` shows **revision 3** as `deployed`. Rollback doesn't restore
   the old revision in place — it applies rev 1's manifests as a brand-new
   revision (3), preserving the full timeline.
5. `cat > prod-values.yaml <<'EOF' ... replicaCount: 4 ... EOF` then
   `helm upgrade app charts/myapp -n demo -f prod-values.yaml --wait`
6. `myapp-0.1.0.tgz`. The `0.1.0` comes from the `version:` field in
   `charts/myapp/Chart.yaml`.
