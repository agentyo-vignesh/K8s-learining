# 🎓 Student Worksheet — Kubernetes HPA

**Name:** ____________________________   **Date:** ______________

> Complete Parts A–C. Try everything **before** peeking at the Answer Key at
> the bottom. Formula reminder:
> `desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)`
> (with a ±10% tolerance dead-band, then clamped to min/max).

---

## Part A — Fill in the blanks

1. The HPA scales the ______________ of pods; this is called ______________
   scaling (as opposed to *vertical* scaling done by the VPA).

2. The HPA reads CPU and memory metrics from the ______________ component,
   which serves the `______________.k8s.io` API.

3. By default the HPA controller re-evaluates every HPA object every
   ______________ seconds.

4. With `type: Utilization`, the target percentage is measured against the
   container's resource ______________ (not its limit).

5. If a Deployment has **no** CPU request, the HPA `TARGETS` column shows
   ______________ and the app never scales.

6. The default scale-**down** stabilization window is ______________ seconds,
   which is why scaling in is slower than scaling out.

7. When an HPA has multiple metrics, it picks the ______________ desired
   replica count among them ("____ wins").

8. The correct API version for a modern HPA manifest is `autoscaling/____`.

9. The HPA only averages metrics across pods that are in the ____________
   state (unready pods are excluded).

10. To enable metrics on minikube you run:
    `minikube addons enable ______________`.

---

## Part B — Predict the replica count

Show the formula, then the result. Remember `ceil()` rounds **up**, the
±10% tolerance means "no change" when `current/target` is between 0.9 and 1.1,
and the result is clamped to `[minReplicas, maxReplicas]`.

**Q1.** currentReplicas = 2, target = 50%, current avg = 100%
→ desiredReplicas = ______

**Q2.** currentReplicas = 3, target = 50%, current avg = 200%
→ desiredReplicas = ______

**Q3.** currentReplicas = 4, target = 60%, current avg = 30%
→ desiredReplicas = ______

**Q4.** currentReplicas = 1, target = 50%, current avg = 250%,
minReplicas = 1, **maxReplicas = 4**
→ desiredReplicas = ______  (watch the ceiling!)

**Q5.** currentReplicas = 5, target = 50%, current avg = 52%
→ desiredReplicas = ______  (think about the tolerance band)

**Q6.** currentReplicas = 2, target = 50%, current avg = 75%
→ desiredReplicas = ______

---

## Part C — Hands-on tasks (check each box when done)

- [ ] **Task 1 — Bring the lab up.** Run `./scripts/setup.sh` (or do
      Steps 1–5 of the lab guide manually). Confirm `kubectl top nodes`
      returns real numbers and `kubectl get hpa` shows `cpu: 0%/50%`.
      _Write the initial REPLICAS value you see:_ ______

- [ ] **Task 2 — Trigger a scale-out.** In two terminals, run `watch.sh`
      and `load-test.sh`. Watch the HPA. _Record the **highest** REPLICAS
      count you observe and the peak CPU % in TARGETS:_
      REPLICAS = ______  , peak CPU = ______%

- [ ] **Task 3 — Read the HPA's mind.** Run `kubectl describe hpa php-apache`
      and find the **Events** section. _Copy one `SuccessfulRescale` message
      and its stated reason:_
      ________________________________________________________________

- [ ] **Task 4 — Observe scale-in.** Stop the load (Ctrl-C). Keep watching.
      _How long (roughly) after CPU dropped to ~0% did REPLICAS return to 1?_
      ______  _Explain in one sentence WHY it took that long:_
      ________________________________________________________________

- [ ] **Task 5 — Go multi-metric.** Delete the basic HPA and apply
      `manifests/hpa-advanced.yaml`. Run `kubectl get hpa php-apache-advanced`.
      _Write the TARGETS string showing BOTH metrics:_
      ________________________________________________________________

**Bonus (optional):** Edit `hpa-advanced.yaml` to set
`scaleDown.stabilizationWindowSeconds: 30`, re-apply, and re-test. Did
scale-in get faster? ______

---

## Part D — Short answer

1. In one sentence, why must a workload declare resource **requests** for a
   `Utilization`-based HPA to work?
   ____________________________________________________________________

2. Your HPA is at `maxReplicas` and pods are `Pending`. Which autoscaler
   (not the HPA) is responsible for fixing this, and what does it do?
   ____________________________________________________________________

---
---

# ✅ Answer Key (no peeking until you've tried!)

### Part A
1. **number** of pods; **horizontal**
2. **metrics-server**; **metrics** (`metrics.k8s.io`)
3. **15**
4. **request**
5. **`<unknown>`**
6. **300**
7. **highest** ("**max** wins")
8. **v2** (`autoscaling/v2`)
9. **Ready**
10. **metrics-server**

### Part B
- **Q1.** `ceil(2 × 100/50) = ceil(4.0) =` **4**
- **Q2.** `ceil(3 × 200/50) = ceil(12.0) =` **12**
- **Q3.** `ceil(4 × 30/60) = ceil(2.0) =` **2**
- **Q4.** `ceil(1 × 250/50) = ceil(5.0) = 5`, but `maxReplicas = 4` ⇒ clamped to **4**
- **Q5.** ratio `= 52/50 = 1.04`, inside the 0.9–1.1 tolerance ⇒ **no change, stays 5**
- **Q6.** `ceil(2 × 75/50) = ceil(3.0) =` **3**

### Part C (expected observations)
- **Task 1:** REPLICAS = **1** initially.
- **Task 2:** REPLICAS typically peaks around **5–10** (often 7); peak CPU well
  above target, often **200–300%** before pods spread the load.
- **Task 3:** e.g. `New size: 4; reason: cpu resource utilization above target`.
- **Task 4:** roughly **~5 minutes** — because of the default **300s scale-down
  stabilization window** that prevents flapping.
- **Task 5:** e.g. `cpu: 0%/50%, memory: 12%/70%` (two metrics shown together).
- **Bonus:** Yes — a smaller `stabilizationWindowSeconds` makes scale-in faster
  (at the cost of more potential flapping).

### Part D
1. Because `Utilization` is a **percentage of the request**; with no request
   there is no denominator, so the HPA can't compute a percentage (shows
   `<unknown>`).
2. The **Cluster Autoscaler** — it detects unschedulable (`Pending`) pods and
   **adds nodes** so the pods have somewhere to run. (HPA scales pods; CA
   scales nodes.)
