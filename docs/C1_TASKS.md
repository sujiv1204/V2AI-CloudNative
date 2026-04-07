# C1 (sujiv) Tasks: GKE Kubernetes Deployment

## Overview

Your tasks for Day 5-6:

1. **Create GKE Cluster** in GCP
2. **Push Docker images** to Google Container Registry (GCR)
3. **Deploy services** to Kubernetes with proper manifests
4. **Configure HPA** (Horizontal Pod Autoscaler)
5. **Setup Prometheus/Grafana** for metrics
6. **Run load tests** and compare with multi-VM results

---

## Current Live Endpoints (Day 4 VM)

**Backend:** `http://35.193.246.44:8000`  
**ML Pipeline:** `http://35.193.246.44:8001`  
**VM Name:** v2ai-vm-1

These remain running for C2/C3 to test against while you work on GKE.

---

## Part 1: Create GKE Cluster

### Step 1.1: Enable GKE API

```bash
gcloud services enable container.googleapis.com --project=v2aicloud
```

### Step 1.2: Create Cluster

```bash
gcloud container clusters create v2ai-cluster \
  --project=v2aicloud \
  --zone=us-central1-a \
  --num-nodes=3 \
  --machine-type=e2-standard-2 \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=5 \
  --disk-size=30GB
```

**Expected output:**

```
Creating cluster v2ai-cluster...done.
NAME          LOCATION       MASTER_VERSION  NUM_NODES  STATUS
v2ai-cluster  us-central1-a  1.27.x          3          RUNNING
```

### Step 1.3: Get Credentials

```bash
gcloud container clusters get-credentials v2ai-cluster \
  --project=v2aicloud \
  --zone=us-central1-a
```

### Step 1.4: Verify kubectl

```bash
kubectl get nodes
```

Expected: 3 nodes in Ready status.

---

## Part 2: Push Images to GCR

### Step 2.1: Enable GCR API

```bash
gcloud services enable containerregistry.googleapis.com --project=v2aicloud
```

### Step 2.2: Configure Docker for GCR

```bash
gcloud auth configure-docker
```

### Step 2.3: Tag and Push Backend Image

```bash
cd /home/sujiv/Documents/projects/V2AI-CloudNative

# Build image
docker build -t v2ai-backend:latest ./backend

# Tag for GCR
docker tag v2ai-backend:latest gcr.io/v2aicloud/v2ai-backend:latest

# Push to GCR
docker push gcr.io/v2aicloud/v2ai-backend:latest
```

### Step 2.4: Tag and Push ML Pipeline Image

```bash
# Build image
docker build -t v2ai-ml-pipeline:latest ./ml_pipeline

# Tag for GCR
docker tag v2ai-ml-pipeline:latest gcr.io/v2aicloud/v2ai-ml-pipeline:latest

# Push to GCR
docker push gcr.io/v2aicloud/v2ai-ml-pipeline:latest
```

### Step 2.5: Verify Images in GCR

```bash
gcloud container images list --project=v2aicloud
```

---

## Part 3: Create Kubernetes Manifests

### Step 3.1: Create k8s Directory

```bash
mkdir -p k8s
```

### Step 3.2: Create Namespace

Create `k8s/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
    name: v2ai
```

### Step 3.3: Create ConfigMap

Create `k8s/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: v2ai-config
    namespace: v2ai
data:
    GCP_PROJECT_ID: "v2aicloud"
    GCS_BUCKET_NAME: "v2aibucket"
    FIRESTORE_DB_NAME: "v2aidb"
    FIRESTORE_COLLECTION: "videos"
    ML_PIPELINE_URL: "http://ml-pipeline-service:8001"
    LOG_LEVEL: "INFO"
```

### Step 3.4: Create Secret for GCP Key

```bash
# Create secret from gcp-key.json file
kubectl create namespace v2ai
kubectl create secret generic gcp-credentials \
  --from-file=gcp-key.json=./gcp-key.json \
  --namespace=v2ai
```

### Step 3.5: Create Backend Deployment

