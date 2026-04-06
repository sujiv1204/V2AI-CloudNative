# V2AI Day 4 Report - Single VM Deployment Complete

## Overview

Day 4 single VM deployment is **COMPLETE**. The full pipeline is running on GCP and tested end-to-end from the public internet.

**Current Status:** ✅ Production deployment on GCP VM verified working

---

## Day 4 Results

### VM Deployment

| Resource | Details |
|----------|---------|
| VM Name | v2ai-vm-1 |
| Zone | us-central1-a |
| Machine Type | e2-medium (2 vCPU, 4GB RAM) |
| External IP | 35.193.246.44 |
| OS | Ubuntu 22.04 LTS |
| Disk | 30GB |

### Services Running

| Service | Port | Status |
|---------|------|--------|
| Backend | 8000 | ✅ Running |
| ML Pipeline | 8001 | ✅ Running |
| Prometheus | 9090 | ✅ Running |

### End-to-End Test Results

```
Upload Time: ~2s
Transcription Time: 72.95s
Summarization Time: 64.66s (4 chunks)
QA Generation Time: 10.41s
Total Processing: ~149s
```

**Test File:** lecture.mp4 (49MB)
- Transcript: 4961 characters extracted
- Summary: 1160 characters generated  
- Questions: 3 questions generated

---

## Day 4 Tasks by Contributor

### ✅ C1 (sujiv) - Backend & Cloud - COMPLETE

**Completed:**
- [x] Created GCE VM instance (v2ai-vm-1)
- [x] Installed Docker 28.2.2 and docker-compose v2.24.0
- [x] Configured firewall rules (v2ai-allow-http: ports 8000, 8001, 9090)
- [x] Deployed all services via docker-compose

### ✅ C2 (Sagnik) - ML Pipeline - VERIFIED

**Verified on VM:**
- [x] ML pipeline running on VM
- [x] Transcription working (72.95s for 49MB video)
- [x] Summarization working (64.66s, 4 chunks)
- [x] Model loading successful (first-run downloads complete)

### ✅ C3 (Harshil) - Integration & Testing - VERIFIED

**Verified:**
- [x] docker-compose running on VM
- [x] Public API accessible (http://35.193.246.44:8000)
- [x] End-to-end test passed from internet

---

## Current Architecture (Single VM)

```
                    Internet
                        |
                   [Firewall]
              (ports 8000,8001,9090)
                        |
                   [v2ai-vm-1]
                   35.193.246.44
              +------------------+
              |   Docker Host    |
              |  +-----------+   |
              |  | Backend   |   |
              |  | :8000     |   |
              |  +-----------+   |
              |       |          |
              |  +-----------+   |
              |  | ML Pipeline|  |
              |  | :8001     |   |
              |  +-----------+   |
              |       |          |
              |  +-----------+   |
              |  | Prometheus|   |
              |  | :9090     |   |
              |  +-----------+   |
              +------------------+
                        |
                [GCS / Firestore]
```

---

## Next Steps - Multi-VM Scaling (Optional Day 4 Extension)

To scale to multiple VMs:

1. **Create VM-2 for ML Pipeline only:**
```bash
gcloud compute instances create v2ai-vm-2 \
  --zone=us-central1-a --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud
```

2. **Update Backend to use VM-2 internal IP:**
```bash
# On VM-1, update .env:
ML_PIPELINE_URL=http://<vm2-internal-ip>:8001
```

3. **Deploy ML Pipeline only on VM-2:**
```bash
docker compose up ml_pipeline -d
```

---

## Day 4 Checklist - COMPLETE

- [x] GCP VM created and running
- [x] Docker/Compose installed
- [x] Firewall rules configured
- [x] Application deployed via docker-compose
- [x] Health endpoints accessible from internet
- [x] End-to-end pipeline tested successfully
- [x] All 3 ML stages working (transcription, summarization, QA)

---

## Commands Quick Reference

```bash
# SSH into VM
gcloud compute ssh v2ai-vm-1 --project=v2aicloud --zone=us-central1-a

# View container status
sudo docker-compose ps

# View logs
sudo docker-compose logs -f

# Restart services
sudo docker-compose restart

# Test from local machine
curl http://35.193.246.44:8000/health
curl http://35.193.246.44:8001/health

# Upload video and test
curl -X POST -F 'file=@lecture.mp4' http://35.193.246.44:8000/upload

# Check status
curl http://35.193.246.44:8000/status/<file_id>

# Cleanup (when done testing)
gcloud compute instances delete v2ai-vm-1 --project=v2aicloud --zone=us-central1-a
gcloud compute firewall-rules delete v2ai-allow-http --project=v2aicloud
```

---

## Day 5 Preview - GKE Deployment

Next steps for Day 5:
1. Create GKE cluster
2. Push images to Google Container Registry
3. Create Kubernetes deployments/services
4. Test in K8s environment
