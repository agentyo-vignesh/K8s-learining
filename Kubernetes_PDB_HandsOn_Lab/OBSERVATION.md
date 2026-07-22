# Observation Sheet

## Before Drain

kubectl get pods -n pdb-demo -o wide

Expected:
3 Running Pods

kubectl get pdb -n pdb-demo

Expected:
Allowed Disruptions: 1

---

Drain

kubectl drain <worker-node> --ignore-daemonsets --delete-emptydir-data

---

Observe

One Pod -> Terminating

New Pod -> Pending

Remaining Running Pods -> 2

Allowed Disruptions -> 0

Drain waits.

---

Reason

Replacement pod cannot schedule because:

- nodeSelector
- node is SchedulingDisabled

PDB blocks another eviction because:

Available Pods = 2
minAvailable = 2
