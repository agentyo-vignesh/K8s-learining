# 03 — Live Demo (Watch a Node Get Added)

> The fun part for the classroom. You'll create more pods than the current
> nodes can hold, so some go `Pending`, and the Cluster Autoscaler adds a brand
> new node **live** in front of the students.

---

## Open 4 terminals

Arrange them side by side so everyone can see all four at once.

### Terminal 1 — watch the nodes (a new one appears here)
```bash
# Refresh the node list every 2 seconds
watch -n 2 kubectl get nodes
```

### Terminal 2 — watch the pods
```bash
# Refresh the pod list every 2 seconds
watch -n 2 'kubectl get pods'
```

### Terminal 3 — the autoscaler's live log
```bash
# Tail CA logs, hide the instance dump, keep only scaling-related lines
kubectl logs -f -n kube-system deployment/cluster-autoscaler 2>&1 \
  | grep -v "static instance" \
  | grep -iE "scale|unschedul|node group|trigger"
```

### Terminal 4 — apply the load
```bash
# A heavy deployment: 30 pods, each reserving real resources
kubectl create deployment stress-test --image=nginx --replicas=30
```
```bash
# Give each pod resource requests — THIS is what makes them unschedulable
kubectl set resources deployment stress-test --requests=cpu=200m,memory=256Mi
```
> 💡 Script shortcut for Terminal 4: `./scripts/05-live-demo.sh`

---

## What students will see (timeline)

| Time | What happens | Which terminal shows it |
|---|---|---|
| 0 min | Pods → `Pending` | Terminal 2 |
| ~1 min | Log shows `unschedulable pods` | Terminal 3 |
| ~2 min | Log shows `Scale-up: group size to X` | Terminal 3 |
| ~4 min | New node → `NotReady` | Terminal 1 |
| ~6 min | Node → `Ready`, pods → `Running` | Terminal 1 & 2 |

**What just happened?** The 30 pods needed more CPU/memory than the existing
nodes had free, so the scheduler couldn't place some of them → they sat
`Pending`. CA saw the `Pending` pods, decided one more node would fix it, and
told the ASG to launch an EC2 instance. When that node joined and became
`Ready`, the pending pods were scheduled onto it.

---

## Bonus — show scale DOWN too

```bash
# Remove the load
kubectl delete deployment stress-test
```
> 💡 Or: `./scripts/05-live-demo.sh --down`

After **~10 minutes** (the default scale-down cooldown), the now-empty extra
node is removed automatically. The log (Terminal 3) will show a `Scale-down`
line.

> 💡 **Scale down is intentionally slow (for safety).** CA waits ~10 min of a
> node being underused before removing it, so a brief lull doesn't kill a node
> you'll need again moments later. Don't expect it to happen instantly.

---

## Teaching tips

- Pair this with the `hpa-lab` demo: run HPA first (pods multiply), watch them
  go `Pending` when nodes fill up, **then** CA adds a node. That's the full
  autoscaling story end to end.
- If nothing scales after ~3 min, jump to [`04-troubleshooting.md`](04-troubleshooting.md)
  — it's almost always missing ASG tags (Step 6) or `maxSize == minSize` (Step 1).
- Adjust `--replicas` to your node size so you reliably create `Pending` pods
  (bigger nodes → use more replicas or larger requests).

➡️ **Next:** keep [`04-troubleshooting.md`](04-troubleshooting.md) and
[`05-cheatsheet.md`](05-cheatsheet.md) open during the demo.
