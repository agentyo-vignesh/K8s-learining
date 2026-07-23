# ⎈ Helm Training Lab

A complete, hands-on lab for teaching **Helm 3** — the package manager for
Kubernetes — on a **kOps cluster running on AWS**. Students install Helm,
deploy a public chart (**bitnami/nginx**) through its full
install → upgrade → rollback → uninstall lifecycle, then **build and install
their own chart** from hand-written templates.

> **Audience:** DevOps students who know basic `kubectl` (pods, deployments,
> services) and have a running kOps cluster, but are new to Helm.
> **Platform:** kOps on AWS (LoadBalancer Services provision real ELBs).
> **Helm:** version 3 — no Tiller.

---

## 🎯 Learning outcomes

By the end of this lab a student can:

- Explain what Helm is and how *charts*, *releases*, *repositories*, and
  *values* relate.
- Describe the Helm 3 architecture (client-only, no Tiller) and where release
  state is stored.
- Install Helm and add/search chart repositories.
- Run the full lifecycle on a public chart: install → upgrade → history →
  rollback → uninstall.
- Scaffold a chart with `helm create`, understand every file, and hand-write
  their own templates.
- Override values three ways (`--set`, `-f file`, precedence) and package a
  chart as a `.tgz`.
- Diagnose the classic failures (name-in-use, stuck upgrades, `<empty>` ELB
  URLs, template parse errors).

---

## ✅ Prerequisites

| Requirement | Check command |
|---|---|
| A running kOps cluster | `kops get cluster` |
| `kubectl` pointed at it | `kubectl get nodes` (nodes `Ready`) |
| Outbound internet (to fetch charts) | `curl -I https://charts.bitnami.com/bitnami` |
| Bash shell (Git Bash / WSL on Windows) | `bash --version` |

> Helm reuses your kubeconfig — if `kubectl get nodes` works, Helm will too.

---

## 📁 What's in this package

```
helm/
├── README.md                    ← you are here
├── docs/
│   ├── 01-concepts.md           ← theory: chart/release/repo/values, Helm 3 arch, templating
│   ├── 02-lab-guide.md          ← Phase 1 walkthrough: install bitnami/nginx (every cmd + output)
│   ├── 03-create-chart.md       ← build your own chart: helm create + hand-written templates
│   ├── 04-troubleshooting.md    ← symptom → cause → fix table + deep dives + Windows notes
│   ├── 05-cheatsheet.md         ← one-page command reference + 14 interview Q&A
│   ├── 06-production-chart.md   ← prod-grade chart walkthrough + interview soundbites
│   └── 07-realtime-scenarios.md ← 1-hour real-world runbook (idempotent/atomic/per-env deploys)
├── charts/
│   ├── myapp/                   ← minimal hand-written chart (learn the basics)
│   │   ├── Chart.yaml           ← metadata
│   │   ├── values.yaml          ← default values
│   │   ├── .helmignore
│   │   └── templates/
│   │       ├── deployment.yaml  ← our own template
│   │       ├── service.yaml     ← our own template (LoadBalancer + annotations)
│   │       └── NOTES.txt        ← post-install message
│   └── webapp/                  ← PRODUCTION-GRADE chart (interview-ready)
│       ├── Chart.yaml
│       ├── values.yaml          ← fully-commented prod knobs
│       ├── .helmignore
│       └── templates/
│           ├── _helpers.tpl     ← reusable name/label snippets
│           ├── deployment.yaml  ← non-root, probes, resources, HPA-aware
│           ├── service.yaml
│           ├── serviceaccount.yaml  ← gated (IRSA-ready)
│           ├── hpa.yaml         ← gated by autoscaling.enabled
│           ├── ingress.yaml     ← gated by ingress.enabled
│           ├── NOTES.txt
│           └── tests/
│               └── test-connection.yaml  ← helm test smoke test
├── scripts/
│   ├── install-helm.sh          ← install Helm 3 (idempotent)
│   ├── deploy-bitnami.sh        ← Phase 1 fast path
│   ├── deploy-mychart.sh        ← install the minimal chart (lint → render → dry-run → install)
│   ├── deploy-webapp.sh         ← install the prod-grade chart + run helm test
│   ├── watch.sh                 ← live view of the demo namespace
│   └── cleanup.sh               ← remove all releases + namespace
└── student-worksheet.md         ← fill-in-the-blanks + predictions + 6 tasks + answer key
```

