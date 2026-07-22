========================================
HELM - PHASE 1
========================================

--- Cluster check ---

kops get cluster

--- Helm install ---

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh
chmod +x get_helm.sh
./get_helm.sh
helm version

--- Connection verify ---

helm list -A

--- Repo add ---

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

--- Search ---

helm search repo nginx

--- Chart values paaru ---

helm show values bitnami/nginx | head -40

--- Install ---

helm install web bitnami/nginx -n demo --create-namespace --wait --timeout 5m

--- Verify ---

kubectl get all -n demo

--- Upgrade (replica 1 to 3) ---

helm upgrade web bitnami/nginx -n demo --set replicaCount=3 --reuse-values --wait

kubectl get pods -n demo

--- History ---

helm history web -n demo

--- Browser URL ---

echo "http://$(kubectl get svc web-nginx -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

--- Rollback ---

helm rollback web 1 -n demo --wait

--- Cleanup ---

helm uninstall web -n demo
kubectl delete ns demo
helm list -A