Create `k8s/backend-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: backend
    namespace: v2ai
    labels:
        app: backend
spec:
    replicas: 2
    selector:
        matchLabels:
            app: backend
    template:
        metadata:
            labels:
                app: backend
        spec:
            containers:
                - name: backend
                  image: gcr.io/v2aicloud/v2ai-backend:latest
                  ports:
                      - containerPort: 8000
                  envFrom:
                      - configMapRef:
                            name: v2ai-config
                  env:
                      - name: GCS_KEY_PATH
                        value: "/secrets/gcp-key.json"
                  volumeMounts:
                      - name: gcp-credentials
                        mountPath: "/secrets"
                        readOnly: true
                      - name: uploads
                        mountPath: "/app/uploads"
                  resources:
                      requests:
                          memory: "512Mi"
                          cpu: "250m"
                      limits:
                          memory: "1Gi"
                          cpu: "500m"
                  livenessProbe:
                      httpGet:
                          path: /health
                          port: 8000
                      initialDelaySeconds: 10
                      periodSeconds: 10
                  readinessProbe:
                      httpGet:
                          path: /health
                          port: 8000
                      initialDelaySeconds: 5
                      periodSeconds: 5
            volumes:
                - name: gcp-credentials
                  secret:
                      secretName: gcp-credentials
                - name: uploads
                  emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
    name: backend-service
    namespace: v2ai
spec:
    type: LoadBalancer
    selector:
        app: backend
    ports:
        - port: 8000
          targetPort: 8000
```

### Step 3.6: Create ML Pipeline Deployment

Create `k8s/ml-pipeline-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: ml-pipeline
    namespace: v2ai
    labels:
        app: ml-pipeline
spec:
    replicas: 2
    selector:
        matchLabels:
            app: ml-pipeline
    template:
        metadata:
            labels:
                app: ml-pipeline
        spec:
            containers:
                - name: ml-pipeline
                  image: gcr.io/v2aicloud/v2ai-ml-pipeline:latest
                  ports:
                      - containerPort: 8001
                  env:
                      - name: TRANSFORMERS_CACHE
                        value: "/models"
                      - name: HF_HOME
                        value: "/models"
                      - name: CUDA_VISIBLE_DEVICES
                        value: ""
                  volumeMounts:
                      - name: models-cache
                        mountPath: "/models"
                  resources:
                      requests:
                          memory: "4Gi"
                          cpu: "1000m"
                      limits:
                          memory: "6Gi"
                          cpu: "2000m"
                  livenessProbe:
                      httpGet:
                          path: /health
                          port: 8001
                      initialDelaySeconds: 60
                      periodSeconds: 30
                  readinessProbe:
                      httpGet:
                          path: /health
                          port: 8001
                      initialDelaySeconds: 30
                      periodSeconds: 10
            volumes:
                - name: models-cache
                  emptyDir:
                      sizeLimit: 5Gi
---
apiVersion: v1
kind: Service
metadata:
    name: ml-pipeline-service
    namespace: v2ai
spec:
    type: ClusterIP
    selector:
        app: ml-pipeline
    ports:
        - port: 8001
          targetPort: 8001
```

### Step 3.7: Create HPA (Horizontal Pod Autoscaler)

Create `k8s/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
    name: backend-hpa
    namespace: v2ai
spec:
    scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: backend
    minReplicas: 2
    maxReplicas: 5
    metrics:
        - type: Resource
          resource:
              name: cpu
              target:
                  type: Utilization
                  averageUtilization: 70
        - type: Resource
          resource:
              name: memory
              target:
                  type: Utilization
                  averageUtilization: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
    name: ml-pipeline-hpa
    namespace: v2ai
spec:
    scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: ml-pipeline
    minReplicas: 2
    maxReplicas: 4
    metrics:
        - type: Resource
          resource:
              name: cpu
              target:
                  type: Utilization
                  averageUtilization: 70
```

---

## Part 4: Deploy to Kubernetes

### Step 4.1: Apply Manifests

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/ml-pipeline-deployment.yaml
kubectl apply -f k8s/hpa.yaml
```

### Step 4.2: Verify Deployments

```bash
# Check pods
kubectl get pods -n v2ai

# Check services
kubectl get services -n v2ai

