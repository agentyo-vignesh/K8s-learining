#!/usr/bin/env bash
# ============================================================
# REAL USER SETUP  -  create a genuine 'intern' user on minikube
# using a client certificate signed by the cluster CA (CSR flow).
#
# After this, 'intern' can really log in (not just --as).
# Requires: openssl + kubectl (admin context = minikube)
# ============================================================
set -euo pipefail

USER=intern
GROUP=interns
NS=rbac-lab

echo "==> [1/6] Private key + CSR generate panrom (CN=user, O=group)"
openssl genrsa -out ${USER}.key 2048
openssl req -new -key ${USER}.key -out ${USER}.csr -subj "/CN=${USER}/O=${GROUP}"

echo "==> [2/6] Kubernetes CSR object create (cluster CA-ku sign request)"
kubectl delete csr ${USER} --ignore-not-found
CSR_B64=$(base64 -w0 ${USER}.csr 2>/dev/null || base64 ${USER}.csr | tr -d '\n')
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER}
spec:
  request: ${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400          # cert 1 day valid
  usages:
  - client auth
EOF

echo "==> [3/6] Admin approve panrom (nee = cluster-admin)"
kubectl certificate approve ${USER}

echo "==> [4/6] Signed certificate download panrom"
for i in $(seq 1 10); do
  CERT=$(kubectl get csr ${USER} -o jsonpath='{.status.certificate}')
  [ -n "$CERT" ] && break
  echo "    ...cert varala, wait ($i)"; sleep 1
done
echo "$CERT" | base64 -d > ${USER}.crt

echo "==> [5/6] kubeconfig-la 'intern' user + context add"
kubectl config set-credentials ${USER} \
  --client-key=${USER}.key \
  --client-certificate=${USER}.crt \
  --embed-certs=true
kubectl config set-context ${USER}-ctx \
  --cluster=minikube --user=${USER} --namespace=${NS}

echo "==> [6/6] Done! Ippo 'intern' real-a login pannalam:"
echo "    kubectl --context ${USER}-ctx get pods -n ${NS}"
