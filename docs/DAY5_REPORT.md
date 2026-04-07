# Day 5 Report: GKE Deployment (C1)

## Summary

Successfully deployed the V2AI pipeline to Google Kubernetes Engine (GKE) using Autopilot mode. The full end-to-end pipeline is working with video upload, transcription, summarization, and question generation.

## GKE Cluster Details

| Property     | Value            |
| ------------ | ---------------- |
| Cluster Name | `v2ai-cluster`   |
| Type         | GKE Autopilot    |
| Region       | `us-central1`    |
| Project      | `v2aicloud`      |
| External IP  | `35.222.254.140` |

## Deployment Configuration

### Images (pushed to GCR)

- `gcr.io/v2aicloud/v2ai-backend:latest`
- `gcr.io/v2aicloud/v2ai-ml-pipeline:latest`

### Pods Running

| Component   | Replicas | CPU Request | Memory Request |
| ----------- | -------- | ----------- | -------------- |
| Backend     | 2        | 250m        | 512Mi          |
| ML Pipeline | 2-4      | 1000m       | 2Gi            |

### Services

| Service             | Type         | Port    | External Access       |
| ------------------- | ------------ | ------- | --------------------- |
| v2ai-backend        | LoadBalancer | 80→8000 | http://35.222.254.140 |
| ml-pipeline-service | ClusterIP    | 8001    | Internal only         |

### Horizontal Pod Autoscaler (HPA)

| Component   | Min | Max | Target CPU |
| ----------- | --- | --- | ---------- |
| Backend     | 2   | 5   | 70%        |
| ML Pipeline | 2   | 4   | 70%        |

## API Endpoints (GKE)

### Health Check

```bash
curl http://35.222.254.140/health
# {"status":"ok"}
```

### Upload Video

```bash
curl -X POST http://35.222.254.140/upload \
  -F "file=@lecture.mp4"
```

### Check Status

```bash
curl http://35.222.254.140/status/{file_id}
```

## End-to-End Test Results

### Test Run

- **Video**: lecture.mp4 (49MB)
- **Upload Time**: Immediate
- **Total Processing**: ~150 seconds
- **Status**: ✅ SUCCESS

### Pipeline Timing

| Stage                    | Duration |
| ------------------------ | -------- |
| Upload + Audio Extract   | ~5s      |
| Transcription (Whisper)  | ~73s     |
| Summarization (BART)     | ~65s     |
| Question Generation (T5) | ~10s     |

### Sample Output

```json
{
    "file_id": "1f132bad-d953-6fdc-84a8-8d101c3e6c8f",
    "status": "processed",
    "ml_results": {
        "transcript": { "status": "success", "text": "5044 chars" },
        "summary": { "status": "success", "text": "1136 chars" },
        "questions": { "status": "success", "count": 3 }
    }
}
```

## Challenges & Solutions

### 1. Resource Stockout

**Problem**: Multiple zones (us-central1-a, us-central1-b, us-east1-b) had e2-standard-2 stockouts.
**Solution**: Switched to GKE Autopilot which handles resource allocation automatically.

### 2. Missing ConfigMap Values

**Problem**: Backend pods crashed due to missing `GCP_PROJECT_ID` and `GCS_KEY_PATH`.
**Solution**: Updated configmap.yaml with all required environment variables.

### 3. kubectl Auth Plugin

**Problem**: `gke-gcloud-auth-plugin` not installed locally.
**Solution**: Installed via `sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin`

## Files Modified/Created

### New Files

- `k8s/configmap.yaml` - Environment variables
- `k8s/secret.yaml` - GCP credentials template
- `k8s/ml-pipeline-deployment.yaml` - ML service deployment
- `k8s/ml-pipeline-service.yaml` - ML service (ClusterIP)

### Updated Files

- `k8s/backend-deployment.yaml` - Added GCR image, secrets, probes
- `k8s/hpa.yaml` - Added ML pipeline autoscaler

## Commands Reference

### Cluster Setup

```bash
# Create Autopilot cluster
gcloud container clusters create-auto v2ai-cluster \
  --project=v2aicloud \
  --region=us-central1

# Get credentials
gcloud container clusters get-credentials v2ai-cluster \
  --region=us-central1 --project=v2aicloud
```

### Deploy Application

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secret from GCP key
kubectl create secret generic gcp-credentials \
  --from-file=gcp-key.json=./gcp-key.json -n v2ai

# Deploy all
kubectl apply -f k8s/
```

### Monitor

```bash
# Check pods
kubectl get pods -n v2ai

# Check HPA
kubectl get hpa -n v2ai

# View logs
kubectl logs -f deployment/v2ai-backend -n v2ai
kubectl logs -f deployment/v2ai-ml-pipeline -n v2ai
```

## Cost Considerations

GKE Autopilot charges per-pod resource usage:

- Backend: 2 pods × (250m CPU + 512Mi) ≈ $0.05/hr
- ML Pipeline: 2 pods × (1000m CPU + 2Gi) ≈ $0.20/hr
- **Estimated**: ~$6/day when running

## Next Steps (Day 6)

1. **Load Testing**: Run Locust tests against GKE endpoint
2. **Compare**: Benchmark GKE vs Multi-VM Docker Compose
3. **Prometheus/Grafana**: Set up monitoring stack
4. **Document**: Performance comparison report

## Comparison: VM vs GKE

| Aspect         | Single VM     | GKE Autopilot   |
| -------------- | ------------- | --------------- |
| External IP    | 35.193.246.44 | 35.222.254.140  |
| Scaling        | Manual        | Automatic (HPA) |
| Replicas       | 1 each        | 2+ each         |
| Load Balancing | None          | Built-in        |
| Cost           | ~$1/day       | ~$6/day         |
| Setup Time     | 30 min        | 45 min          |
