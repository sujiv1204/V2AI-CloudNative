# V2AI Cloud-Native Platform

Scalable lecture video understanding as a service - an end-to-end ML inference pipeline for lecture videos using Whisper (transcription), BART (summarization), and T5 (question generation).

## Project Structure

```
.
├── backend/              # C1 - FastAPI orchestration service
│   ├── main.py           # Async upload, orchestration, status endpoints
│   ├── config.py         # GCP configuration
│   ├── gcp_service.py    # GCS & Firestore operations
│   ├── audio_service.py  # FFmpeg audio extraction
│   ├── Dockerfile
│   └── requirements.txt
├── ml_pipeline/          # C2/C3 - ML model inference services
│   ├── main.py           # FastAPI with /transcript, /summarize, /qa
│   ├── services/
│   │   ├── transcription.py  # faster-whisper (C2)
│   │   ├── summarization.py  # BART summarization (C2)
│   │   └── qa.py             # T5 question generation (C3)
│   ├── Dockerfile
│   └── requirements.txt
├── k8s/                  # Kubernetes manifests (Day 5)
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── ml-pipeline-deployment.yaml
│   ├── ml-pipeline-service.yaml
│   └── hpa.yaml
├── scripts/              # Utility scripts
│   ├── cleanup-gcp.sh
│   └── day5-gke-deployment.sh
├── monitoring/           # Prometheus config
│   └── prometheus.yml
├── docs/                 # Documentation
│   ├── DAY5_REPORT.md
│   └── ...
├── docker-compose.yml    # Local dev orchestration
├── test-integration.sh   # End-to-end pipeline test
└── .env.example          # Environment variables template
```

## Quick Start

### Using Docker Compose

```bash
cp .env.example .env
# Add your GCP service account key
cp /path/to/service-account-key.json gcp-key.json

docker compose up --build
```

Or use the Makefile:
```bash
make build
make up
make logs
```

### End-to-End Test

```bash
# Start services
docker compose up -d

# Run integration test (uploads lecture.mp4 and validates full pipeline)
./test-integration.sh
```

**Services:**

- Backend: http://localhost:8000 (orchestration)
- ML Pipeline: http://localhost:8001 (inference)
- Prometheus: http://localhost:9090 (metrics)

### API Endpoints

**Backend (C1):**

- `GET /health` - Health check
- `POST /upload` - Upload video, triggers async ML pipeline
- `GET /status/{file_id}` - Check processing status and results

**ML Pipeline (C2/C3):**

- `POST /transcript` - Transcribe audio (multipart file)
- `POST /summarize` - Summarize text (JSON body: `{"text": "..."}`)
- `POST /qa` - Generate questions (JSON body: `{"text": "..."}`)

## Team Responsibilities

| Day | C1 (Backend & Cloud) | C2 (ML Pipeline) | C3 (Integration & Testing) |
|-----|---------------------|------------------|---------------------------|
| 1 | FastAPI, GCS, Firestore | Whisper, BART setup | T5 QA setup |
| 2 | Dockerize backend | Dockerize ML services | Dockerize QA |
| 3 | Async orchestration | Standardize responses | docker-compose, testing |
| 4 | Multi-VM deployment | Validate in VM | Inter-VM testing |
| 5 | GKE cluster setup | K8s pod validation | Locust scripts |
| 6 | Resource limits | Inference optimization | HPA/VPA config |
| 7 | Autoscaling tuning | Final optimization | Load testing |
| 8 | Prometheus setup | Stability validation | Grafana dashboards |

## Day 1-3 Completed (Integration Branch)

### Pipeline Flow
```
1. POST /upload (video) → Backend saves to GCS, extracts audio
2. Background task calls ML Pipeline:
   - /transcript (audio file) → Whisper transcription
   - /summarize (text) → BART summary
   - /qa (text) → T5 questions
3. Results stored in Firestore, accessible via GET /status/{file_id}
```

### Performance (lecture.mp4 ~50MB)
- Transcription: ~30-40s (faster-whisper base model)
- Summarization: ~30-40s (BART with chunking)
- QA Generation: ~5-10s (T5-small)
- Total pipeline: ~60-90s

## Day 4: Single VM Deployment

Deployed full pipeline to GCE VM for baseline testing.

| Resource | Value |
|----------|-------|
| VM | v2ai-vm-1 (e2-medium) |
| Zone | us-central1-a |
| External IP | 35.193.246.44 |

```bash
# Test VM deployment
curl http://35.193.246.44:8000/health
curl -X POST http://35.193.246.44:8000/upload -F 'file=@lecture.mp4'
```

## Day 5: GKE Deployment

Deployed to GKE Autopilot for auto-scaling and load balancing.

| Resource | Value |
|----------|-------|
| Cluster | v2ai-cluster (Autopilot) |
| Region | us-central1 |
| External IP | 35.222.254.140 |

### GKE Quick Start
```bash
# Get cluster credentials
gcloud container clusters get-credentials v2ai-cluster --region=us-central1 --project=v2aicloud

# Deploy
kubectl apply -f k8s/

# Check pods
kubectl get pods -n v2ai

# Test
curl http://35.222.254.140/health
curl -X POST http://35.222.254.140/upload -F 'file=@lecture.mp4'
curl http://35.222.254.140/status/{file_id}
```

### GKE Components
- **Backend**: 2 replicas, LoadBalancer on port 80
- **ML Pipeline**: 2-4 replicas (HPA), ClusterIP internal
- **HPA**: Auto-scales at 70% CPU

See `scripts/day5-gke-deployment.sh` for full deployment steps and `docs/DAY5_REPORT.md` for details.

## Development Notes

- Models cache in `/models` volume - persists across container restarts
- ffmpeg required in all containers for audio extraction
- Services communicate via Docker network (`v2ai-network`)
- ML pipeline uses JSON body for text endpoints (not query params)

## Cleanup

To reset test data (local + GCS + Firestore):

```bash
# Clean everything
./scripts/cleanup-gcp.sh --all

# Clean only local uploads
./scripts/cleanup-gcp.sh --local

# Clean only GCS bucket
./scripts/cleanup-gcp.sh --gcs

# Clean only Firestore
./scripts/cleanup-gcp.sh --firestore
```

## GCP Configuration

### Required Environment Variables
```bash
GCP_PROJECT_ID=241955658779
GCS_BUCKET_NAME=v2aibucket
GCS_KEY_PATH=./gcp-key.json
FIRESTORE_DB_NAME=v2aidb
FIRESTORE_COLLECTION=videos
```

### Setup
```bash
cp .env.example .env
cp /path/to/service-account-key.json gcp-key.json
```

Service account must be from project `241955658779`.

## Testing

```bash
# Health checks
curl http://localhost:8000/health
curl http://localhost:8001/health

# Upload video
curl -X POST -F 'file=@lecture.mp4' http://localhost:8000/upload

# Check status
curl http://localhost:8000/status/{file_id}

# Full integration test
./test-integration.sh
```
