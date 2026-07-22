#!/usr/bin/env bash
# Kubernetes Lab: ConfigMaps & Secrets — all commands in order
# Run step by step, not blindly as a script.

# ---- Prerequisites ----
kubectl version --short
kubectl get nodes                          # at least one node Ready

kubectl create namespace cm-lab
kubectl config set-context --current --namespace=cm-lab

# ---- Part 1: Creating ConfigMaps ----
# 1a. from literals
kubectl create configmap app-config \
  --from-literal=APP_COLOR=blue \
  --from-literal=APP_MODE=production
kubectl get configmaps
kubectl describe configmap app-config

# 1b. from a file
echo "log_level=debug" > app.properties
echo "cache_ttl=300" >> app.properties
kubectl create configmap file-config --from-file=app.properties
kubectl get configmap file-config -o yaml  # filename becomes the key

# 1c. from YAML
kubectl apply -f configmap.yaml
kubectl get configmap web-config -o yaml

# ---- Part 2: ConfigMap as env vars ----
kubectl apply -f pod-env.yaml
kubectl logs env-demo | grep -E 'APP_COLOR|WELCOME|MAX'

# env vars are a snapshot — prove it:
kubectl create configmap app-config \
  --from-literal=APP_COLOR=red \
  --from-literal=APP_MODE=production \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl exec env-demo -- sh -c 'echo $APP_COLOR'   # still blue
kubectl delete pod env-demo
kubectl apply -f pod-env.yaml
kubectl exec env-demo -- sh -c 'echo $APP_COLOR'   # now red

# ---- Part 3: ConfigMap as volume ----
kubectl apply -f pod-volume.yaml
kubectl logs volume-demo
kubectl exec volume-demo -- ls -l /etc/config      # each key = one file

# live update (wait ~60s for kubelet sync)
kubectl patch configmap web-config \
  -p '{"data":{"WELCOME_MESSAGE":"Updated live!"}}'
kubectl exec volume-demo -- cat /etc/config/WELCOME_MESSAGE

# ---- Part 4: Secrets ----
# 4a. from literals
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD='S3cr3t!Pass'
kubectl get secret db-credentials
kubectl describe secret db-credentials             # values hidden
kubectl get secret db-credentials -o yaml          # base64-encoded

# 4b. use in a pod
kubectl apply -f pod-secret.yaml
kubectl logs secret-demo
kubectl exec secret-demo -- cat /etc/secrets/DB_PASSWORD

# 4c. data vs stringData
echo -n 'admin' | base64          # YWRtaW4=   (NOTE: -n is mandatory!)
echo -n 'S3cr3t!Pass' | base64    # UzNjcjN0IVBhc3M=
kubectl apply -f secret-data.yaml -f secret-stringdata.yaml
kubectl get secret db-cred-data -o yaml
kubectl get secret db-cred-string -o yaml          # stringData -> base64 data

# ---- Part 5: Security ----
# base64 is NOT encryption:
kubectl get secret db-credentials \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo

# RBAC check:
kubectl auth can-i get secrets \
  --as=system:serviceaccount:cm-lab:default

# ---- Cleanup ----
kubectl delete namespace cm-lab
kubectl config set-context --current --namespace=default
