# V2AI Cloud-Native: Day 5-8 Master Plan

## Project Overview

**Title:** Cloud-Native V2AI: Scalable Lecture Video Understanding as a Service

**Current Status:** Day 4 complete - Single VM deployment working end-to-end.

**Goal:** Benchmark multi-VM Docker Compose deployment vs managed Kubernetes (GKE) with load testing, metrics collection, and performance analysis.

---

## Team Assignments

| Contributor      | Role                  | Day 5-8 Focus                              |
| ---------------- | --------------------- | ------------------------------------------ |
| **C1 (sujiv)**   | Backend & Cloud       | GKE Kubernetes deployment, HPA, metrics    |
| **C2 (Sagnik)**  | ML Pipeline & UI      | Store results in Firestore, build basic UI |
| **C3 (Harshil)** | Integration & Testing | Multi-VM deployment, Locust load testing   |

---

## Architecture Overview

```
                        ┌─────────────────────────────────────────────────────┐
                        │                    Internet                          │
                        └─────────────────────┬───────────────────────────────┘
                                              │
                        ┌─────────────────────▼───────────────────────────────┐
                        │                  Load Balancer                       │
                        └─────────────────────┬───────────────────────────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              │                               │                               │
    ┌─────────▼─────────┐          ┌─────────▼─────────┐          ┌─────────▼─────────┐
    │   Multi-VM Setup  │          │   GKE Cluster     │          │   Basic UI        │
    │   (C3 - Harshil)  │          │   (C1 - sujiv)    │          │   (C2 - Sagnik)   │
    │                   │          │                   │          │                   │
    │  VM-1: Backend    │          │  Deployment:      │          │  - Upload page    │
    │  VM-2: ML Pipeline│          │  - backend (HPA)  │          │  - Status check   │
    │  VM-3: ML Pipeline│          │  - ml_pipeline    │          │  - Results view   │
    │                   │          │  - prometheus     │          │                   │
    └─────────┬─────────┘          └─────────┬─────────┘          └─────────┬─────────┘
              │                               │                               │
              └───────────────────────────────┼───────────────────────────────┘
                                              │
                        ┌─────────────────────▼───────────────────────────────┐
                        │              GCP Services                            │
                        │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
                        │  │   GCS    │  │ Firestore│  │ Container Reg.   │   │
                        │  │ (videos) │  │ (results)│  │ (Docker images)  │   │
                        │  └──────────┘  └──────────┘  └──────────────────┘   │
                        └─────────────────────────────────────────────────────┘
```

---

## Day-by-Day Plan

### Day 5: Setup & Parallel Development

| C1 (sujiv)           | C2 (Sagnik)                   | C3 (Harshil)                  |
| -------------------- | ----------------------------- | ----------------------------- |
| Create GKE cluster   | Store ML results in Firestore | Create 3 VMs                  |
| Push images to GCR   | Test Firestore integration    | Install Docker on all VMs     |
| Create K8s manifests | Start basic UI (upload page)  | Configure inter-VM networking |

### Day 6: Core Implementation

| C1 (sujiv)       | C2 (Sagnik)                 | C3 (Harshil)                |
| ---------------- | --------------------------- | --------------------------- |
| Deploy to GKE    | Complete Firestore storage  | Deploy services across VMs  |
| Configure HPA    | Add status/results UI pages | Test inter-VM communication |
| Test autoscaling | Connect UI to backend API   | Document deployment process |

### Day 7: Testing & Optimization

| C1 (sujiv)              | C2 (Sagnik)        | C3 (Harshil)             |
| ----------------------- | ------------------ | ------------------------ |
| Tune resource limits    | Polish UI          | Prepare Locust scripts   |
| Debug any K8s issues    | Fix any UI bugs    | Run baseline load tests  |
| Setup Prometheus in K8s | Add loading states | Collect multi-VM metrics |

### Day 8: Benchmarking & Analysis

| C1 (sujiv)          | C2 (Sagnik)        | C3 (Harshil)              |
| ------------------- | ------------------ | ------------------------- |
| Run K8s load tests  | Final UI testing   | Run multi-VM load tests   |
| Collect K8s metrics | Create screenshots | Compare VM vs K8s results |
| Grafana dashboards  | Document UI usage  | Generate benchmark report |

---

## What Needs to be Done

### 1. Store ML Results in Firestore (C2)

Currently we only store video metadata. We need to store:

- Full transcript text
- Summary text
- Generated questions

**Location:** `backend/main.py` - the `process_ml_pipeline()` function already stores results.

### 2. Build Basic UI (C2)

Simple web interface with 3 pages:

- Upload page (video file upload)
- Status page (processing progress)
- Results page (transcript, summary, questions)

**Tech:** HTML/CSS/JavaScript (vanilla) - served from backend

### 3. Multi-VM Deployment (C3)

Deploy across 3 VMs:

- VM-1: Backend service
- VM-2: ML Pipeline (primary)
- VM-3: ML Pipeline (replica for load balancing)

### 4. GKE Deployment (C1)

- Create GKE cluster
- Push Docker images to GCR
- Create Kubernetes deployment manifests
- Configure HPA (Horizontal Pod Autoscaler)

---

## GCP Permissions for C2 and C3

### IAM Roles Required

Grant these roles to C2 and C3's Google accounts:

