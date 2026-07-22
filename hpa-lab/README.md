# 🚀 Kubernetes HPA Training Lab

A complete, hands-on lab for teaching the **Horizontal Pod Autoscaler (HPA)**
on **minikube**. Students deploy a demo app, attach an HPA, generate load, and
watch Kubernetes scale pods **out** under pressure and **in** when idle — then
reinforce it with a worksheet and cheat sheet.

> **Audience:** DevOps students who know basic `kubectl` (pods, deployments,
> services) but are new to autoscaling.
> **API level:** all manifests use **`autoscaling/v2`** — no deprecated APIs.

---

## 🎯 Learning outcomes

By the end of this lab a student can:

- Explain what the HPA does and how it differs from the VPA and Cluster Autoscaler.
- Describe the HPA control loop (15s sync period) and the scaling formula.
- Enable and verify the metrics-server on minikube.
- Create an HPA both **imperatively** (`kubectl autoscale`) and **declaratively** (YAML).
- Drive load, observe live scale-out, and understand why scale-in is deliberately slow.
- Diagnose the classic failures (`<unknown>` targets, missing requests, metrics-server issues).

---

## ✅ Prerequisites

| Tool | Version (or newer) | Check command |
|---|---|---|
| minikube | v1.32+ | `minikube version` |
| kubectl | v1.29+ | `kubectl version --client` |
| A driver | Docker / Hyperkit / VirtualBox | `docker version` |
| Resources | ≥ 2 CPUs & 2 GB RAM free for minikube | — |

> No standalone `kubectl`? Use `minikube kubectl -- <args>` anywhere this lab
> says `kubectl`.

---

## 📁 What's in this package

```
hpa-lab/
├── README.md                 ← you are here
├── docs/
│   ├── 01-concepts.md        ← theory: HPA vs VPA vs CA, architecture, the formula (3 examples)
│   ├── 02-lab-guide.md       ← the hands-on walkthrough (every command + expected output)
│   ├── 03-troubleshooting.md ← symptom → cause → fix table for common HPA problems
│   └── 04-cheatsheet.md      ← one-page command + spec reference + 14 interview Q&A
├── manifests/
│   ├── deployment.yaml       ← php-apache Deployment (cpu 200m/500m) + Service
│   ├── hpa-basic.yaml        ← simple CPU 50% HPA (autoscaling/v2)
│   └── hpa-advanced.yaml     ← multi-metric (CPU+mem) HPA w/ behavior policies, fully commented
├── scripts/
│   ├── setup.sh              ← start minikube, enable metrics, wait for top, apply manifests
│   ├── load-test.sh          ← launch a busybox load generator
│   ├── watch.sh              ← live watch on the HPA / pods
│   └── cleanup.sh            ← tear down all lab resources
└── student-worksheet.md      ← fill-in-the-blanks + predictions + 5 tasks + answer key
```

---

## 🗺️ Recommended lab flow (~30–40 min)

| # | Do this | Time | File |
|---|---|---|---|
| 1 | Read the theory | 10 min | [`docs/01-concepts.md`](docs/01-concepts.md) |
| 2 | Run the hands-on lab | 20 min | [`docs/02-lab-guide.md`](docs/02-lab-guide.md) |
| 3 | Break something / debug | 5 min | [`docs/03-troubleshooting.md`](docs/03-troubleshooting.md) |
| 4 | Test yourself | 10 min | [`student-worksheet.md`](student-worksheet.md) |
| 5 | Keep for reference | — | [`docs/04-cheatsheet.md`](docs/04-cheatsheet.md) |

---

## ⚡ Quick start (the fast path)

The scripts are **Bash** (Linux/macOS, or Git Bash / WSL on Windows).

```bash
# 0) From the hpa-lab/ directory, make the scripts executable (first time only)
chmod +x scripts/*.sh

# 1) Start minikube, enable metrics-server, wait for metrics, deploy app + HPA
./scripts/setup.sh

# 2) In TERMINAL 1 — watch the HPA live
./scripts/watch.sh

# 3) In TERMINAL 2 — generate load and watch it scale out in Terminal 1
./scripts/load-test.sh
#    ...press Ctrl-C after a few minutes to stop the load and watch scale-in

# 4) Tear everything down when finished
./scripts/cleanup.sh
```

### Windows note

The `.sh` scripts run under **Git Bash** or **WSL**. If you're in native
**PowerShell**, run the equivalent `kubectl`/`minikube` commands directly from
[`docs/02-lab-guide.md`](docs/02-lab-guide.md) — every step there includes a
PowerShell variant where the syntax differs. The `kubectl` and `minikube`
commands themselves are identical across platforms.

---

## 🧭 Manual quick start (no scripts)

```bash
# Start cluster + metrics, then deploy
minikube start
minikube addons enable metrics-server
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/hpa-basic.yaml

# Verify (wait ~1 min for metrics to warm up)
kubectl top pods
kubectl get hpa php-apache
```

Then follow [`docs/02-lab-guide.md`](docs/02-lab-guide.md) from **Step 6**.

---

## 🧯 If something goes wrong

Most issues are the metrics-server or missing resource requests. Start here:

```bash
# The three-command triage
kubectl top pods                       # is the metrics pipeline alive?
kubectl describe hpa php-apache        # what does the HPA say? (read Events)
kubectl get hpa php-apache             # <unknown> vs a real %?
```

Full symptom → cause → fix table: [`docs/03-troubleshooting.md`](docs/03-troubleshooting.md).

---

## 👩‍🏫 Notes for the instructor

- **Timing expectations:** scale-**out** shows within ~15–60s; scale-**in**
  takes ~5 min by default (the 300s stabilization window). Warn students so
  they don't think it's broken — this is a great teaching moment.
- **The `<unknown>` demo:** to *deliberately* show the classic failure, apply
  the deployment with the CPU request removed, then apply the HPA — students
  see `<unknown>` and learn why requests matter. Restore with
  `kubectl apply -f manifests/deployment.yaml`.
- **Resource sizing:** if pods get stuck `Pending`, minikube likely needs more
  CPU/RAM: `minikube stop && minikube start --cpus=4 --memory=4096`.
- **Advanced extension:** have students tune `hpa-advanced.yaml`'s
  `behavior` block and observe how scale speed changes.

---

Happy autoscaling! 📈
