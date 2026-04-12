# V2AI Cloud-Native

V2AI is a cloud-native lecture video understanding pipeline. It accepts a video, extracts audio, runs transcription/summarization/question generation, and stores processing metadata and results in Firestore.

## Architecture

- **Backend (`backend/`)**: FastAPI orchestration service
  - Video upload endpoint
  - Audio extraction via ffmpeg
  - GCS uploads (video + audio)
  - Async ML pipeline orchestration
  - Firestore status/result storage
- **ML Pipeline (`ml_pipeline/`)**: FastAPI inference service
  - `/transcript` (Whisper)
  - `/summarize` (BART)
  - `/qa` (T5)
- **Infra**
  - Local: Docker Compose
  - Cloud: GKE manifests in `k8s/`
  - Monitoring: Prometheus/Grafana setup documented in `docs/GKE_BENCHMARK.md`

## Repository Layout

```text
backend/         Backend API and orchestration logic
ml_pipeline/     ML inference API and model services
k8s/             Kubernetes manifests and monitoring patches
monitoring/      Prometheus config for local/docker setup
tests/           API and load-test files
scripts/         Deployment and cleanup scripts
docs/            Task docs, reports, integration notes
results/         Locust and benchmark outputs
```

## Prerequisites

- Python 3.11+ (3.12 used in this repo)
- Docker and Docker Compose
- ffmpeg
- GCP project with:
  - GCS bucket
  - Firestore database
  - Service account key file (`gcp-key.json`)

## Configuration

1. Copy env template:

```bash
cp .env.example .env
```

2. Place service account key at repository root:

```bash
cp /path/to/your-key.json ./gcp-key.json
```

3. Update `.env` values as needed.

## Run Locally (Docker Compose)

```bash
docker compose up --build
```

Or with Make:

```bash
make build
make up
```

Services:

- Backend: `http://localhost:8000`
- ML Pipeline: `http://localhost:8001`
- Prometheus: `http://localhost:9090`

## API Endpoints

### Backend

- `GET /` UI page
- `GET /health`
- `POST /upload` (multipart `file`)
- `GET /status/{file_id}`
- `POST /summarize` (proxy to ML service)
- `POST /qa` (proxy to ML service)
- `GET /debug/ml` (ML connectivity diagnostics)

### ML Pipeline

- `GET /health`
- `GET /ready`
- `POST /transcript` (multipart audio/video file)
- `POST /summarize` (`{"text":"..."}`)
- `POST /qa` (`{"text":"..."}`)

## End-to-End Test

Run the integration flow against local or remote backend:

```bash
# Default target is set in script; override with BACKEND_URL when needed
BACKEND_URL=http://localhost:8000 ./test-integration.sh
```

The script uploads `lecture.mp4`, polls status, and validates transcript/summary/QA stages.

## Kubernetes (GKE)

Primary manifests are under `k8s/`:

- `namespace.yaml`
- `configmap.yaml`
- `secret.yaml` (template; create real secret via kubectl command)
- `backend-deployment.yaml`, `backend-service.yaml`
- `ml-pipeline-deployment.yaml`, `ml-pipeline-service.yaml`
- `hpa.yaml`

For full deployment and benchmark workflow:

- `docs/C1_TASKS.md`
- `docs/GKE_BENCHMARK.md`
- `scripts/day5-gke-deployment.sh`

## Current GCP Resources

Current resources in use for deployment and storage:

- **GCP project**: `v2aicloud` (`241955658779`)
- **GKE cluster**: `v2ai-cluster` (region `us-central1`, status `RUNNING`)
- **Kubernetes namespace**: `v2ai`
- **Backend service**: `v2ai-backend` (`LoadBalancer`, external IP `35.222.254.140`, port `80`)
- **ML service**: `ml-pipeline-service` (`ClusterIP`, port `8001`)
- **GCS bucket**: `v2aibucket`
- **Firestore database**: `v2aidb`, collection `videos`
- **Monitoring namespace**: `monitoring` (Prometheus + Grafana)

## Load Testing

Locust files:

- `tests/locustfile.py` (backend-focused workload)
- `tests/ml_locustfile.py` (direct ML endpoint workload)

Example:

```bash
GKE_IP=$(kubectl get svc v2ai-backend -n v2ai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
venv/bin/python -m locust -f tests/locustfile.py --host=http://$GKE_IP --users=20 --spawn-rate=5 --run-time=120s --headless --csv=results/gke
```

## Current Benchmark Results

Results below are from repository artifacts in `results/`.

### GKE (health-focused run)

Source: `results/gke_stats.csv` (Aggregated row)

- Requests: **95**
- Failures: **3**
- Requests/sec: **1.3609**
- Avg latency: **573.63 ms**
- p95: **880 ms**
- p99: **1500 ms**

### GKE (end-to-end traffic mix: health + status + upload)

Source: `results/gke-e2e_stats.csv` (Aggregated row)

- Requests: **274**
- Failures: **2**
- Requests/sec: **3.0918**
- Avg latency: **1787.23 ms**
- p95: **5000 ms**
- p99: **7700 ms**

### Multi-VM baseline (comparison)

Source: `results/Locust_2026-04-09-01h33_locustfile.py_http___34.131.164.21_8000_requests.csv` (Aggregated row)

- Requests: **215**
- Failures: **19**
- Requests/sec: **1.3054**
- Avg latency: **19864.32 ms**
- p95: **94000 ms**
- p99: **118000 ms**

## Useful Commands

```bash
make logs
make test
make down
make clean
```

```bash
kubectl get pods -n v2ai
kubectl get svc -n v2ai
kubectl get hpa -n v2ai
```

## Notes

- `tests/test_api.py` currently targets a remote base URL; update it if you need local API testing.
- `k8s/` contains additional monitoring patches used during GKE troubleshooting and presentation workflows.
