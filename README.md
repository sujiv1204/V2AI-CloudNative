# V2AI Cloud-Native Platform

Scalable lecture video understanding as a service using FastAPI, Docker, Kubernetes, and cloud-native microservices.

## Overview

This project implements an end-to-end platform for lecture video processing with:
- **C1 (Backend & Cloud):** FastAPI orchestration + GCP integration
- **C2 (ML Pipeline):** Whisper (transcription), BART (summarization)
- **C3 (Testing & Analytics):** T5 (question generation), Locust (load testing), Prometheus/Grafana (metrics)

## Project Structure

```
.
├── backend/              # C1 - Backend service (FastAPI)
│   ├── main.py
│   ├── config.py
│   ├── gcp_service.py
│   ├── audio_service.py
│   ├── Dockerfile
│   └── requirements.txt
├── ml_pipeline/          # C2 - ML inference service
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── tests/                # C3 - Testing & load testing
│   ├── test_api.py
│   ├── locustfile.py
│   └── requirements.txt
├── k8s/                  # Kubernetes manifests
│   ├── namespace.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   └── hpa.yaml
├── monitoring/           # Prometheus configuration
├── docker-compose.yml    # Local development
└── PROGRESS_REPORT.md    # Detailed implementation status
```

## Quick Start

### Setup

```bash
# Copy environment template
cp .env.example .env

# Add your GCP service account JSON key
cp /path/to/gcp-key.json ./gcp-key.json
```

### Run with Docker Compose

```bash
docker compose up --build
```

Services will be available at:
- Backend: http://localhost:8000/health
- ML Pipeline: http://localhost:8001/health
- Prometheus: http://localhost:9090

### Development with venv

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt
bash verify-day1.sh
```

## Configuration

### Required Environment Variables

```
GCP_PROJECT_ID=v2aicloud
GCS_BUCKET_NAME=v2aibucket
GCS_KEY_PATH=./gcp-key.json
FIRESTORE_DB_NAME=v2aidb
FIRESTORE_COLLECTION=videos
UPLOAD_DIR=uploads
LOG_LEVEL=INFO
```

### GCP Resources

- **Project:** v2aicloud
- **GCS Bucket:** v2aibucket (us region, Standard)
- **Firestore:** v2aidb (native mode)
- **Service Account:** Must have Cloud Storage and Firestore permissions

## Development Workflow

### Cleanup Test Data

```bash
bash cleanup.sh
```

This will:
- Clear local uploads/
- Remove Docker volumes
- Delete GCS files
- Clean Firestore (manual step via GCP Console)

## Status

See `PROGRESS_REPORT.md` for detailed implementation status and team roadmap.

### Current Phase

- C1 Day 1-2: Complete (Backend + Docker)
- C1 Day 3: Awaiting C2 & C3 day 1 completion
- C2 Day 1: Ready to start
- C3 Day 1: Ready to start

## Architecture

**Workflow:**
1. Client uploads video to Backend `/upload` endpoint
2. Backend extracts audio, uploads video + audio to GCS
3. Backend stores metadata in Firestore
4. Day 3: Backend calls ML Pipeline for transcription & summarization
5. Day 3: Backend calls QA service for question generation
6. Final response: transcript + summary + questions

**Deployment:**
- Local: Docker Compose (3 containers)
- Cloud: GKE with HPA (scales 2-10 replicas based on CPU/memory)

## Notes

- FFmpeg required in all containers
- Models cached in containers
- Services communicate via Docker network
- All team code in respective `/backend`, `/ml_pipeline`, `/tests` directories
