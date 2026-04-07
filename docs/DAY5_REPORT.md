# Day 5 Report: GKE Deployment (C1)

## Summary

Successfully deployed the V2AI pipeline to Google Kubernetes Engine (GKE) using Autopilot mode. After debugging OOM and storage issues, the full end-to-end pipeline is working with video upload, transcription, summarization, and question generation.

## GKE Cluster Details

| Property | Value |
|----------|-------|
| Cluster Name | `v2ai-cluster` |
| Type | GKE Autopilot |
| Region | `us-central1` |
| Project | `v2aicloud` |
| External IP | `35.222.254.140` |

## Deployment Steps

### Step 1: Enable APIs
```bash
gcloud services enable container.googleapis.com containerregistry.googleapis.com --project=v2aicloud
```

### Step 2: Push Images to GCR
```bash
gcloud auth configure-docker --quiet
docker tag v2ai-cloudnative-backend:latest gcr.io/v2aicloud/v2ai-backend:latest
docker tag v2ai-cloudnative-ml_pipeline:latest gcr.io/v2aicloud/v2ai-ml-pipeline:latest
docker push gcr.io/v2aicloud/v2ai-backend:latest
docker push gcr.io/v2aicloud/v2ai-ml-pipeline:latest
```

### Step 3: Create GKE Cluster
```bash
# Standard cluster failed due to zonal stockouts - used Autopilot instead
gcloud container clusters create-auto v2ai-cluster --project=v2aicloud --region=us-central1
```

### Step 4: Deploy to Kubernetes
```bash
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials v2ai-cluster --region=us-central1 --project=v2aicloud

kubectl apply -f k8s/namespace.yaml
kubectl create secret generic gcp-credentials --from-file=gcp-key.json=./gcp-key.json -n v2ai
kubectl apply -f k8s/
```

## Issues Encountered and Fixes

### Issue 1: Zonal Stockouts
**Problem**: Standard GKE cluster failed in us-central1-a, us-central1-b due to e2-standard-2 stockouts.
**Solution**: Used GKE Autopilot which handles resource allocation automatically.

### Issue 2: Missing ConfigMap Values  
**Problem**: Backend pods crashed - missing `GCP_PROJECT_ID` and `GCS_KEY_PATH`.
**Solution**: Updated `k8s/configmap.yaml` with all required environment variables.

### Issue 3: Ephemeral Storage Exceeded
**Problem**: ML pods evicted - model downloads exceeded 1Gi storage limit.
```
Warning  Evicted  Pod ephemeral local storage usage exceeds the total limit of containers 1Gi.
```
**Solution**: Increased ephemeral-storage to 4Gi request / 8Gi limit.

### Issue 4: Models Loading Mid-Request (Connection Drops)
**Problem**: Transcription worked but Summary/QA failed with "Server disconnected" errors. Models were lazy-loaded during requests, causing pods to crash.
```json
{"summary": {"message": "Server disconnected without sending a response.", "status": "error"}}
```
**Solution**: Added model preloading at startup in `ml_pipeline/main.py`:
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("=== Preloading ML models at startup ===")
    await run_in_threadpool(get_whisper_model)  # ~3s
    await run_in_threadpool(get_summarizer)     # ~14s
    await run_in_threadpool(get_qa_model)       # ~4s
    logger.info("=== All models preloaded successfully ===")
    yield
```

### Issue 5: Readiness Probe Failures
**Problem**: Pods marked unhealthy before models finished loading (~20 seconds).
**Solution**: Increased probe delays:
- `livenessProbe.initialDelaySeconds`: 60 → 120
- `readinessProbe.initialDelaySeconds`: 30 → 60

## Why Old Pods Showed Completed/Error/ContainerStatusUnknown

Those pods were **remnants from failed deployments** during debugging:
- `69d669c8b6-*` = Old ReplicaSet (before OOM fix)
- `7849675c55-*` = New working ReplicaSet (after fix)

They were NOT from HPA scaling. To clean them up:
```bash
kubectl delete pods -n v2ai --field-selector=status.phase!=Running
```

## Final Configuration

### Resource Limits (ML Pipeline)
```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "1000m"
    ephemeral-storage: "4Gi"
  limits:
    memory: "8Gi"
    cpu: "2000m"
    ephemeral-storage: "8Gi"
```

### Final Pod Status
```
NAME                                READY   STATUS    AGE
v2ai-backend-7f4467dccf-2p6dz       1/1     Running   40m
v2ai-backend-7f4467dccf-crn4v       1/1     Running   40m
v2ai-ml-pipeline-7849675c55-7b2fj   1/1     Running   42m
v2ai-ml-pipeline-7849675c55-dzrhj   1/1     Running   43m
```

## End-to-End Test Results

### Final Test
```bash
curl -X POST http://35.222.254.140/upload -F 'file=@lecture.mp4'
curl http://35.222.254.140/status/{file_id}
```

### Results
| Stage | Status |
|-------|--------|
| Transcription | ✅ Success |
| Summarization | ✅ Success |
| Question Generation | ✅ Success |

### Sample Output
```json
{
  "status": "processed",
  "ml_results": {
    "transcript": {"status": "success"},
    "summary": {"status": "success", "text": "Students in our previous lecture..."},
    "questions": {"status": "success", "questions": ["fats and proteins", "food items which are rich in fat"]}
  }
}
```

### Processing Time: ~130 seconds total

## Files Modified

| File | Changes |
|------|---------|
| `k8s/configmap.yaml` | Added GCP_PROJECT_ID, GCS_KEY_PATH |
| `k8s/ml-pipeline-deployment.yaml` | Increased storage (8Gi), memory (8Gi), probe delays |
| `ml_pipeline/main.py` | Added lifespan startup to preload all models |

## Commands Reference

```bash
# Check pods
kubectl get pods -n v2ai

# Check HPA
kubectl get hpa -n v2ai

# View logs
kubectl logs -f deployment/v2ai-ml-pipeline -n v2ai

# Restart deployment
kubectl rollout restart deployment/v2ai-ml-pipeline -n v2ai

# Clean up failed pods
kubectl delete pods -n v2ai --field-selector=status.phase!=Running
```

## Cost Estimate (Autopilot)
- Backend: 2 pods × (250m CPU + 512Mi) ≈ $0.05/hr
- ML Pipeline: 2 pods × (1000m CPU + 4Gi) ≈ $0.40/hr
- **Total**: ~$10-12/day when running
