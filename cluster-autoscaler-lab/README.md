# ☁️ Cluster Autoscaler Lab (kOps + AWS ASG)

A complete, hands-on lab for teaching the **Cluster Autoscaler (CA)** — the
Kubernetes component that adds and removes **worker nodes** (EC2) by driving the
AWS **Auto Scaling Group (ASG)**. Built from the "Cluster Autoscaler on kOps —
Complete Beginner Guide" and organized the same way as the sibling
[`../hpa-lab/`](../hpa-lab/).

> **Audience:** DevOps students who know basic `kubectl` and have (or will get)
> a kOps cluster on AWS.
> **Pairs with:** `hpa-lab` — HPA adds pods, CA adds the nodes those pods need.

---

## 🎯 Learning outcomes

By the end a student can:
- Explain ASG vs Cluster Autoscaler vs HPA vs VPA and how they cooperate.
- Understand why an ASG alone can't handle `Pending` pods.
- Set node instance-group min/max, tag ASGs, and deploy CA on kOps.
- Apply the three kOps-specific fixes (SSL dir, region, credentials).
- Run a live demo where a new node appears in front of the class.
- Debug the classic errors (MissingRegion, NoCredentialProviders, NotTriggerScaleUp).

---

## ✅ Prerequisites

| Need | Notes |
|---|---|
| A running **kOps** cluster on AWS | e.g. `kops.k8s.local` |
| `kubectl`, `kops`, `aws` CLIs | all on your PATH |
| AWS admin credentials | configured for the `aws` CLI |
| Node IGs with room to grow | `maxSize > minSize` (Step 1) |

> ⚠️ Unlike `hpa-lab` (which runs on minikube), this lab needs a **real AWS +
> kOps** cluster, because CA drives actual EC2 Auto Scaling Groups. It cannot
> be done on minikube.

---

## 📁 What's in this package

```
cluster-autoscaler-lab/
├── README.md                     ← you are here
├── docs/
│   ├── 01-concepts.md            ← ASG vs CA vs HPA vs VPA, how they work together (mermaid)
│   ├── 02-setup-guide.md         ← step-by-step kOps CA setup (every command + output)
│   ├── 03-live-demo.md           ← the 4-terminal "watch a node appear" demo
│   ├── 04-troubleshooting.md     ← error → cause → fix table (all 5 classic errors)
│   └── 05-cheatsheet.md          ← one-page commands + tags + 12 interview Q&A
├── manifests/
│   └── cluster-autoscaler.yaml   ← the full manifest (6 objects), 3 kOps fixes applied
├── scripts/
│   ├── config.sh                 ← shared settings (cluster name, region, ASGs)
│   ├── 01-prereqs-check.sh       ← verify tools + cluster + AWS access
│   ├── 02-create-secret.sh       ← create the aws-credentials Secret
│   ├── 03-tag-asgs.sh            ← tag the node ASGs for CA discovery
│   ├── 04-deploy.sh              ← apply CA, wait, tail logs
│   ├── 05-live-demo.sh           ← create Pending pods (and --down to scale in)
│   └── cleanup.sh                ← remove CA, Secret, and demo load
└── student-worksheet.md          ← blanks + error matching + predictions + tasks + answer key
```

---

## 🗺️ Recommended lab flow (~45–60 min)

| # | Do this | File |
|---|---|---|
| 1 | Read the theory | [`docs/01-concepts.md`](docs/01-concepts.md) |
| 2 | Set up CA step by step | [`docs/02-setup-guide.md`](docs/02-setup-guide.md) |
| 3 | Run the live node-scaling demo | [`docs/03-live-demo.md`](docs/03-live-demo.md) |
| 4 | Break & fix it | [`docs/04-troubleshooting.md`](docs/04-troubleshooting.md) |
| 5 | Test yourself | [`student-worksheet.md`](student-worksheet.md) |
| — | Keep for reference | [`docs/05-cheatsheet.md`](docs/05-cheatsheet.md) |

---

## ⚡ Quick start (scripted path)

The scripts are **Bash**. Edit [`scripts/config.sh`](scripts/config.sh) once
(cluster name, region, ASG names), then:

```bash
# From the cluster-autoscaler-lab/ directory (first time only)
chmod +x scripts/*.sh

# 0) Verify tools, cluster, and AWS access
./scripts/01-prereqs-check.sh

# 1) (manual) set maxSize > minSize on each node IG — see docs/02 Step 1
#    kops edit ig ... ; kops update cluster --name <cluster> --yes

# 2) Create the AWS credentials Secret (reads keys from env or aws CLI)
./scripts/02-create-secret.sh

# 3) Tag the node ASGs so CA can discover them
./scripts/03-tag-asgs.sh

# 4) Deploy CA and watch the startup logs
./scripts/04-deploy.sh

# 5) Live demo: force Pending pods → a new node appears
./scripts/05-live-demo.sh
#    ...then scale back in:
./scripts/05-live-demo.sh --down

# 6) Tear down the lab (leaves your cluster/nodes intact)
./scripts/cleanup.sh
```

> **Windows:** run the `.sh` scripts under **Git Bash** or **WSL**. The
> `kubectl` / `kops` / `aws` commands themselves are identical on PowerShell if
> you prefer to run the steps from [`docs/02-setup-guide.md`](docs/02-setup-guide.md) by hand.

---

## 🧠 The one-sentence summary

| Tool | What it does |
|---|---|
| ASG (alone) | Scales EC2 by CPU — not Kubernetes-aware |
| **Cluster Autoscaler** | **Adds a node when pods are `Pending`** |
| HPA | Adds more pods when load rises |
| VPA | Makes a pod bigger |

**HPA adds pods → if there's no room, CA adds a node.** That's the whole story.

---

## 🔐 Security note (please read before production)

This lab uses **static AWS keys** stored in a Kubernetes Secret — fine for
learning, **not** for production. For real clusters use **IRSA** (IAM Roles for
Service Accounts) or the node IAM role, then delete the Secret and the
`AWS_*_KEY` env blocks. Details in
[`docs/02-setup-guide.md`](docs/02-setup-guide.md#-production-hardening-optional-but-recommended).

Happy scaling! ☁️📈
