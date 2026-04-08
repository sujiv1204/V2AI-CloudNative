# GKE Integration Guide for C2 and C3

This guide explains how to integrate your changes into the GKE cluster after completing your tasks.

## Current GKE Status

| Component   | Status         | Notes                                       |
| ----------- | -------------- | ------------------------------------------- |
| Cluster     | Running        | `v2ai-cluster` (Autopilot, us-central1)     |
| Backend     | ✅ Working     | 2 replicas, LoadBalancer                    |
| ML Pipeline | ⚠️ Partial     | Transcription works, Summary/QA may timeout |
| External IP | 35.222.254.140 | Access via port 80                          |

## Why Summary/QA Failed

The errors you saw:

```
"summary": { "message": "Server disconnected without sending a response.", "status": "error" }
"questions": { "message": "All connection attempts failed", "status": "error" }
```

**Root Cause**: Memory pressure on ML pipeline pods. BART and T5 models need ~1-2GB each to load. When a pod processes transcription and then tries to load BART/T5, it can OOM or timeout.

**Solutions** (for C2 to implement):

1. Pre-load all models at startup
2. Increase memory limits
3. Use smaller model variants

---

## Integration Workflow

### Step 1: Work on Your Branch

```bash
# C2
git checkout main
git pull origin main
git checkout -b feature/c2-firestore-ui

# C3
git checkout main
git pull origin main
git checkout -b feature/c3-multi-vm-locust
```

### Step 2: Make Your Changes

Follow your task docs:

- C2: `docs/C2_TASKS.md`
- C3: `docs/C3_TASKS.md`

### Step 3: Test Locally First

```bash
# Build and test locally
docker compose build
docker compose up -d
./test-integration.sh
```

### Step 4: Push to GitHub

```bash
git add .
git commit -m "Your descriptive message"
git push origin feature/your-branch
```

### Step 5: Create Pull Request

1. Go to GitHub repo
2. Create PR: `feature/your-branch` → `main`
3. Request review from C1 (sujiv)

---

## C1's GKE Update Process

After C2/C3 PRs are merged to main, C1 will:

### 1. Pull Latest Code

```bash
git checkout main
git pull origin main
```

### 2. Rebuild Docker Images

```bash
# Rebuild with new code
docker compose build

# Tag for GCR
docker tag v2ai-cloudnative-backend:latest gcr.io/v2aicloud/v2ai-backend:latest
docker tag v2ai-cloudnative-ml_pipeline:latest gcr.io/v2aicloud/v2ai-ml-pipeline:latest
```

### 3. Push to GCR

```bash
docker push gcr.io/v2aicloud/v2ai-backend:latest
docker push gcr.io/v2aicloud/v2ai-ml-pipeline:latest
```

### 4. Update K8s Manifests (if needed)

```bash
# If C2 added new env vars, update configmap
vi k8s/configmap.yaml

# If resources changed
vi k8s/ml-pipeline-deployment.yaml
```

### 5. Deploy to GKE

```bash
# Get credentials
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials v2ai-cluster \
  --region=us-central1 --project=v2aicloud

# Apply updated configs
kubectl apply -f k8s/configmap.yaml

# Trigger rolling update to pull new images
kubectl rollout restart deployment/v2ai-backend -n v2ai
kubectl rollout restart deployment/v2ai-ml-pipeline -n v2ai

# Watch rollout
kubectl rollout status deployment/v2ai-backend -n v2ai
kubectl rollout status deployment/v2ai-ml-pipeline -n v2ai
```

### 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n v2ai

# Test endpoints
curl http://35.222.254.140/health
curl -X POST http://35.222.254.140/upload -F 'file=@lecture.mp4'
```

---

## Quick Commands Reference

### Check GKE Status

```bash
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
kubectl get pods -n v2ai
kubectl get services -n v2ai
kubectl get hpa -n v2ai
```

### View Logs

```bash
# Backend logs
kubectl logs -f deployment/v2ai-backend -n v2ai

# ML Pipeline logs
kubectl logs -f deployment/v2ai-ml-pipeline -n v2ai
```

### Debug Issues

```bash
# Check events
kubectl get events -n v2ai --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top pods -n v2ai

# Describe problematic pod
kubectl describe pod <pod-name> -n v2ai
```

### Force Restart

```bash
# Delete pod (will auto-recreate)
kubectl delete pod <pod-name> -n v2ai

# Full restart
kubectl rollout restart deployment/v2ai-ml-pipeline -n v2ai
```

---

## Environment Variables in K8s

The `k8s/configmap.yaml` contains:

```yaml
GCP_PROJECT_ID: "v2aicloud"
GCS_BUCKET_NAME: "v2aibucket"
GCS_KEY_PATH: "/secrets/gcp-key.json"
FIRESTORE_DB_NAME: "v2aidb"
FIRESTORE_COLLECTION: "videos"
ML_PIPELINE_URL: "http://ml-pipeline-service:8001"
TRANSFORMERS_CACHE: "/models"
```

If C2 adds new Firestore fields, no config changes needed.
If C2 adds new env vars, update `configmap.yaml` and redeploy.

---

## Timeline

1. **C2 completes tasks** → Push to branch → Create PR
2. **C3 completes tasks** → Push to branch → Create PR
3. **C1 reviews and merges** PRs to main
4. **C1 rebuilds and deploys** to GKE
5. **All test together** on GKE endpoint

---

## Contact

If you run into issues deploying to GKE, share:

1. Output of `kubectl get pods -n v2ai`
2. Output of `kubectl logs <failing-pod> -n v2ai`
3. What change you made

C1 will help debug and deploy.