# Check HPA
kubectl get hpa -n v2ai
```

### Step 4.3: Get External IP

```bash
kubectl get service backend-service -n v2ai
```

Wait for EXTERNAL-IP to be assigned (may take 1-2 minutes).

### Step 4.4: Test Endpoints

```bash
GKE_IP=$(kubectl get service backend-service -n v2ai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "GKE Backend IP: $GKE_IP"

# Test health
curl http://$GKE_IP:8000/health
```

---

## Part 5: Setup Prometheus & Grafana

### Step 5.1: Install Prometheus using Helm

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Step 5.2: Access Grafana

```bash
# Port forward Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

Open http://localhost:3000 (default: admin/prom-operator)

### Step 5.3: Create V2AI Dashboard

Import or create dashboard with:

- Pod CPU/Memory usage
- Request latency
- Request rate
- HPA status

---

## Part 6: Load Testing

### Step 6.1: Run Locust Against GKE

```bash
GKE_IP=$(kubectl get service backend-service -n v2ai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Run load test
locust -f tests/locustfile.py \
  --host=http://$GKE_IP:8000 \
  --users=20 \
  --spawn-rate=5 \
  --run-time=120s \
  --headless \
  --csv=results/gke
```

### Step 6.2: Monitor HPA Scaling

```bash
# Watch HPA in real-time
kubectl get hpa -n v2ai -w

# In another terminal, watch pods
kubectl get pods -n v2ai -w
```

### Step 6.3: Collect Metrics

```bash
# Get pod resource usage
kubectl top pods -n v2ai

# Get node resource usage
kubectl top nodes
```

---

## Part 7: Document Results

Create `docs/GKE_BENCHMARK.md`:

```markdown
# GKE Deployment Benchmark Results

## Cluster Configuration

| Component        | Type          | Nodes     | Resources                    |
| ---------------- | ------------- | --------- | ---------------------------- |
| GKE Cluster      | e2-standard-2 | 3         | 2 vCPU, 8GB per node         |
| Backend Pods     | -             | 2-5 (HPA) | 250m-500m CPU, 512Mi-1Gi RAM |
| ML Pipeline Pods | -             | 2-4 (HPA) | 1-2 CPU, 4-6Gi RAM           |

## Test Parameters

- Duration: 120 seconds
- Users: 20 concurrent
- Spawn rate: 5 users/second

## Results

| Metric             | Value  |
| ------------------ | ------ |
| Total Requests     | XXX    |
| Requests/sec       | XXX    |
| Median Latency     | XXX ms |
| 95th Percentile    | XXX ms |
| 99th Percentile    | XXX ms |
| Failure Rate       | X%     |
| HPA Scaling Events | X      |

## Comparison with Multi-VM

| Metric       | Multi-VM | GKE   |
| ------------ | -------- | ----- |
| Requests/sec | X        | X     |
| p95 Latency  | X ms     | X ms  |
| Scaling Time | N/A      | X sec |
| Cost/hour    | $X       | $X    |
```

---

## Verification Checklist

- [ ] GKE cluster created with 3 nodes
- [ ] Images pushed to GCR
- [ ] Deployments running (backend + ml-pipeline)
- [ ] Services accessible via LoadBalancer
- [ ] HPA configured and responding
- [ ] Prometheus/Grafana installed
- [ ] Load tests completed
- [ ] Results documented

---

## Commands Quick Reference

```bash
# Cluster management
gcloud container clusters list --project=v2aicloud
gcloud container clusters get-credentials v2ai-cluster --zone=us-central1-a --project=v2aicloud

# Pod management
kubectl get pods -n v2ai
kubectl logs -f deployment/backend -n v2ai
kubectl logs -f deployment/ml-pipeline -n v2ai

# Scaling
kubectl scale deployment backend --replicas=3 -n v2ai
kubectl get hpa -n v2ai -w

# Debugging
kubectl describe pod <pod-name> -n v2ai
kubectl exec -it <pod-name> -n v2ai -- /bin/bash

# Cleanup (when done)
gcloud container clusters delete v2ai-cluster --zone=us-central1-a --project=v2aicloud --quiet
```

---

## Cleanup (After Benchmarking)

```bash
# Delete GKE cluster (saves costs)
gcloud container clusters delete v2ai-cluster \
  --zone=us-central1-a \
  --project=v2aicloud \
  --quiet

# Delete GCR images (optional)
gcloud container images delete gcr.io/v2aicloud/v2ai-backend:latest --quiet
gcloud container images delete gcr.io/v2aicloud/v2ai-ml-pipeline:latest --quiet
```

---

## Timeline

| Day      | Task                     | Hours |
| -------- | ------------------------ | ----- |
| Day 5 AM | Create GKE cluster       | 1-2   |
| Day 5 AM | Push images to GCR       | 1-2   |
| Day 5 PM | Create K8s manifests     | 2-3   |
| Day 5 PM | Deploy and verify        | 1-2   |
| Day 6 AM | Configure HPA            | 1-2   |
| Day 6 AM | Setup Prometheus/Grafana | 2-3   |
| Day 6 PM | Run load tests           | 2-3   |
| Day 6 PM | Document results         | 1-2   |
