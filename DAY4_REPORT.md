# V2AI Day 4 Preparation Report

## Overview

Day 3 is complete. All services are containerized, working end-to-end, and ready for multi-VM deployment.

**Current Status:** Integration branch has full pipeline working locally with Docker Compose.

---

## Day 4 Tasks by Contributor

### C1 (sujiv) - Backend & Cloud

**Day 4 Tasks:**

1. Create 2-3 GCE VM instances (e2-medium or larger recommended)
2. Install Docker and Docker Compose on each VM
3. Configure firewall rules for inter-VM communication
4. Set up network tags and VPC rules

**Steps:**

```bash
# 1. Create VMs (run from local machine with gcloud)
gcloud compute instances create v2ai-vm-1 v2ai-vm-2 \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=v2ai-server

# 2. Configure firewall
gcloud compute firewall-rules create v2ai-allow-internal \
  --allow=tcp:8000-8001,tcp:9090 \
  --source-tags=v2ai-server \
  --target-tags=v2ai-server

gcloud compute firewall-rules create v2ai-allow-external \
  --allow=tcp:8000 \
  --target-tags=v2ai-server

# 3. SSH into each VM and install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
# Log out and back in

# 4. Clone repo and setup
git clone <repo-url>
cd V2AI-CloudNative
cp /path/to/gcp-key.json .
cp .env.example .env
# Edit .env with correct values
```

**Deliverables:**

- [ ] 2-3 VMs running and accessible
- [ ] Docker installed on all VMs
- [ ] Firewall rules configured
- [ ] Network connectivity verified between VMs

---

### C2 (Sagnik) - ML Pipeline

**Day 4 Tasks:**

1. Validate ML pipeline in VM environment
2. Fix any environment-specific issues
3. Optimize model loading for VM resources
4. Test transcription and summarization on VM

**Steps:**

```bash
# SSH into VM
gcloud compute ssh v2ai-vm-1 --zone=us-central1-a

# Test ML pipeline container
cd V2AI-CloudNative
docker compose up ml_pipeline -d

# Verify health
curl http://localhost:8001/health

# Test transcription (use small audio file first)
curl -X POST -F 'file=@test.wav' http://localhost:8001/transcript

# Test summarization
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Test text for summarization."}' \
  http://localhost:8001/summarize
```

**Environment Issues to Watch:**

- Memory limits (BART needs ~2GB RAM)
- Model download on first run (may take 5-10 min)
- CPU-only inference (ensure CUDA_VISIBLE_DEVICES= is set)

**Deliverables:**

- [ ] ML pipeline running on VM
- [ ] Transcription working on VM
- [ ] Summarization working on VM
- [ ] Document any VM-specific fixes needed

---

### C3 (Harshil) - Integration & Testing

**Day 4 Tasks:**

1. Deploy docker-compose on multiple VMs
2. Validate inter-VM communication
3. Test public API endpoint
4. Document deployment process

**Steps:**

```bash
# Deploy on VM-1 (backend + ml_pipeline)
gcloud compute ssh v2ai-vm-1 --zone=us-central1-a
cd V2AI-CloudNative
docker compose up -d

# Deploy on VM-2 (can run additional ml_pipeline for scaling test)
gcloud compute ssh v2ai-vm-2 --zone=us-central1-a
cd V2AI-CloudNative
# Modify docker-compose to only run ml_pipeline
docker compose up ml_pipeline -d

# Test from local machine
VM_IP=$(gcloud compute instances describe v2ai-vm-1 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

curl http://$VM_IP:8000/health
curl -X POST -F 'file=@lecture.mp4' http://$VM_IP:8000/upload
```

**Inter-VM Communication Test:**

```bash
# From VM-1, test connectivity to VM-2
VM2_INTERNAL_IP=$(gcloud compute instances describe v2ai-vm-2 --zone=us-central1-a --format='get(networkInterfaces[0].networkIP)')
curl http://$VM2_INTERNAL_IP:8001/health
```

**Deliverables:**

- [ ] docker-compose running on multiple VMs
- [ ] Inter-VM communication working
- [ ] Public API accessible from internet
- [ ] Deployment documentation written

---

## Architecture for Day 4

```
                    Internet
                        |
                   [Firewall]
                        |
              +---------+---------+
              |                   |
         [VM-1]              [VM-2]
         Backend             ML Pipeline
         (8000)              (8001)
              |                   |
              +---[VPC Network]---+
                        |
                   [GCS/Firestore]
```

**Option A: Single VM (Simple)**

- All services on one VM
- Good for initial testing

**Option B: Multi-VM (Recommended)**

- VM-1: Backend service
- VM-2: ML Pipeline service
- Backend calls ML Pipeline via internal IP

---

## Environment Variables for VMs

Create `.env` on each VM:

```bash
# GCP Settings
GCP_PROJECT_ID=241955658779
GCS_BUCKET_NAME=v2aibucket
GCS_KEY_PATH=./gcp-key.json
FIRESTORE_DB_NAME=v2aidb
FIRESTORE_COLLECTION=videos

# ML Pipeline URL (update for multi-VM)
ML_PIPELINE_URL=http://localhost:8001  # or http://<vm2-internal-ip>:8001

# Logging
LOG_LEVEL=INFO
```

---

## Checklist Before Day 4 Starts

- [x] Integration branch merged/stable
- [x] docker-compose.yml working locally
- [x] All services tested end-to-end
- [x] GCP credentials available (gcp-key.json)
- [x] Cleanup script available (scripts/cleanup-gcp.sh)

---

## Commands Quick Reference

```bash
# Create VMs
gcloud compute instances create v2ai-vm-1 --zone=us-central1-a --machine-type=e2-medium

# SSH into VM
gcloud compute ssh v2ai-vm-1 --zone=us-central1-a

# Get VM external IP
gcloud compute instances describe v2ai-vm-1 --format='get(networkInterfaces[0].accessConfigs[0].natIP)'

# Get VM internal IP
gcloud compute instances describe v2ai-vm-1 --format='get(networkInterfaces[0].networkIP)'

# Copy files to VM
gcloud compute scp gcp-key.json v2ai-vm-1:~/V2AI-CloudNative/

# View VM logs
docker compose logs -f

# Cleanup VMs (after testing)
gcloud compute instances delete v2ai-vm-1 v2ai-vm-2 --zone=us-central1-a
```
