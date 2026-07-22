# REAL USER CREATE — Step by Step (one by one)

Minikube la oru **real user** (`intern`) create panradhu, client certificate use panni.
Idhu `--as` impersonation illa — **real login**. Cluster CA cert-a sign pannum (CSR flow).

> Ellam **admin context** (`minikube`) la run pannanum. User certificate use panni intern login aaganum.

**Config (namma use panra values):**

| Item        | Value        | Enna idhu                         |
|-------------|--------------|-----------------------------------|
| USER        | `intern`     | user peru → cert CN                |
| GROUP       | `interns`    | group peru → cert O                |
| NS          | `rbac-lab`   | eந்த namespace la work pannuvaanga |
| ROLE        | `pod-reader` | read-only pods access             |

---

## STEP 0 — Cluster iruka nu check

```bash
kubectl get nodes
```
Nodes list vந்தா cluster ready. Illana `minikube start` pannunga.

---

## STEP 1 — Namespace create

```bash
kubectl create namespace rbac-lab
```
User eng work pannuvaango antha namespace. Already irundhaa "AlreadyExists" — parava illa.

---

## STEP 2 — Private key + CSR generate (user side)

```bash
openssl genrsa -out intern.key 2048
openssl req -new -key intern.key -out intern.csr -subj "/CN=intern/O=interns"
```

- `intern.key` = user oda **private key** (idhu secret, user kitta than irukkum).
- `intern.csr` = **signing request** (cluster kitta "en cert-a sign pannu" nu kekaradhu).
- `CN=intern` → Kubernetes idha **User name** ah paakum.
- `O=interns` → Kubernetes idha **Group name** ah paakum.

---

## STEP 3 — CSR-a Kubernetes-ku submit pannu

```bash
# pazhaya CSR irundhaa clean pannu
kubectl delete csr intern --ignore-not-found

# csr file-a base64 pannu
CSR_B64=$(base64 -w0 intern.csr)

# CSR object create
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: intern
spec:
  request: ${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client   # client-auth cert
  expirationSeconds: 86400                            # 1 naal valid
  usages:
  - client auth
EOF
```

Ippo status paaru — `Pending` ah irukkum:
```bash
kubectl get csr intern
```

---

## STEP 4 — Admin approve pannu

```bash
kubectl certificate approve intern
```
Nee (cluster-admin) than approve panra. Ippo cluster CA cert-a **sign** pannum.

Check pannu — `Approved,Issued`:
```bash
kubectl get csr intern
```

---

## STEP 5 — Signed certificate download

```bash
kubectl get csr intern -o jsonpath='{.status.certificate}' | base64 -d > intern.crt
```
Idhu than cluster sign panna **real trusted certificate** (`intern.crt`).

---

## STEP 6 — kubeconfig la user + context add

```bash
# user credentials add (key + cert embed)
kubectl config set-credentials intern \
  --client-key=intern.key \
  --client-certificate=intern.crt \
  --embed-certs=true

# context create (user + cluster + namespace)
kubectl config set-context intern-ctx \
  --cluster=minikube --user=intern --namespace=rbac-lab
```
Ippo `intern-ctx` use panna **real-a intern-a login** pannalaam.

---

## STEP 7 — Role + RoleBinding apply (permissions kudu)

Idhu illama login pannalaam, aana **onnum panna mudiyaadhu** (Forbidden).
Role = enna panna mudiyum, RoleBinding = antha role-a user-ku kattaradhu.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-lab
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list","watch"]        # read-only mattum
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: intern-pod-reader
  namespace: rbac-lab
subjects:
- kind: User
  name: intern                          # namma create panna user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

---

## STEP 8 — Verify (real login test)

```bash
# ALLOW — pods paaka mudiyum (yes varanum)
kubectl --context intern-ctx auth can-i list pods -n rbac-lab
kubectl --context intern-ctx get pods -n rbac-lab

# DENY — delete panna mudiyaadhu (Forbidden varanum, Role la delete illa)
kubectl --context intern-ctx delete pod --all -n rbac-lab

# DENY — vera namespace / secrets (Forbidden)
kubectl --context intern-ctx get pods -n kube-system
kubectl --context intern-ctx get secrets -n rbac-lab
```

---

## Admin context-ku thirumba vara

```bash
kubectl config use-context minikube
```

---

## Cleanup (venumna)

```bash
kubectl delete csr intern --ignore-not-found
kubectl config delete-context intern-ctx
kubectl config delete-user intern
kubectl delete rolebinding intern-pod-reader -n rbac-lab
kubectl delete role pod-reader -n rbac-lab
rm -f intern.key intern.csr intern.crt
```

---

### Quick recap (order)

```
0. kubectl get nodes            # cluster check
1. create namespace             # rbac-lab
2. openssl key + csr            # user identity
3. CSR submit                   # kubectl apply csr
4. certificate approve          # admin sign
5. download intern.crt          # signed cert
6. kubeconfig user + context    # login ready
7. Role + RoleBinding           # permissions
8. verify (allow / deny)        # test
```

> Ellame ஒரே command la venumna → `bash create-user.sh`
