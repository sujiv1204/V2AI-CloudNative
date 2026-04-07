# V2AI API Documentation

## Live Endpoints (Day 4 VM Deployment)

**Backend API Base URL:** `http://35.193.246.44:8000`  
**ML Pipeline API Base URL:** `http://35.193.246.44:8001`  
**Prometheus:** `http://35.193.246.44:9090`

> **Note:** These endpoints are running on `v2ai-vm-1` in GCP. Use these for testing instead of localhost.

---

## Backend API (Port 8000)

### Health Check

```bash
GET /health
```

**Response:**

```json
{ "status": "ok" }
```

**Example:**

```bash
curl http://35.193.246.44:8000/health
```

---

### Upload Video

```bash
POST /upload
Content-Type: multipart/form-data
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| file | File | Yes | Video file (MP4, AVI, MOV) |

**Response:**

```json
{
    "file_id": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140",
    "filename": "lecture.mp4",
    "message": "Video uploaded. ML pipeline processing started in background.",
    "status": "queued",
    "video_path": "gs://v2aibucket/videos/1f132083-9f8b-6b11-8be8-f9b1ddbf8140_lecture.mp4",
    "audio_path": "gs://v2aibucket/audio/1f132083-9f8b-6b11-8be8-f9b1ddbf8140.wav",
    "note": "Check Firestore or use the status endpoint to monitor progress"
}
```

**Example:**

```bash
curl -X POST -F "file=@lecture.mp4" http://35.193.246.44:8000/upload
```

---

### Check Processing Status

```bash
GET /status/{file_id}
```

**Parameters:**
| Field | Type | Description |
|-------|------|-------------|
| file_id | string | UUID returned from upload |

**Response (Processing):**

```json
{
    "file_id": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140",
    "status": "processing",
    "original_filename": "lecture.mp4",
    "upload_timestamp": "2026-04-06T22:30:37.965955"
}
```

**Response (Complete):**

```json
{
    "file_id": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140",
    "status": "processed",
    "original_filename": "lecture.mp4",
    "upload_timestamp": "2026-04-06T22:30:37.965955",
    "processing_completed_at": "2026-04-06T22:33:06.847484",
    "ml_results": {
        "transcript": {
            "text": "Hello dear students, welcome back to your biology class...",
            "status": "success",
            "filename": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140.wav"
        },
        "summary": {
            "text": "Students in our previous lecture we discussed carbohydrates...",
            "status": "success",
            "input_length": 4961,
            "output_length": 1160
        },
        "questions": {
            "questions": [
                "fats and proteins",
                "what are the food items which we have in our daily diet which are rich in fat",
                "ey plant source and the animal source"
            ],
            "status": "success",
            "count": 3
        }
    }
}
```

**Example:**

```bash
curl http://35.193.246.44:8000/status/1f132083-9f8b-6b11-8be8-f9b1ddbf8140
```

---

## ML Pipeline API (Port 8001)

### Health Check

```bash
GET /health
```

**Response:**

```json
{ "status": "ok" }
```

**Example:**

```bash
curl http://35.193.246.44:8001/health
```

---

### Transcribe Audio

```bash
POST /transcript
Content-Type: multipart/form-data
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| file | File | Yes | Audio file (WAV, MP3) |

**Response:**

```json
{
    "text": "Hello dear students, welcome back to your biology class...",
    "status": "success",
    "filename": "audio.wav"
}
```

**Example:**

```bash
curl -X POST -F "file=@audio.wav" http://35.193.246.44:8001/transcript
```

---

### Summarize Text

```bash
POST /summarize
Content-Type: application/json
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| text | string | Yes | Text to summarize |

**Response:**

```json
{
    "text": "Summary of the input text...",
    "status": "success",
    "input_length": 4961,
    "output_length": 1160
}
```

**Example:**

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Your long text here..."}' \
  http://35.193.246.44:8001/summarize
```

---

### Generate Questions

```bash
POST /qa
Content-Type: application/json
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| text | string | Yes | Text to generate questions from |

**Response:**

```json
{
    "questions": ["Question 1?", "Question 2?", "Question 3?"],
    "status": "success",
    "count": 3,
    "input_length": 4961
}
```

**Example:**

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Your lecture text here..."}' \
  http://35.193.246.44:8001/qa
```

---

## Status Codes

| Code | Meaning                          |
| ---- | -------------------------------- |
| 200  | Success                          |
| 400  | Bad Request (missing parameters) |
| 404  | Not Found (invalid file_id)      |
| 500  | Server Error (check logs)        |

---

## Processing Flow

```
1. POST /upload (video file)
   └── Returns file_id immediately

2. Background Processing:
   ├── Extract audio (ffmpeg)
   ├── Upload to GCS
   ├── Call /transcript
   ├── Call /summarize
   └── Call /qa

3. GET /status/{file_id}
   └── Poll until status = "processed"

4. Results stored in Firestore
```

---

## GCP Resources

| Resource     | Name            | Details                      |
| ------------ | --------------- | ---------------------------- |
| VM           | v2ai-vm-1       | 35.193.246.44, us-central1-a |
| GCS Bucket   | v2aibucket      | Videos and audio storage     |
| Firestore DB | v2aidb          | Collection: videos           |
| Firewall     | v2ai-allow-http | Ports 8000, 8001, 9090       |

---

## Quick Test Commands

```bash
# Test backend health
curl http://35.193.246.44:8000/health

# Test ML pipeline health
curl http://35.193.246.44:8001/health

# Upload video (full pipeline)
curl -X POST -F "file=@lecture.mp4" http://35.193.246.44:8000/upload

# Check status (replace FILE_ID)
curl http://35.193.246.44:8000/status/FILE_ID

# Test summarization directly
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Machine learning is a subset of artificial intelligence that enables systems to learn from data."}' \
  http://35.193.246.44:8001/summarize

# Test QA directly
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Machine learning is a subset of artificial intelligence that enables systems to learn from data."}' \
  http://35.193.246.44:8001/qa
```

---

## Performance (Day 4 Benchmark)

| Stage         | Time      | Notes               |
| ------------- | --------- | ------------------- |
| Upload        | ~2s       | 49MB video          |
| Transcription | ~73s      | faster-whisper base |
| Summarization | ~65s      | BART, 4 chunks      |
| QA Generation | ~10s      | T5-small            |
| **Total**     | **~150s** | End-to-end          |
