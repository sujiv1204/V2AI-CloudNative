# Day 4 GCP VM Deployment - Step-by-Step Guide

This document provides the exact steps and outputs from the Day 4 single VM deployment.

**Date:** April 6, 2026  
**Project:** V2AI-CloudNative  
**VM:** v2ai-vm-1 (35.193.246.44)

---

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and authenticated
- Project files ready locally
- `gcp-key.json` service account key

---

## Step 1: Create GCP VM Instance

```bash
gcloud compute instances create v2ai-vm-1 \
  --project=v2aicloud \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --boot-disk-size=30GB \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=v2ai-server
```

**Output:**

```
Created [https://www.googleapis.com/compute/v1/projects/v2aicloud/zones/us-central1-a/instances/v2ai-vm-1].
NAME        ZONE           MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
v2ai-vm-1   us-central1-a  e2-medium                  10.128.0.2   35.193.246.44  RUNNING
```

---

## Step 2: Create Firewall Rule

```bash
gcloud compute firewall-rules create v2ai-allow-http \
  --project=v2aicloud \
  --allow=tcp:8000,tcp:8001,tcp:9090 \
  --target-tags=v2ai-server \
  --description="Allow HTTP traffic for V2AI services"
```

**Output:**

```
Creating firewall...done.
NAME             NETWORK  DIRECTION  PRIORITY  ALLOW                        DENY  DISABLED
v2ai-allow-http  default  INGRESS    1000      tcp:8000,tcp:8001,tcp:9090         False
```

---

## Step 3: SSH into VM and Install Docker

```bash
gcloud compute ssh v2ai-vm-1 --project=v2aicloud --zone=us-central1-a
```

Once connected to the VM:

```bash
# Update packages
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com | sudo sh

# Check Docker version
docker --version
```

**Output:**

```
Docker version 28.2.2, build e6534ba
```

---

## Step 4: Install Docker Compose

```bash
# Download docker-compose standalone binary
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose

# Make executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

**Output:**

```
Docker Compose version v2.24.0
```

---

## Step 5: Copy Project Files to VM

From your local machine:

```bash
cd /home/sujiv/Documents/projects/V2AI-CloudNative

# Copy all required files
gcloud compute scp --recurse --project=v2aicloud --zone=us-central1-a \
  backend ml_pipeline docker-compose.yml .env gcp-key.json test-integration.sh lecture.mp4 \
  v2ai-vm-1:~/V2AI-CloudNative/
```

**Output:**

```
audio_service.py                100%  786     2.8KB/s   00:00
Dockerfile                      100%  305     1.1KB/s   00:00
config.py                       100%  415     1.5KB/s   00:00
gcp_service.py                  100% 2155     7.6KB/s   00:00
main.py                         100% 7611    26.8KB/s   00:00
requirements.txt                100%  241     0.9KB/s   00:00
transcription.py                100% 2697     9.5KB/s   00:00
summarization.py                100% 4457    15.2KB/s   00:00
qa.py                           100% 2848    10.1KB/s   00:00
docker-compose.yml              100% 1219     4.3KB/s   00:00
.env                            100%  167     0.6KB/s   00:00
gcp-key.json                    100% 2349     8.3KB/s   00:00
test-integration.sh             100% 2461     8.5KB/s   00:00
lecture.mp4                     100%   49MB   5.0MB/s   00:09
```

---

## Step 6: Create Prometheus Configuration

SSH into VM and create the monitoring directory:

```bash
gcloud compute ssh v2ai-vm-1 --project=v2aicloud --zone=us-central1-a
```

```bash
mkdir -p ~/V2AI-CloudNative/monitoring

cat > ~/V2AI-CloudNative/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: backend
    static_configs:
      - targets: ["backend:8000"]
  - job_name: ml_pipeline
    static_configs:
      - targets: ["ml_pipeline:8001"]
EOF
```

---

## Step 7: Verify Files on VM

```bash
cd ~/V2AI-CloudNative && ls -la
```

**Output:**

```
total 50084
drwxrwxr-x 4 sujiv sujiv     4096 Apr  6 22:13 .
drwxr-x--- 5 sujiv sujiv     4096 Apr  6 22:12 ..
-rw-rw-r-- 1 sujiv sujiv      167 Apr  6 22:13 .env
drwxrwxr-x 4 sujiv sujiv     4096 Apr  6 22:13 backend
-rw-rw-r-- 1 sujiv sujiv     1219 Apr  6 22:13 docker-compose.yml
-rw-rw-r-- 1 sujiv sujiv     2349 Apr  6 22:13 gcp-key.json
-rw-rw-r-- 1 sujiv sujiv 51251124 Apr  6 22:13 lecture.mp4
drwxrwxr-x 4 sujiv sujiv     4096 Apr  6 22:13 ml_pipeline
drwxrwxr-x 2 sujiv sujiv     4096 Apr  6 22:28 monitoring
-rwxrwxr-x 1 sujiv sujiv     2461 Apr  6 22:13 test-integration.sh
```

Verify .env contents:

```bash
cat .env
```

**Output:**

```
GCP_PROJECT_ID=v2aicloud
GCS_BUCKET_NAME=v2aibucket
GCS_KEY_PATH=./gcp-key.json
FIRESTORE_DB_NAME=v2aidb
FIRESTORE_COLLECTION=videos
UPLOAD_DIR=uploads
LOG_LEVEL=INFO
```

---

## Step 8: Build and Start Docker Containers

```bash
cd ~/V2AI-CloudNative
sudo docker-compose up -d --build
```

**Output (truncated):**

```
[+] Building 180.5s (25/25) FINISHED
 => [backend] FROM docker.io/library/python:3.11-slim
 => [ml_pipeline] FROM docker.io/library/python:3.10-slim
 => Installing dependencies...
 => Successfully built images