---

## 🗺️ Recommended lab flow (~60 min)

| # | Do this | Time | File |
|---|---|---|---|
| 1 | Read the theory | 10 min | [`docs/01-concepts.md`](docs/01-concepts.md) |
| 2 | Phase 1: install a public chart | 20 min | [`docs/02-lab-guide.md`](docs/02-lab-guide.md) |
| 3 | Phase 2: build your own (minimal) chart | 20 min | [`docs/03-create-chart.md`](docs/03-create-chart.md) |
| 4 | Phase 3: production-grade chart + interview prep | 20 min | [`docs/06-production-chart.md`](docs/06-production-chart.md) |
| 5 | Break something / debug | 5 min | [`docs/04-troubleshooting.md`](docs/04-troubleshooting.md) |
| 6 | Test yourself | 10 min | [`student-worksheet.md`](student-worksheet.md) |
| 7 | Keep for reference | — | [`docs/05-cheatsheet.md`](docs/05-cheatsheet.md) |

---

## ⚡ Quick start (the fast path)

The scripts are **Bash** (run on the kOps admin box, or Git Bash / WSL on Windows).

```bash
# 0) From the helm/ directory, make the scripts executable (first time only)
chmod +x scripts/*.sh

# 1) Install Helm 3 (skips if already installed)
./scripts/install-helm.sh

# 2) PHASE 1 — install/upgrade/rollback the public bitnami/nginx chart
./scripts/deploy-bitnami.sh

# 3) PHASE 2 — install YOUR OWN minimal chart (charts/myapp)
./scripts/deploy-mychart.sh

# 4) PHASE 3 — install the PRODUCTION-GRADE chart + run its helm test (charts/webapp)
./scripts/deploy-webapp.sh

# 5) Watch things live (optional, separate terminal)
./scripts/watch.sh

# 6) Tear everything down when finished
./scripts/cleanup.sh
```

---

## 🧭 Manual quick start (no scripts)

```bash
# Install Helm + verify it reaches the cluster
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version && helm list -A

# Phase 1 — public chart
helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
helm install web bitnami/nginx -n demo --create-namespace --wait --timeout 5m

# Phase 2 — your own chart
helm lint charts/myapp
helm install app charts/myapp -n demo --create-namespace --wait
```

Then follow [`docs/02-lab-guide.md`](docs/02-lab-guide.md) and
[`docs/03-create-chart.md`](docs/03-create-chart.md) for the full walkthroughs.

---

## 🧯 If something goes wrong

```bash
# The three-command triage
helm list -A                      # can Helm reach the cluster? (empty = yes)
helm status <release> -n demo     # what does the release say?
kubectl get all -n demo           # what actually got created?
```

Full symptom → cause → fix table: [`docs/04-troubleshooting.md`](docs/04-troubleshooting.md).

---

## 👩‍🏫 Notes for the instructor

- **ELB timing:** LoadBalancer Services provision a real AWS ELB — the URL
  stays empty for ~2-3 min. Warn students so they don't think it's broken.
- **Cost reminder:** each `LoadBalancer` Service = a billable ELB. Always run
  `./scripts/cleanup.sh` at the end of the session.
- **`--reuse-values` teaching moment:** run an upgrade with `--set` *without*
  `--reuse-values` and show how un-passed values silently revert to defaults.
  This is the #1 real-world Helm footgun.
- **Local vs repo charts:** stress that Phase 1 installs `bitnami/nginx` (repo)
  while Phase 2 installs `charts/myapp` (a path). Different install syntax.
- **Security groups:** if the ELB URL resolves but won't load, it's almost
  always a port-80 security-group rule, not Helm.

---

Happy Helming! ⎈
