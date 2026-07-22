========================================
HELM CREATE - CUSTOM CHART DEMO
========================================

--- Helm check ---

helm version

--- Create a new chart ---

helm create mychart

--- Folder structure paaru ---

tree mychart
# no tree? use:
ls -R mychart

# Structure:
# mychart/
# ├── Chart.yaml          -> chart metadata (name, version)
# ├── values.yaml         -> default config values
# ├── charts/             -> dependency (sub) charts
# ├── templates/          -> k8s manifest templates
# │   ├── deployment.yaml
# │   ├── service.yaml
# │   ├── ingress.yaml
# │   ├── hpa.yaml
# │   ├── serviceaccount.yaml
# │   ├── _helpers.tpl     -> template helpers
# │   ├── NOTES.txt        -> post-install notes
# │   └── tests/
# └── .helmignore

--- Chart.yaml paaru ---

cat mychart/Chart.yaml

--- values.yaml paaru (default nginx image) ---

cat mychart/values.yaml | head -40

--- Edit values (image + replicas + service type) ---

# Open mychart/values.yaml and set:
#   replicaCount: 2
#   image:
#     repository: nginx
#     tag: "1.27"
#   service:
#     type: LoadBalancer
#     port: 80

--- Lint the chart (syntax check) ---

helm lint mychart

--- Render templates locally (dry run, no cluster) ---

helm template web mychart

--- Dry run against cluster ---

helm install web mychart -n demo --create-namespace --dry-run --debug

--- Install for real ---

helm install web mychart -n demo --create-namespace --wait --timeout 5m

--- Verify ---

kubectl get all -n demo

--- Override a value at install/upgrade time ---

helm upgrade web mychart -n demo --set replicaCount=3 --wait

kubectl get pods -n demo

--- Use a custom values file ---

# create prod-values.yaml:
cat > prod-values.yaml <<'EOF'
replicaCount: 4
image:
  repository: nginx
  tag: "1.27"
service:
  type: LoadBalancer
  port: 80
EOF

helm upgrade web mychart -n demo -f prod-values.yaml --wait

--- History ---

helm history web -n demo

--- Browser URL ---

echo "http://$(kubectl get svc web-mychart -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

--- Package the chart (share as .tgz) ---

helm package mychart

--- Rollback ---

helm rollback web 1 -n demo --wait

--- Cleanup ---

helm uninstall web -n demo
kubectl delete ns demo
helm list -A
