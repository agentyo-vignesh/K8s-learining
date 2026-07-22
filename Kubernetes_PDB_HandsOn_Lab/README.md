# Kubernetes Pod Disruption Budget (PDB) Hands-on Lab

## Objective
Understand how Deployment, ReplicaSet, Scheduler, Node Drain and PodDisruptionBudget work together.

## Cluster Used
- 1 Control Plane
- 2 Worker Nodes

## Architecture

Deployment
    |
ReplicaSet
    |
+---------+---------+---------+
| Pod-1   | Pod-2   | Pod-3   |
+---------+---------+---------+
         ^
         |
        PDB (minAvailable: 2)

## Lab Flow

1. Create namespace
2. Deploy nginx (3 replicas)
3. Create PDB (minAvailable=2)
4. Verify pods
5. Drain the worker node
6. Observe pod eviction
7. Observe replacement pod
8. Observe PDB blocking further evictions

## Commands

kubectl apply -f pdb-demo.yaml

kubectl get pods -n pdb-demo -o wide

kubectl get pdb -n pdb-demo

kubectl describe pdb nginx-pdb -n pdb-demo

kubectl drain <worker-node> --ignore-daemonsets --delete-emptydir-data

kubectl uncordon <worker-node>

kubectl describe pod <pending-pod> -n pdb-demo

## Expected Behaviour

- One pod is evicted.
- Deployment creates a replacement pod.
- Replacement pod stays Pending if no schedulable node matches.
- PDB blocks further evictions.
- Drain waits until the PDB condition is satisfied.

## Key Concepts

Deployment
- Maintains desired state.

ReplicaSet
- Ensures desired replica count.

Scheduler
- Chooses a node for new pods.

PDB
- Protects application availability during voluntary disruptions.
- Works on pods selected by labels.
- Counts Ready pods across the entire cluster.
- Does NOT reference nodes.

kubectl drain
- Operates on a node.
- Before evicting each pod, Kubernetes checks for a matching PDB.

## Interview Questions

Q: Does PDB work at node level?
A: No. It works on pods selected by labels across the cluster.

Q: Why did the replacement pod remain Pending?
A: The nodeSelector matched only the drained node, which became SchedulingDisabled.

Q: Why did drain stop?
A: Evicting another pod would violate minAvailable.



==========================================
KUBERNETES PDB HANDS-ON LAB
==========================================

--------------------------------------------------
STEP 1 - VERIFY CLUSTER
--------------------------------------------------

kubectl get nodes

kubectl get pods -A

--------------------------------------------------
STEP 2 - CREATE NAMESPACE
--------------------------------------------------

kubectl create namespace pdb-demo

kubectl get ns

--------------------------------------------------
STEP 3 - APPLY YAML
--------------------------------------------------

kubectl apply -f pdb-demo.yaml

--------------------------------------------------
STEP 4 - VERIFY DEPLOYMENT
--------------------------------------------------

kubectl get deployment -n pdb-demo

kubectl describe deployment nginx -n pdb-demo

--------------------------------------------------
STEP 5 - VERIFY REPLICASET
--------------------------------------------------

kubectl get rs -n pdb-demo

kubectl describe rs -n pdb-demo

--------------------------------------------------
STEP 6 - VERIFY PODS
--------------------------------------------------

kubectl get pods -n pdb-demo

kubectl get pods -n pdb-demo -o wide

kubectl describe pod <pod-name> -n pdb-demo

--------------------------------------------------
STEP 7 - VERIFY SERVICE
--------------------------------------------------

kubectl get svc -n pdb-demo

kubectl describe svc nginx-service -n pdb-demo

--------------------------------------------------
STEP 8 - VERIFY PDB
--------------------------------------------------

kubectl get pdb -n pdb-demo

kubectl describe pdb nginx-pdb -n pdb-demo

--------------------------------------------------
STEP 9 - WATCH RESOURCES (OPEN 3 TERMINALS)
--------------------------------------------------

Terminal 1

kubectl get pods -n pdb-demo -o wide --watch

--------------------------------------------------

Terminal 2

kubectl get pdb -n pdb-demo --watch

--------------------------------------------------

Terminal 3

kubectl get nodes --watch

--------------------------------------------------
STEP 10 - DRAIN WORKER NODE
--------------------------------------------------

kubectl drain i-08613cafe1490da2b \
--ignore-daemonsets \
--delete-emptydir-data

--------------------------------------------------
STEP 11 - VERIFY AFTER DRAIN
--------------------------------------------------

kubectl get pods -n pdb-demo

kubectl get pods -n pdb-demo -o wide

kubectl get pdb -n pdb-demo

kubectl describe pdb nginx-pdb -n pdb-demo

--------------------------------------------------
STEP 12 - CHECK PENDING POD
--------------------------------------------------

kubectl describe pod <pending-pod-name> -n pdb-demo

Example

kubectl describe pod nginx-64f4657cbf-4fpc6 -n pdb-demo

--------------------------------------------------
STEP 13 - CHECK EVENTS
--------------------------------------------------

kubectl get events -n pdb-demo --sort-by=.lastTimestamp

kubectl get events -A --sort-by=.lastTimestamp

--------------------------------------------------
STEP 14 - UNCORDON NODE
--------------------------------------------------

kubectl uncordon i-08613cafe1490da2b

kubectl get nodes

--------------------------------------------------
STEP 15 - WATCH RECOVERY
--------------------------------------------------

kubectl get pods -n pdb-demo -o wide --watch

--------------------------------------------------
STEP 16 - CLEANUP
--------------------------------------------------

kubectl delete namespace pdb-demo

OR

kubectl delete -f pdb-demo.yaml

--------------------------------------------------
USEFUL DEBUG COMMANDS
--------------------------------------------------

kubectl get nodes -o wide

kubectl get pods -A -o wide

kubectl get deployment -A

kubectl get rs -A

kubectl get svc -A

kubectl get pdb -A

kubectl get events -A --sort-by=.lastTimestamp

kubectl describe node i-08613cafe1490da2b

kubectl top node

kubectl top pod -A

--------------------------------------------------
EXPECTED OBSERVATION
--------------------------------------------------

1. Three pods are Running.

2. PDB shows:
   Allowed Disruptions = 1

3. Run kubectl drain.

4. One pod goes to Terminating.

5. Deployment creates a new Pod.

6. New Pod remains Pending.

7. PDB changes:
   Allowed Disruptions = 0

8. Drain command waits.

9. Run kubectl uncordon.

10. Pending Pod becomes Running.

11. Drain completes successfully.