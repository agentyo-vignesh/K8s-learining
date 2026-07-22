# 🎓 Student Worksheet — Cluster Autoscaler on kOps

**Name:** ____________________________   **Date:** ______________

> Complete Parts A–D. Try everything before checking the Answer Key at the
> bottom.

---

## Part A — Fill in the blanks

1. Kubernetes has two levels of scaling: **pod** scaling (HPA/VPA) and
   ______________ scaling (Cluster Autoscaler).

2. The Cluster Autoscaler watches for ______________ pods (pods that can't be
   scheduled) and reacts by adding a ______________.

3. An AWS ASG on its own is **not** ______________-aware, so it can't react to
   a `Pending` pod.

4. "CA = the ______________, ASG = the ______________." (CA decides, ASG acts.)

5. For CA to scale, the instance group's `maxSize` must be ______________ than
   `minSize`.

6. CA discovers which ASGs to manage using ______________ (two of them per ASG).

7. The three kOps-specific fixes to the CA manifest are:
   (a) mount `/etc/ssl/certs` as a ______________,
   (b) set the ______________ env var,
   (c) provide AWS ______________.

8. Scale-**down** is slow — it waits about ______________ minutes before
   removing an underused node.

9. In production, instead of static keys you should use ______________ (IAM
   Roles for Service Accounts).

10. HPA adds ______________; if there's no room, CA adds a ______________.

---

## Part B — Match the error to its fix

Draw a line (or write the letter):

| Error | | Fix |
|---|---|---|
| 1. `MissingRegion` | | A. Add the two `k8s.io/cluster-autoscaler/*` tags to the ASGs |
| 2. `NoCredentialProviders` | | B. Set `env: AWS_REGION` |
| 3. `NotTriggerScaleUp / 0 ASGs` | | C. Mount `/etc/ssl/certs` as a directory |
| 4. `CrashLoop: ...ca-bundle.crt not a directory` | | D. Create the `aws-credentials` Secret |
| 5. `Skipping node group - max size reached` | | E. Raise `maxSize` (or celebrate — it's working!) |

Answers: 1-__  2-__  3-__  4-__  5-__

---

## Part C — Predict the outcome

**Q1.** An IG has `minSize: 2, maxSize: 2`. 5 pods go `Pending`. What will CA do?
______________________________________________________________________

**Q2.** The ASGs have **no** cluster-autoscaler tags. A pod is `Pending`. What
does the CA log say, and does a node get added?
______________________________________________________________________

**Q3.** You delete a big deployment and all extra nodes are now empty. How long
until CA removes them, roughly, and why the wait?
______________________________________________________________________

---

## Part D — Hands-on tasks (check each box)

- [ ] **Task 1 — Prep.** Set `maxSize=5` on both node IGs and apply. _Write the
      command you used to apply:_ ________________________________

- [ ] **Task 2 — Secret + tags.** Create the `aws-credentials` Secret and tag
      both ASGs. Verify the tags. _Paste the two tag keys you see:_
      ________________________________________________________________

- [ ] **Task 3 — Deploy.** Apply the manifest and confirm the pod is `Running`.
      _Write the READY value:_ ______

- [ ] **Task 4 — Logs.** Tail the logs. _Copy the success line you see (e.g.
      "Starting main loop"):_ ________________________________________

- [ ] **Task 5 — Live demo.** Run the stress-test (30 pods). _Record: how many
      pods went `Pending`_ ______ _and how many minutes until a new node was_
      `Ready`: ______

**Bonus:** Delete the stress-test. Did a node get removed? After how long? ______

---
---

# ✅ Answer Key (no peeking!)

### Part A
1. **node** 2. **Pending** / **node** 3. **Kubernetes** 4. **brain** / **hands**
5. **larger** 6. **tags** 7. (a) **directory** (b) **AWS_REGION** (c) **credentials**
8. **~10** 9. **IRSA** 10. **pods** / **node**

### Part B
1-**B**  2-**D**  3-**A**  4-**C**  5-**E**

### Part C
- **Q1.** Nothing — `maxSize == minSize == 2`, so there's no headroom. CA logs
  "max size reached" / skips the group; the pods stay `Pending`.
- **Q2.** The log shows `NotTriggerScaleUp` and "0 ASGs" — CA discovered no
  taggable node groups, so **no node is added**. Fix: add the discovery tags.
- **Q3.** About **~10 minutes** (the scale-down cooldown). CA waits so a brief
  lull doesn't destroy a node you'll need again seconds later (safety).

### Part D (expected)
- **Task 1:** `kops update cluster --name <cluster> --yes`
- **Task 2:** `k8s.io/cluster-autoscaler/enabled` and
  `k8s.io/cluster-autoscaler/<cluster>`
- **Task 3:** `1/1`
- **Task 4:** e.g. `Registered ASGs` / `Starting main loop`
- **Task 5:** several pods `Pending`; new node `Ready` in ~4–6 minutes.
- **Bonus:** yes, the empty node is removed after ~10 min.
