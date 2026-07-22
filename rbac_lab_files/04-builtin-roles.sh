kubectl get clusterrole | grep -E '^(view|edit|admin|cluster-admin)'
kubectl describe clusterrole view | head -n 30
