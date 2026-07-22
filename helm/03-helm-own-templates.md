========================================
HELM - OWN / CUSTOM TEMPLATES DEMO
========================================

# Goal: default templates use pannaama, enoda sontha
# templates vachi oru chart build panradhu.

========================================
OPTION A - Scratch la fresh chart
========================================

--- Chart folder manual ah create pannu ---

mkdir -p myapp/templates

--- Chart.yaml (metadata) ---

cat > myapp/Chart.yaml <<'EOF'
apiVersion: v2
name: myapp
description: My own custom Helm chart
type: application
version: 0.1.0
appVersion: "1.0"
EOF

--- values.yaml (defaults - inga values define pannu) ---

cat > myapp/values.yaml <<'EOF'
replicaCount: 2

image:
  repository: nginx
  tag: "1.27"
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80
EOF

--- templates/deployment.yaml (enoda own template) ---
# {{ .Values.xxx }}  -> values.yaml la irundhu edukum
# {{ .Release.Name }} -> install panna release name

cat > myapp/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-myapp
  labels:
    app: {{ .Release.Name }}-myapp
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}-myapp
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-myapp
    spec:
      containers:
        - name: myapp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
EOF

--- templates/service.yaml (enoda own template) ---

cat > myapp/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-myapp
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}-myapp
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
EOF

--- Lint (syntax check) ---

helm lint myapp

--- Render locally paaru (cluster venaam) ---

helm template web myapp

--- Dry run against cluster ---

helm install web myapp -n demo --create-namespace --dry-run --debug

--- Install ---

helm install web myapp -n demo --create-namespace --wait --timeout 5m

--- Verify ---

kubectl get all -n demo

--- Value override ---

helm upgrade web myapp -n demo --set replicaCount=3 --wait
kubectl get pods -n demo


========================================
OPTION B - helm create + default delete
========================================

--- Scaffold create pannu ---

helm create myapp2

--- Default templates ellam remove pannu ---

rm -rf myapp2/templates/*

--- Ippo un own YAML files templates/ la pottukko ---
# (Option A la irukura maadhiri deployment.yaml, service.yaml add pannu)

--- Verify + install same maadhiri ---

helm lint myapp2
helm template web2 myapp2
helm install web2 myapp2 -n demo --create-namespace --wait


========================================
USEFUL TEMPLATE SYNTAX (quick paaru)
========================================

# {{ .Values.key }}          -> values.yaml value
# {{ .Release.Name }}         -> release name (helm install <name>)
# {{ .Release.Namespace }}    -> namespace
# {{ .Chart.Name }}           -> Chart.yaml name
# {{ .Chart.Version }}        -> chart version

# Conditionals:
# {{- if .Values.service.enabled }} ... {{- end }}

# Loop:
# {{- range .Values.env }} ... {{- end }}

# Default value:
# {{ .Values.image.tag | default "latest" }}


--- Cleanup ---

helm uninstall web -n demo
helm uninstall web2 -n demo
kubectl delete ns demo
helm list -A
