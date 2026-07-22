#!/usr/bin/env bash
# =============================================================================
#  create-user.sh  -  ALL-IN-ONE: minikube-la oru REAL user create panradhu
# -----------------------------------------------------------------------------
#  Idhu onnu run pannா pothum. Ithukulla ellam iruku:
#    1. Namespace create
#    2. User-ku client certificate (cluster CA sign panradhu - CSR flow)
#    3. kubeconfig-la user + context add (real login)
#    4. Role + RoleBinding apply (embedded - vera file venaam)
#    5. Auto test (allow/deny verify)
#
#  Vera edha .yaml file-um apply panna vendaam - ellam inga embedded.
#  Requires: kubectl (admin=minikube context) + openssl
# =============================================================================
set -euo pipefail

# ------------------------------------------------------------------
# CONFIG  -  inga maathikonga (username / namespace / permissions)
# ------------------------------------------------------------------
USER="intern"                 # user oda peru  (cert CN = idhu)
GROUP="interns"               # group peru     (cert O  = idhu)
NS="rbac-lab"                 # eந்த namespace-la work pannuvaanga
ROLE_NAME="pod-reader"        # role peru
VERBS='["get","list","watch"]'   # enna panna mudiyum (read-only inga)
RESOURCES='["pods"]'          # edha access panna mudiyum
DAYS_VALID=86400              # cert validity (seconds) = 1 naal

echo "############################################################"
echo "#  Creating user '${USER}' in namespace '${NS}'"
echo "############################################################"

# ------------------------------------------------------------------
# 0. Minikube run aaguthaa nu check (illana script nikkum)
# ------------------------------------------------------------------
if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: cluster reach aagala. First 'minikube start' pannunga." >&2
  exit 1
fi

# ------------------------------------------------------------------
# 1. NAMESPACE  -  illana create, irundhaa error illa (idempotent)
# ------------------------------------------------------------------
echo "==> [1/6] Namespace '${NS}' ensure panrom"
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

# ------------------------------------------------------------------
# 2. KEY + CSR  -  user-oda private key, appuram signing request
#    CN=username -> Kubernetes idha 'User' name-a paakum
#    O=group     -> Kubernetes idha 'Group' name-a paakum
# ------------------------------------------------------------------
echo "==> [2/6] Private key + CSR generate (openssl)"
openssl genrsa -out "${USER}.key" 2048
openssl req -new -key "${USER}.key" -out "${USER}.csr" -subj "/CN=${USER}/O=${GROUP}"

# ------------------------------------------------------------------
# 3. CSR -> Kubernetes-ku submit + admin approve
#    cluster-oda CA idha sign pannum (real, trusted cert)
# ------------------------------------------------------------------
echo "==> [3/6] Kubernetes CSR create + approve"
kubectl delete csr "${USER}" --ignore-not-found          # pazhaya CSR clean
CSR_B64=$(base64 -w0 "${USER}.csr" 2>/dev/null || base64 "${USER}.csr" | tr -d '\n')
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER}
spec:
  request: ${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client   # client-auth cert
  expirationSeconds: ${DAYS_VALID}
  usages:
  - client auth
EOF
kubectl certificate approve "${USER}"                    # admin (nee) approve

# ------------------------------------------------------------------
# 4. Signed cert download  (approve aana odane populate aagum)
# ------------------------------------------------------------------
echo "==> [4/6] Signed certificate download"
for i in $(seq 1 10); do
  CERT=$(kubectl get csr "${USER}" -o jsonpath='{.status.certificate}')
  [ -n "${CERT}" ] && break
  echo "    ...cert varala, wait ${i}s"; sleep 1
done
echo "${CERT}" | base64 -d > "${USER}.crt"

# ------------------------------------------------------------------
# 5. kubeconfig-la user + context add  ->  real login ready
# ------------------------------------------------------------------
echo "==> [5/6] kubeconfig-la user + context add"
kubectl config set-credentials "${USER}" \
  --client-key="${USER}.key" \
  --client-certificate="${USER}.crt" \
  --embed-certs=true
kubectl config set-context "${USER}-ctx" \
  --cluster=minikube --user="${USER}" --namespace="${NS}"

# ------------------------------------------------------------------
# 6. ROLE + ROLEBINDING apply (embedded - vera file venaam)
#    Role       = enna panna mudiyum (permissions)
#    RoleBinding = antha role-a user-ku kattaradhu (attach)
# ------------------------------------------------------------------
echo "==> [6/6] Role + RoleBinding apply (embedded)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${ROLE_NAME}
  namespace: ${NS}
rules:
- apiGroups: [""]
  resources: ${RESOURCES}
  verbs: ${VERBS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${USER}-${ROLE_NAME}
  namespace: ${NS}
subjects:
- kind: User
  name: ${USER}                 # <- namma create panna user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ${ROLE_NAME}
  apiGroup: rbac.authorization.k8s.io
EOF

# =============================================================================
#  DONE - auto verify (real login test)
# =============================================================================
echo ""
echo "############################################################"
echo "#  DONE!  '${USER}' ready. Verify panrom:"
echo "############################################################"
echo "--> ALLOW test  (get pods -> WORK aaganum):"
kubectl --context "${USER}-ctx" auth can-i list pods -n "${NS}"
echo "--> DENY test   (delete pods -> 'no' varanum):"
kubectl --context "${USER}-ctx" auth can-i delete pods -n "${NS}"
echo ""
echo "Manual-a try panna:"
echo "  kubectl --context ${USER}-ctx get pods -n ${NS}          # works"
echo "  kubectl --context ${USER}-ctx delete pod --all -n ${NS}  # Forbidden"
echo "  kubectl config use-context minikube                      # admin-ku thirumba vara"
