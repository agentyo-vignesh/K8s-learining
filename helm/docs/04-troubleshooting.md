# 04 — Troubleshooting

> Symptom → cause → fix. Start with the three-command triage, then find your
> symptom below.

---

## The three-command triage

```bash
# 1) Can Helm even reach the cluster? (empty table = yes, healthy)
helm list -A

# 2) What does the release itself say?
helm status <release> -n <ns>

# 3) What actually got created / what's failing?
kubectl get all -n <ns>
kubectl describe pod <pod> -n <ns>    # read the Events at the bottom
```

---

## Symptom → cause → fix

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error: Kubernetes cluster unreachable` | kubeconfig not pointed at the cluster | `kops export kubeconfig --admin` then `kubectl get nodes` |
| `helm: command not found` | Helm not installed / not on PATH | Re-run `./scripts/install-helm.sh`; check `which helm` |
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | Release name already exists | `helm upgrade --install <name> ...` **or** `helm uninstall <name> -n <ns>` first |
| `Error: ... namespaces "demo" not found` | Namespace doesn't exist | Add `--create-namespace` to the install |
| Install hangs then `timed out waiting for the condition` | `--wait` waiting on pods that never go Ready | `kubectl get pods -n <ns>`; `kubectl describe pod ...`; fix the pod, then upgrade |
| Pod stuck `ImagePullBackOff` | Bad `image.repository` / `image.tag` | Fix the value, `helm upgrade ... --set image.tag=<good>` |
| Pod stuck `Pending` | No schedulable node / not enough CPU/mem | `kubectl describe pod` → check Events; scale nodes / lower requests |
| `Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress` | A prior op crashed mid-flight | `helm rollback <name> <last-good-rev> -n <ns>`; if truly stuck see "pending-upgrade" below |
| ELB URL prints empty (`http://`) | AWS LoadBalancer not provisioned yet | Wait 2-3 min; `kubectl get svc -n <ns>`; check the `EXTERNAL-IP`/hostname column |
| ELB URL resolves but page won't load | Security group blocks port 80 | Allow inbound 80 on the node/ELB security group |
| Upgrade silently reverted my config | Used `--set` **without** `--reuse-values` | Re-apply with `--reuse-values`, or better, keep config in a `-f values.yaml` |
| `helm lint` error: `[ERROR] templates/: parse error` | Bad Go-template syntax (unclosed `{{ }}`, bad indent) | `helm template <chart>` to see the exact line; fix the tag |
| Rendered YAML indentation is wrong | Missing `nindent`/`indent` or stray whitespace | Use `{{ ... | nindent N }}`; add `{{-`/`-}}` to trim |
| `Error: found in Chart.yaml, but missing in charts/ directory` | Declared a dependency but didn't fetch it | `helm dependency update <chart>` |

---

## Deep dives

### "Cluster unreachable" / auth issues (kOps)

```bash
# Re-export admin kubeconfig for the kOps cluster
kops export kubeconfig --name <cluster-name> --admin

# Confirm the context and connectivity
kubectl config current-context
kubectl get nodes
```
Helm uses the **exact same kubeconfig as kubectl**. If `kubectl get nodes`
works, Helm will too.

### A release is stuck in `pending-upgrade` / `pending-install`

```bash
# See the status
helm status <release> -n <ns>          # shows STATUS: pending-upgrade

# Option 1 (preferred): roll back to the last good revision
helm history <release> -n <ns>
helm rollback <release> <good-rev> -n <ns>

# Option 2 (last resort): uninstall and reinstall
helm uninstall <release> -n <ns>
helm install <release> <chart> -n <ns> --create-namespace
```

### See exactly what Helm will apply (before it fails on the cluster)

```bash
# Render locally — no cluster, shows the final YAML
helm template <release> <chart> -f my-values.yaml

# Or validate against the API server without creating anything
helm install <release> <chart> -n <ns> --dry-run --debug
```

### Diff what an upgrade *would* change (optional plugin)

```bash
# One-time: install the diff plugin
helm plugin install https://github.com/databus23/helm-diff

# Preview the change set of an upgrade
helm diff upgrade <release> <chart> -n <ns> -f my-values.yaml
```

---

## Windows notes

The `.sh` scripts and the `curl | bash` installer need **Git Bash** or **WSL**.
In native **PowerShell**:

- `helm` / `kubectl` commands themselves are **identical** — run them directly.
- The `echo "http://$(...)"` URL trick is Bash. PowerShell equivalent:
  ```powershell
  $h = kubectl get svc web-nginx -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  "http://$h"
  ```
- Install Helm on Windows with: `choco install kubernetes-helm` or
  `winget install Helm.Helm`.
- Heredocs (`cat > file <<'EOF'`) are Bash — in PowerShell create the values
  file with an editor or `Set-Content`.

---

Full command reference → [`05-cheatsheet.md`](05-cheatsheet.md).