```bash
# For C2 (Sagnik) - needs Firestore and basic compute access
gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:sagnik@email.com" \
  --role="roles/datastore.user"

gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:sagnik@email.com" \
  --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:sagnik@email.com" \
  --role="roles/compute.viewer"

# For C3 (Harshil) - needs full VM and networking access
gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:harshil@email.com" \
  --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:harshil@email.com" \
  --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:harshil@email.com" \
  --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding v2aicloud \
  --member="user:harshil@email.com" \
  --role="roles/datastore.viewer"
```

### Roles Summary

| Role                             | C2  | C3  | Purpose                           |
| -------------------------------- | --- | --- | --------------------------------- |
| `roles/datastore.user`           | ✅  | ❌  | Read/write Firestore              |
| `roles/storage.objectViewer`     | ✅  | ✅  | View GCS buckets                  |
| `roles/compute.viewer`           | ✅  | ❌  | View VMs (for testing)            |
| `roles/compute.instanceAdmin.v1` | ❌  | ✅  | Create/manage VMs                 |
| `roles/compute.networkAdmin`     | ❌  | ✅  | Manage firewall rules             |
| `roles/datastore.viewer`         | ❌  | ✅  | View Firestore (for verification) |

---

## Files to Share with C2 and C3

### Required Files

```
Files to send via secure channel (NOT in git):
├── gcp-key.json          # Service account key (KEEP SECRET)
└── .env                  # Environment variables
```

### .env File Contents

```bash
# GCP Settings
GCP_PROJECT_ID=v2aicloud
GCS_BUCKET_NAME=v2aibucket
GCS_KEY_PATH=./gcp-key.json
FIRESTORE_DB_NAME=v2aidb
FIRESTORE_COLLECTION=videos

# Service URLs (update for multi-VM)
ML_PIPELINE_URL=http://ml_pipeline:8001

# Logging
LOG_LEVEL=INFO
```

### Security Notes

⚠️ **IMPORTANT:**

1. Send `gcp-key.json` via secure channel (not email/slack/git)
2. Add `gcp-key.json` to `.gitignore` (already done)
3. Never commit credentials to git
4. Rotate keys if accidentally exposed

---

## Git Branching Strategy

### Starting Point

Everyone starts from `main` branch (which has the Day 4 working code).

### Branch Names

```
main                        # Production-ready code
├── feature/c2-firestore    # C2: Firestore storage improvements
├── feature/c2-ui           # C2: Basic UI
├── feature/c3-multivm      # C3: Multi-VM deployment
└── feature/c1-gke          # C1: GKE deployment
```

### How to Start (for C2 and C3)

```bash
# 1. Clone the repository
git clone <repo-url>
cd V2AI-CloudNative

# 2. Make sure you're on main and pull latest
git checkout main
git pull origin main

# 3. Create your feature branch
git checkout -b feature/c2-firestore   # For C2
# OR
git checkout -b feature/c3-multivm     # For C3

# 4. Copy the secret files (sent separately by C1)
cp /path/to/gcp-key.json .
cp /path/to/.env .

# 5. Start Docker Compose to verify everything works
docker-compose up -d --build

# 6. Test health endpoints
curl http://localhost:8000/health
curl http://localhost:8001/health

# 7. Now start making your changes...
```

### Commit Guidelines

```bash
# Make small, focused commits
git add <specific-files>
git commit -m "Add Firestore storage for transcript"

# Push to your branch regularly
git push origin feature/c2-firestore

# When ready for review, create a PR to main
```

---

## Testing Checkpoints

### C2 Checkpoints

- [ ] Transcript stored in Firestore document
- [ ] Summary stored in Firestore document
- [ ] Questions stored in Firestore document
- [ ] UI upload page works
- [ ] UI shows processing status
- [ ] UI displays all results (transcript, summary, questions)

### C3 Checkpoints

- [ ] 3 VMs created and accessible via SSH
- [ ] Docker installed on all VMs
- [ ] Backend running on VM-1 (port 8000)
- [ ] ML Pipeline running on VM-2 (port 8001)
- [ ] ML Pipeline running on VM-3 (port 8001)
- [ ] Backend can call ML Pipeline on VM-2/VM-3
- [ ] Locust load test scripts ready
- [ ] Baseline metrics collected

### C1 Checkpoints

- [ ] GKE cluster created
- [ ] Images pushed to GCR
- [ ] Deployments running in K8s
- [ ] Services accessible via LoadBalancer
- [ ] HPA configured and auto-scales
- [ ] Prometheus collecting metrics
- [ ] Grafana dashboard ready

---

## Communication Plan

### Daily Sync

- Quick status update (what you did, any blockers)
- Share PRs for review
- Coordinate on integration points

### Integration Points

| From | To    | What                          |
| ---- | ----- | ----------------------------- |
| C2   | C1/C3 | Firestore schema (if changed) |
| C2   | C1/C3 | UI requires backend endpoints |
| C3   | C1    | Locust scripts can be reused  |
| C1   | C3    | K8s manifests for reference   |

---

## Individual Task Files

- **C2 (Sagnik):** See `docs/C2_TASKS.md` - Firestore storage + UI
- **C3 (Harshil):** See `docs/C3_TASKS.md` - Multi-VM deployment + Load testing

Each file contains **detailed step-by-step instructions** with exact code and commands.
