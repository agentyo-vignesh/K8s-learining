kubectl auth can-i list pods --namespace rbac-lab --as intern
kubectl auth can-i delete pods --namespace rbac-lab --as intern
kubectl auth can-i get secrets --namespace rbac-lab --as intern
kubectl edit role pod-reader -n rbac-lab
kubectl auth can-i delete pods --namespace rbac-lab --as intern
