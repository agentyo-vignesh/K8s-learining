kubectl delete namespace rbac-lab
kubectl delete clusterrole node-reader
kubectl delete clusterrolebinding intern-node-reader

# real user cleanup (Method 3)
kubectl delete csr intern --ignore-not-found
kubectl config delete-context intern-ctx 2>/dev/null || true
kubectl config delete-user intern 2>/dev/null || true
kubectl config use-context minikube
rm -f intern.key intern.csr intern.crt

rm -f role-pod-reader.yaml rolebinding-intern.yaml clusterrole-node-reader.yaml clusterrolebinding-intern.yaml rolebinding-sa.yaml
