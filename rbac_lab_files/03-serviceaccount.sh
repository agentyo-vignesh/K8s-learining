kubectl create serviceaccount app-sa -n rbac-lab
kubectl apply -f rolebinding-sa.yaml
kubectl auth can-i list pods -n rbac-lab --as=system:serviceaccount:rbac-lab:app-sa
kubectl auth can-i delete pods -n rbac-lab --as=system:serviceaccount:rbac-lab:app-sa