Network v2ai-cloudnative_v2ai-network  Created
Volume "v2ai-cloudnative_prometheus_data"  Created
Volume "v2ai-cloudnative_models_cache"  Created
Container v2ai-ml-pipeline  Created
Container v2ai-prometheus  Created
Container v2ai-backend  Created
Container v2ai-prometheus  Started
Container v2ai-ml-pipeline  Started
Container v2ai-backend  Started
```

---

## Step 9: Verify Containers Running

```bash
sudo docker-compose ps
```

**Output:**

```
NAME               IMAGE                          COMMAND                  SERVICE       CREATED          STATUS          PORTS
v2ai-backend       v2ai-cloudnative-backend       "uvicorn main:app --…"   backend       20 seconds ago   Up 19 seconds   0.0.0.0:8000->8000/tcp
v2ai-ml-pipeline   v2ai-cloudnative-ml_pipeline   "uvicorn main:app --…"   ml_pipeline   20 seconds ago   Up 19 seconds   0.0.0.0:8001->8001/tcp
v2ai-prometheus    prom/prometheus:latest         "/bin/prometheus --c…"   prometheus    20 seconds ago   Up 19 seconds   0.0.0.0:9090->9090/tcp
```

---

## Step 10: Test Health Endpoints (From Local Machine)

```bash
VM_IP="35.193.246.44"

# Test backend health
curl -s "http://$VM_IP:8000/health"
```

**Output:**

```json
{ "status": "ok" }
```

```bash
# Test ML pipeline health
curl -s "http://$VM_IP:8001/health"
```

**Output:**

```json
{ "status": "ok" }
```

---

## Step 11: Upload Video for End-to-End Test

```bash
VM_IP="35.193.246.44"

curl -s -X POST "http://$VM_IP:8000/upload" \
  -F "file=@lecture.mp4" \
  --connect-timeout 30 \
  --max-time 120
```

**Output:**

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

---

## Step 12: Poll Status Until Complete

```bash
FILE_ID="1f132083-9f8b-6b11-8be8-f9b1ddbf8140"

# Poll every 15 seconds
for i in $(seq 0 15 300); do
  STATUS=$(curl -s "http://$VM_IP:8000/status/$FILE_ID")
  STAGE=$(echo "$STATUS" | jq -r '.status')
  echo "[$i s] Status: $STAGE"

  if [ "$STAGE" = "processed" ]; then
    echo "$STATUS" | jq '.'
    break
  fi

  sleep 15
