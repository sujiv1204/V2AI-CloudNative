# V2AI Cloud-Native Platform

Scalable lecture video understanding as a service.

## Project Structure

```
.
├── backend/              # C1 - FastAPI orchestration service
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── ml_pipeline/          # C2 - ML model inference services
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── tests/                # C3 - Testing and analytics
│   ├── test_api.py
│   ├── locustfile.py
│   └── requirements.txt
├── monitoring/           # Prometheus config
│   └── prometheus.yml
├── docker-compose.yml    # Local dev orchestration
└── .env.example         # Environment variables template
```

## Quick Start

### Local Development

```bash
cp .env.example .env
docker-compose up --build
```

**Services:**
- Backend: http://localhost:8000
- ML Pipeline: http://localhost:8001
- Prometheus: http://localhost:9090

### API Endpoints

**Backend (C1):**
- `GET /health` - Health check
- `POST /upload` - Upload and process video

**ML Pipeline (C2):**
- `POST /transcript` - Transcribe audio
- `POST /summarize` - Summarize text
- `POST /qa` - Generate questions

## Team Responsibilities

- **C1 (Backend & Cloud):** FastAPI orchestration, GCP integration, infra setup
- **C2 (ML Pipeline):** Whisper, BART, T5 model integration
- **C3 (Testing & Analytics):** Load testing (Locust), metrics (Prometheus), dashboards (Grafana)

## Development Notes

- Models cache in container - set `TORCH_HOME` for persistence
- ffmpeg required in all containers for audio extraction
- Services communicate via Docker network
