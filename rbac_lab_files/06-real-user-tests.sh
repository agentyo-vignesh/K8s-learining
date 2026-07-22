# ============================================================
# REAL USER TESTS  -  actual login as 'intern' (real Forbidden!)
# --as-a maari, idhu real authentication vechu run aagum.
# ============================================================

# 1. Binding illama try -> Forbidden varum
kubectl --context intern-ctx get pods -n rbac-lab

# 2. Ippo admin-a bindings apply pannu
kubectl apply -f role-pod-reader.yaml
kubectl apply -f rolebinding-intern.yaml

# 3. Thirumba intern-a try -> ippo WORK aagum
kubectl --context intern-ctx get pods -n rbac-lab

# 4. Delete try -> Forbidden (Role-la delete verb illa)
kubectl --context intern-ctx delete pod --all -n rbac-lab

# 5. Vera namespace / secrets -> Forbidden
kubectl --context intern-ctx get pods -n kube-system
kubectl --context intern-ctx get secrets -n rbac-lab

# 6. Cluster-wide node access (ClusterRoleBinding demo)
kubectl --context intern-ctx get nodes                 # Forbidden
kubectl apply -f clusterrole-node-reader.yaml
kubectl apply -f clusterrolebinding-intern.yaml
kubectl --context intern-ctx get nodes                 # ippo work aagum

# thirumba admin context-ku vara:
# kubectl config use-context minikube