done
```

**Output:**

```
[0 s] Status: processing
[15 s] Status: processing
[30 s] Status: processing
[45 s] Status: processing
[60 s] Status: processing
[75 s] Status: processing
[90 s] Status: processing
[105 s] Status: processed
```

---

## Step 13: Final Results

**Full Response:**

```json
{
    "file_id": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140",
    "status": "processed",
    "original_filename": "lecture.mp4",
    "upload_timestamp": "2026-04-06T22:30:37.965955",
    "ml_results": {
        "processing_completed_at": "2026-04-06T22:33:06.847484",
        "file_id": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140",
        "summary": {
            "input_length": 4961,
            "text": "Students in our previous lecture we discussed carbohydrates and activities to detect presence of carbohydrates in given food sample. In today's lecture we shall discuss fats and proteins. These fats they provide us energy and they produce energy much more than the energy that is produced by carbohydrates...",
            "status": "success",
            "output_length": 1160
        },
        "questions": {
            "input_length": 4961,
            "count": 3,
            "status": "success",
            "questions": [
                "fats and proteins",
                "what are the food items which we have in our daily diet which are rich in fat",
                "ey plant source and the animal source"
            ]
        },
        "transcript": {
            "text": "Hello dear students, welcome back to your biology class, you are strong boys and strong girls and I know you must be absolutely healthy. Students in our previous lecture we discussed carbohydrates...",
            "status": "success",
            "filename": "1f132083-9f8b-6b11-8be8-f9b1ddbf8140.wav"
        }
    },
    "processing_completed_at": "2026-04-06T22:33:06.847484"
}
```

---

## Step 14: Check Container Logs

```bash
sudo docker-compose logs --tail=30 ml_pipeline
```

**Output:**

```
v2ai-ml-pipeline  | INFO:     Started server process [1]
v2ai-ml-pipeline  | INFO:     Application startup complete.
v2ai-ml-pipeline  | INFO:     Uvicorn running on http://0.0.0.0:8001
v2ai-ml-pipeline  | 2026-04-06 22:31:51,684 - services.transcription - INFO - Transcription completed successfully
v2ai-ml-pipeline  | 2026-04-06 22:31:51,685 - services.transcription - INFO - Transcription time: 72.95s
v2ai-ml-pipeline  | INFO:     172.18.0.4:60158 - "POST /transcript HTTP/1.1" 200 OK
v2ai-ml-pipeline  | 2026-04-06 22:31:51,714 - services.summarization - INFO - Starting summarization
v2ai-ml-pipeline  | 2026-04-06 22:31:51,714 - services.summarization - INFO - Loading summarization model on device -1
v2ai-ml-pipeline  | 2026-04-06 22:32:12,465 - services.summarization - INFO - Summarization model loaded successfully
v2ai-ml-pipeline  | 2026-04-06 22:32:12,637 - services.summarization - INFO - Processing 4 chunks
v2ai-ml-pipeline  | 2026-04-06 22:32:56,376 - services.summarization - INFO - Summarization completed
v2ai-ml-pipeline  | 2026-04-06 22:32:56,376 - services.summarization - INFO - Summarization time: 64.66s
v2ai-ml-pipeline  | INFO:     172.18.0.4:54878 - "POST /summarize HTTP/1.1" 200 OK
v2ai-ml-pipeline  | 2026-04-06 22:32:56,400 - services.qa - INFO - Starting question generation
v2ai-ml-pipeline  | 2026-04-06 22:32:56,400 - services.qa - INFO - Loading QA model: t5-small
v2ai-ml-pipeline  | 2026-04-06 22:33:02,676 - services.qa - INFO - QA model loaded on cpu
v2ai-ml-pipeline  | 2026-04-06 22:33:02,676 - services.qa - WARNING - Input too large (4961 chars), truncating to 2000
v2ai-ml-pipeline  | 2026-04-06 22:33:06,806 - services.qa - INFO - Generated 3 questions
v2ai-ml-pipeline  | 2026-04-06 22:33:06,806 - services.qa - INFO - QA time: 10.41s
v2ai-ml-pipeline  | INFO:     172.18.0.4:44778 - "POST /qa HTTP/1.1" 200 OK
```

---

## Performance Summary

| Stage            | Time      | Details                     |
| ---------------- | --------- | --------------------------- |
| Video Upload     | ~2s       | 49MB file to GCS            |
| Audio Extraction | ~1s       | ffmpeg MP4 → WAV            |
| Transcription    | 72.95s    | faster-whisper (base model) |
| Summarization    | 64.66s    | BART (4 chunks)             |
| QA Generation    | 10.41s    | T5-small (3 questions)      |
| **Total**        | **~149s** | End-to-end                  |

---

## GCP Resources Created

| Resource      | Name            | Details                        |
| ------------- | --------------- | ------------------------------ |
| VM Instance   | v2ai-vm-1       | e2-medium, 30GB, us-central1-a |
| External IP   | 35.193.246.44   | Ephemeral                      |
| Firewall Rule | v2ai-allow-http | tcp:8000,8001,9090             |
| Network Tag   | v2ai-server     | Applied to VM                  |

---

## Cleanup Commands

When done testing, clean up GCP resources:

```bash
# Delete VM
gcloud compute instances delete v2ai-vm-1 \
  --project=v2aicloud --zone=us-central1-a --quiet

# Delete firewall rule
gcloud compute firewall-rules delete v2ai-allow-http \
  --project=v2aicloud --quiet

# Clean GCS and Firestore (from local with gcp-key.json)
./scripts/cleanup-gcp.sh --all
```

---

## Troubleshooting

### Issue: Containers not starting

```bash
sudo docker-compose logs
```

### Issue: Cannot connect to endpoints

```bash
# Check firewall rules
gcloud compute firewall-rules list --project=v2aicloud

# Check VM is running
gcloud compute instances list --project=v2aicloud
```

### Issue: Upload fails

```bash
# Check backend logs
sudo docker-compose logs backend

# Verify GCP credentials
sudo docker-compose exec backend cat /app/gcp-key.json
```

### Issue: ML processing stuck

```bash
# Check ML pipeline logs
sudo docker-compose logs ml_pipeline

# Check memory usage
sudo docker stats
```

---

## Conclusion

Day 4 single VM deployment was successful. The full V2AI pipeline is running on GCP and accessible from the public internet. The system can:

1. ✅ Accept video uploads via REST API
2. ✅ Extract audio and store in GCS
3. ✅ Transcribe audio using Whisper
4. ✅ Summarize transcript using BART
5. ✅ Generate questions using T5
6. ✅ Store results in Firestore
7. ✅ Return results via status endpoint
