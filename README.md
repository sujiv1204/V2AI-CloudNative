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

### Using Docker Compose

```bash
cp .env.example .env
docker compose up --build
```

Or use the Makefile:
```bash
make build
make up
make logs
```

### Using Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -q -r backend/requirements.txt
bash verify-day1.sh
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

**⚠️ IMPORTANT: Service Account Key Must Match Project ID**
- Service account JSON key must be from project `241955658779`
- See `GCP_KEY_FIX.md` if you get "database not found" errors

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

## Verification Guide - How to Test Day 1

### Option 1: Test with Docker Compose
```bash
# Start all services
docker compose up --build

# In another terminal, test endpoints
curl -X GET http://localhost:8000/health
curl -X GET http://localhost:8001/health

# Test upload endpoint with a video file
curl -X POST -F 'file=@lecture.mp4' http://localhost:8000/upload

# View logs
docker compose logs -f backend
```

### Option 2: Test with Local venv
```bash
# Run verification script
bash verify-day1.sh

# Script validates:
# 1. All Python modules import correctly
# 2. GCP config loads from .env
# 3. API routes registered
# 4. Required directories created
```

### What Each Test Checks

1. **Health Checks** - Confirm services are running
   - Backend: `GET /health` → `{"status": "ok"}`
   - ML Pipeline: `GET /health` → `{"status": "ok"}`

2. **Configuration** - Validates GCP settings loaded:
   - GCP_PROJECT_ID
   - GCS_BUCKET_NAME (v2aibucket)
   - FIRESTORE_DB_NAME (v2aidb)

3. **Endpoints** - Confirms API routes exist:
   - Backend: `POST /upload` (video processing)
   - ML Pipeline: `/transcript`, `/summarize`, `/qa` (placeholders for C2)

4. **Audio Extraction** - When actual video uploaded:
   - Extract WAV from MP4/MOV/AVI
   - Save locally to `uploads/audio/`
   - Upload to GCS `gs://v2aibucket/audio/`

5. **GCP Integration** - When `.gcp-key.json` in place:
   - Upload files to Cloud Storage
   - Store metadata in Firestore
   - Return file_id and GCS paths to client

### Testing Without GCP Key (Local Only)
Services will start but GCP operations will fail. Test structure only:
```bash
# Services start
docker compose up

# Health checks work
curl http://localhost:8000/health

# File upload endpoint exists but GCS ops will error (expected)
curl -X POST -F 'file=@video.mp4' http://localhost:8000/upload
```

Add real GCP key to test full pipeline:
```bash
cp /path/to/gcp-key.json ./gcp-key.json
docker compose restart backend
```

## Cleanup - Reset Test Data

To delete test files and re-test from scratch:

```bash
# Clean GCS audio files
gsutil -m rm gs://v2aibucket/audio/*

# Clean GCS video files
gsutil -m rm gs://v2aibucket/videos/*

# Clean Firestore 'videos' collection
gcloud firestore delete-collection v2aidb videos --quiet

# Clean local uploads directory
rm -rf uploads/
mkdir -p uploads/audio
```

Or run the cleanup script:
```bash
bash cleanup-test-files.sh
```

## Documentation

- `C1_DAY1_CHECKLIST.md` - Complete C1 Day 1 verification checklist
- `SETUP_REPORT.md` - Full setup report with test results
