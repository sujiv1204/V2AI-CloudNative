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

## C1 Day 1 - Backend & Cloud Setup (COMPLETE)

### GCP Setup
- GCS Bucket: `v2aibucket` (us region, Standard storage)
- Firestore DB: `v2aidb` (native mode)
- Service Account JSON key: Place in project root as `gcp-key.json`

### Backend Implementation
1. **FastAPI `/upload` endpoint** - Accepts MP4, MOV, AVI files with multipart form data
2. **Audio extraction** - Extracts WAV (16kHz, PCM) using ffmpeg
3. **GCS upload** - Videos and audio uploaded to separate paths:
   - Videos: `gs://v2aibucket/videos/{file_id}_{filename}`
   - Audio: `gs://v2aibucket/audio/{file_id}.wav`
4. **Firestore metadata** - Stores upload metadata with unique file_id (UUIDv6)

### Project Structure Updates
```
backend/
├── main.py                # Updated with full Day 1 flow
├── config.py              # GCP configuration (pydantic settings)
├── gcp_service.py         # GCS & Firestore operations
├── audio_service.py       # Audio extraction via ffmpeg
├── requirements.txt       # Updated with ffmpeg-python, uuid6
└── Dockerfile             # ffmpeg already included
```

### Environment Setup
```bash
# Copy template and add your GCP credentials
cp .env.example .env
# Copy your GCP service account JSON key to project root
cp /path/to/service-account-key.json gcp-key.json
```

**Required environment variables:**
- `GCP_PROJECT_ID=241955658779`
- `GCS_BUCKET_NAME=v2aibucket`
- `GCS_KEY_PATH=./gcp-key.json`
- `FIRESTORE_DB_NAME=v2aidb`
- `FIRESTORE_COLLECTION=videos`

### API Response (POST /upload)
```json
{
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Video uploaded and processed",
  "filename": "lecture.mp4",
  "video_path": "gs://v2aibucket/videos/550e8400-e29b-41d4-a716-446655440000_lecture.mp4",
  "audio_path": "gs://v2aibucket/audio/550e8400-e29b-41d4-a716-446655440000.wav",
  "status": "uploaded"
}
```

### Firestore Document Structure
```json
{
  "file_id": "550e8400-e29b-41d4-a716-446655440000",
  "original_filename": "lecture.mp4",
  "video_path": "gs://v2aibucket/videos/...",
  "audio_path": "gs://v2aibucket/audio/...",
  "local_video_path": "/app/uploads/...",
  "local_audio_path": "/app/uploads/audio/...",
  "upload_timestamp": "2026-04-05T10:30:45.123456",
  "status": "uploaded"
}
```

### Ready for C2 & C3
- C2 can retrieve audio from `audio_path` in Firestore for transcription
- C3 can write tests against the `/upload` endpoint
- All services communicate via Docker network
