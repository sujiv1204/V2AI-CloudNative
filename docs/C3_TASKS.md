# C3 (Harshil) Tasks: Multi-VM Deployment & Load Testing

## Overview

Your tasks for Day 5-6:
1. **Create 2 additional VMs** for ML Pipeline (VM-1 backend already exists!)
2. **Configure load balancing** between ML Pipeline instances
3. **Create Locust load testing scripts**
4. **Collect baseline performance metrics**

**Important:** Follow these instructions EXACTLY. Test each step before moving to the next.

---

## Existing Resources (Day 4)

**VM-1 (Backend) already running:**
- Name: `v2ai-vm-1`
- External IP: `35.193.246.44`
- Ports: 8000 (backend), 8001 (ML), 9090 (Prometheus)

> ⚠️ **Do NOT delete or modify v2ai-vm-1!** C2 is using it for UI development.  
> You'll create 2 NEW VMs for additional ML Pipeline instances.

### Test Existing Deployment

```bash
# Test backend
curl http://35.193.246.44:8000/health

# Test ML pipeline
curl http://35.193.246.44:8001/health

# Test full pipeline (optional)
curl -X POST -F "file=@video.mp4" http://35.193.246.44:8000/upload
```

---

## Prerequisites

Before starting, make sure you have:

1. ✅ Git installed
2. ✅ `gcloud` CLI installed and authenticated
3. ✅ Docker knowledge (basic commands)
4. ✅ Received `gcp-key.json` and `.env` from C1 (sujiv)
5. ✅ GCP IAM access granted by C1

### Verify GCP Access

```bash
# Login to GCP
gcloud auth login

# Set project
gcloud config set project v2aicloud

# Verify you can list VMs
gcloud compute instances list

# Verify you can list firewall rules
gcloud compute firewall-rules list
```

If you get permission denied, contact C1 to grant you these roles:

- `roles/compute.instanceAdmin.v1`
- `roles/compute.networkAdmin`

---

## Architecture

```
                         Internet
                             │
                    ┌────────▼────────┐
                    │  35.193.246.44  │
                    │     VM-1        │  ← Already exists!
                    │  Backend+ML     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼────────┐    │     ┌────────▼────────┐
     │   VM-2 :8001    │    │     │   VM-3 :8001    │
     │   ML Pipeline   │    │     │   ML Pipeline   │
     │   (NEW)         │    │     │   (NEW)         │
     └────────┬────────┘    │     └────────┬────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼────────┐
                    │  GCS + Firestore │
                    └─────────────────┘
```

**VM Configuration:**

| VM   | Name         | Purpose     | Status          | Ports           |
| ---- | ------------ | ----------- | --------------- | --------------- |
| VM-1 | v2ai-vm-1    | Backend+ML  | ✅ EXISTS       | 8000, 8001      |
| VM-2 | v2ai-ml-1    | ML Pipeline | 🆕 CREATE       | 8001 (internal) |
| VM-3 | v2ai-ml-2    | ML Pipeline | 🆕 CREATE       | 8001 (internal) |

---

## Part 1: Setup Your Development Environment

### Step 1.1: Clone and Setup

```bash
# Clone the repository
git clone <repo-url>
cd V2AI-CloudNative

# Switch to main and pull latest
git checkout main
git pull origin main

# Create your feature branch
git checkout -b feature/c3-multivm

# Copy secret files (received from C1)
cp ~/Downloads/gcp-key.json .
cp ~/Downloads/.env .

# Verify files exist
ls -la gcp-key.json .env
```

### Step 1.2: Test Against Live Endpoint (No Local Docker Needed!)

```bash
# Test existing deployment
curl http://35.193.246.44:8000/health
curl http://35.193.246.44:8001/health
```

Both should return `{"status":"ok"}`. If yes, you're ready to create new VMs.

---

## Part 2: Create Additional ML VMs

> ⚠️ **VM-1 (v2ai-vm-1) already exists!** Skip creating it. Only create VM-2 and VM-3.

### Step 2.1: Create VM-2 (ML Pipeline)

```bash
gcloud compute instances create v2ai-ml-1 \
  --project=v2aicloud \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --boot-disk-size=30GB \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=v2ai-ml
```

**Note:** Using `e2-standard-2` (2 vCPU, 8GB RAM) for ML workloads.

**Save the INTERNAL_IP** - the backend will use this.

### Step 2.2: Create VM-3 (ML Pipeline)

```bash
gcloud compute instances create v2ai-ml-2 \
  --project=v2aicloud \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --boot-disk-size=30GB \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=v2ai-ml
```

### Step 2.3: Verify All VMs

```bash
gcloud compute instances list --project=v2aicloud
```

**Expected output:**

```
NAME          ZONE           MACHINE_TYPE    INTERNAL_IP  EXTERNAL_IP     STATUS
v2ai-vm-1     us-central1-a  e2-medium       10.128.0.2   35.193.246.44   RUNNING  ← Existing
v2ai-ml-1     us-central1-a  e2-standard-2   10.128.0.X   35.XXX.XXX.XXX  RUNNING  ← New
v2ai-ml-2     us-central1-a  e2-standard-2   10.128.0.Y   35.XXX.XXX.XXX  RUNNING  ← New
```

**Record these IPs:**

- VM-1 (v2ai-vm-1) External IP: `35.193.246.44` (already known)
- VM-1 (v2ai-vm-1) Internal IP: ____________
- VM-2 (v2ai-ml-1) Internal IP: ____________
- VM-3 (v2ai-ml-2) Internal IP: ____________

---

## Part 3: Configure Firewall Rules

### Step 3.1: Allow External Access to Backend

```bash
gcloud compute firewall-rules create v2ai-backend-external \
  --project=v2aicloud \
  --allow=tcp:8000 \
  --target-tags=v2ai-backend \
  --description="Allow external access to backend API"
```

### Step 3.2: Allow Internal Communication for ML

```bash
gcloud compute firewall-rules create v2ai-ml-internal \
  --project=v2aicloud \
  --allow=tcp:8001 \
  --source-tags=v2ai-backend \
  --target-tags=v2ai-ml \
  --description="Allow backend to reach ML pipeline"
```

### Step 3.3: Verify Firewall Rules

```bash
gcloud compute firewall-rules list --project=v2aicloud
```

---

## Part 4: Install Docker on All VMs

### Step 4.1: Install Docker on VM-1 (Backend)

```bash
# SSH into VM-1
gcloud compute ssh v2ai-backend --project=v2aicloud --zone=us-central1-a

# Run these commands on the VM:
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify
docker --version
docker-compose --version

# Exit SSH
exit
```

### Step 4.2: Install Docker on VM-2 (ML-1)

```bash
# SSH into VM-2
gcloud compute ssh v2ai-ml-1 --project=v2aicloud --zone=us-central1-a

# Same commands as above
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

docker --version
docker-compose --version

exit
```

### Step 4.3: Install Docker on VM-3 (ML-2)

```bash
# SSH into VM-3
gcloud compute ssh v2ai-ml-2 --project=v2aicloud --zone=us-central1-a

# Same commands
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

docker --version
docker-compose --version

exit
```

**Important:** After installing Docker, you need to logout and login again for group changes to take effect. Or use `sudo docker` for now.

---

## Part 5: Deploy Services

### Step 5.1: Create Deployment Files

Create `docker-compose.backend.yml` for backend-only deployment:

```yaml
version: "3.8"

services:
    backend:
        build: ./backend
        ports:
            - "8000:8000"
        environment:
            - ML_PIPELINE_URL=${ML_PIPELINE_URL}
            - GCP_PROJECT_ID=${GCP_PROJECT_ID}
            - GCS_BUCKET_NAME=${GCS_BUCKET_NAME}
            - GCS_KEY_PATH=/app/gcp-key.json
            - FIRESTORE_DB_NAME=${FIRESTORE_DB_NAME}
            - FIRESTORE_COLLECTION=${FIRESTORE_COLLECTION}
        volumes:
            - ./gcp-key.json:/app/gcp-key.json:ro
            - ./uploads:/app/uploads
        restart: unless-stopped
```

Create `docker-compose.ml.yml` for ML-only deployment:

```yaml
version: "3.8"

services:
    ml_pipeline:
        build: ./ml_pipeline
        ports:
            - "8001:8001"
        environment:
            - TRANSFORMERS_CACHE=/models
            - HF_HOME=/models
        volumes:
            - models_cache:/models
        restart: unless-stopped

volumes:
    models_cache:
```

### Step 5.2: Copy Files to VMs

**Copy to VM-1 (Backend):**

```bash
# Create directory on VM
gcloud compute ssh v2ai-backend --project=v2aicloud --zone=us-central1-a \
  --command="mkdir -p ~/V2AI-CloudNative"

# Copy files
gcloud compute scp --recurse --project=v2aicloud --zone=us-central1-a \
  backend docker-compose.backend.yml .env gcp-key.json \
  v2ai-backend:~/V2AI-CloudNative/
```

**Copy to VM-2 (ML-1):**

```bash
gcloud compute ssh v2ai-ml-1 --project=v2aicloud --zone=us-central1-a \
  --command="mkdir -p ~/V2AI-CloudNative"

gcloud compute scp --recurse --project=v2aicloud --zone=us-central1-a \
  ml_pipeline docker-compose.ml.yml \
  v2ai-ml-1:~/V2AI-CloudNative/
```

**Copy to VM-3 (ML-2):**

```bash
gcloud compute ssh v2ai-ml-2 --project=v2aicloud --zone=us-central1-a \
  --command="mkdir -p ~/V2AI-CloudNative"

gcloud compute scp --recurse --project=v2aicloud --zone=us-central1-a \
  ml_pipeline docker-compose.ml.yml \
  v2ai-ml-2:~/V2AI-CloudNative/
```

### Step 5.3: Update Backend .env with ML URLs

Get the internal IPs of ML VMs:

```bash
ML1_IP=$(gcloud compute instances describe v2ai-ml-1 \
  --project=v2aicloud --zone=us-central1-a \
  --format='get(networkInterfaces[0].networkIP)')

ML2_IP=$(gcloud compute instances describe v2ai-ml-2 \
  --project=v2aicloud --zone=us-central1-a \
  --format='get(networkInterfaces[0].networkIP)')

echo "ML-1 Internal IP: $ML1_IP"
echo "ML-2 Internal IP: $ML2_IP"
```

SSH into backend VM and update .env:

```bash
gcloud compute ssh v2ai-backend --project=v2aicloud --zone=us-central1-a

# Edit .env
cd ~/V2AI-CloudNative
nano .env
```

Update the `ML_PIPELINE_URL` to point to ML-1:

```
ML_PIPELINE_URL=http://10.128.0.X:8001
```

(Replace `10.128.0.X` with the actual internal IP of v2ai-ml-1)

### Step 5.4: Start Services

**Start ML Pipeline on VM-2:**

```bash
gcloud compute ssh v2ai-ml-1 --project=v2aicloud --zone=us-central1-a

cd ~/V2AI-CloudNative
sudo docker-compose -f docker-compose.ml.yml up -d --build

# Check status
sudo docker-compose -f docker-compose.ml.yml ps
sudo docker-compose -f docker-compose.ml.yml logs

exit
```

**Start ML Pipeline on VM-3:**

```bash
gcloud compute ssh v2ai-ml-2 --project=v2aicloud --zone=us-central1-a

cd ~/V2AI-CloudNative
sudo docker-compose -f docker-compose.ml.yml up -d --build

sudo docker-compose -f docker-compose.ml.yml ps

exit
```

**Start Backend on VM-1:**

```bash
gcloud compute ssh v2ai-backend --project=v2aicloud --zone=us-central1-a

cd ~/V2AI-CloudNative
sudo docker-compose -f docker-compose.backend.yml up -d --build

sudo docker-compose -f docker-compose.backend.yml ps

exit
```

---

## Part 6: Verify Deployment

### Step 6.1: Test Health Endpoints

Get the backend external IP:

```bash
BACKEND_IP=$(gcloud compute instances describe v2ai-backend \
  --project=v2aicloud --zone=us-central1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Backend IP: $BACKEND_IP"

# Test backend
curl http://$BACKEND_IP:8000/health
```

Expected: `{"status":"ok"}`

### Step 6.2: Test Internal Communication

SSH into backend and test ML pipeline:

```bash
gcloud compute ssh v2ai-backend --project=v2aicloud --zone=us-central1-a

# Test ML-1 from backend
curl http://10.128.0.X:8001/health  # Replace with ML-1 IP

# Test ML-2 from backend
curl http://10.128.0.Y:8001/health  # Replace with ML-2 IP

exit
```

### Step 6.3: Test End-to-End Upload

```bash
# Upload a video
curl -X POST -F "file=@lecture.mp4" http://$BACKEND_IP:8000/upload
```

Note the `file_id` and poll status:

```bash
FILE_ID="your-file-id"
curl http://$BACKEND_IP:8000/status/$FILE_ID
```

---

## Part 7: Load Balancing (Round-Robin)

To use both ML instances, you need to modify the backend to load balance.

### Step 7.1: Create Load Balancer Config

Create `backend/load_balancer.py`:

```python
import itertools
import httpx
import logging
from typing import List

logger = logging.getLogger(__name__)

class MLLoadBalancer:
    """Simple round-robin load balancer for ML pipeline instances"""

    def __init__(self, urls: List[str]):
        self.urls = urls
        self._cycle = itertools.cycle(urls)
        logger.info(f"Load balancer initialized with {len(urls)} ML instances: {urls}")

    def get_next_url(self) -> str:
        """Get next ML pipeline URL in round-robin fashion"""
        return next(self._cycle)

    async def call_ml_service(self, endpoint: str, **kwargs) -> dict:
        """Call ML service with automatic failover"""
        errors = []

        for _ in range(len(self.urls)):
            url = self.get_next_url()
            full_url = f"{url}{endpoint}"

            try:
                async with httpx.AsyncClient(timeout=300.0) as client:
                    if 'files' in kwargs:
                        response = await client.post(full_url, files=kwargs['files'])
                    elif 'json' in kwargs:
                        response = await client.post(full_url, json=kwargs['json'])
                    else:
                        response = await client.get(full_url)

                    response.raise_for_status()
                    logger.info(f"ML call successful: {url}")
                    return response.json()

            except Exception as e:
                errors.append(f"{url}: {str(e)}")
                logger.warning(f"ML call failed on {url}: {e}")
                continue

        # All instances failed
        raise Exception(f"All ML instances failed: {errors}")


# Global load balancer instance
_load_balancer = None

def get_load_balancer() -> MLLoadBalancer:
    """Get or create load balancer instance"""
    global _load_balancer
    if _load_balancer is None:
        import os
        urls_str = os.getenv("ML_PIPELINE_URLS", os.getenv("ML_PIPELINE_URL", "http://localhost:8001"))
        urls = [url.strip() for url in urls_str.split(",")]
        _load_balancer = MLLoadBalancer(urls)
    return _load_balancer
```

### Step 7.2: Update Backend .env

Add multiple ML URLs:

```bash
# Multiple ML instances (comma-separated)
ML_PIPELINE_URLS=http://10.128.0.3:8001,http://10.128.0.4:8001
```

### Step 7.3: Update Backend main.py

Replace direct `httpx` calls with load balancer calls in `process_ml_pipeline()`:

```python
from load_balancer import get_load_balancer

# In process_ml_pipeline function, replace:
# async with httpx.AsyncClient() as client:
#     response = await client.post(...)

# With:
lb = get_load_balancer()
transcript_result = await lb.call_ml_service("/transcript", files={"file": audio_content})
summary_result = await lb.call_ml_service("/summarize", json={"text": transcript_text})
qa_result = await lb.call_ml_service("/qa", json={"text": transcript_text})
```

---

## Part 8: Create Locust Load Tests

### Step 8.1: Install Locust

```bash
pip install locust
```

### Step 8.2: Create Locust Test File

Create `tests/locustfile.py`:

```python
"""
Locust load testing for V2AI API
Usage: locust -f tests/locustfile.py --host=http://BACKEND_IP:8000
"""

from locust import HttpUser, task, between
import os
import time

class V2AIUser(HttpUser):
    """Simulated user for V2AI API"""

    wait_time = between(1, 3)  # Wait 1-3 seconds between tasks

    @task(10)
    def health_check(self):
        """Frequent health check - lightweight endpoint"""
        self.client.get("/health")

    @task(3)
    def check_random_status(self):
        """Check status of a random file (simulates polling)"""
        # Use a known file_id or generate random
        file_id = "test-file-id"
        self.client.get(f"/status/{file_id}", name="/status/[file_id]")

    @task(1)
    def upload_video(self):
        """Upload a video file - heavy endpoint"""
        # Use a small test video for load testing
        test_video_path = os.getenv("TEST_VIDEO_PATH", "test_video.mp4")

        if not os.path.exists(test_video_path):
            # Skip if no test video
            return

        with open(test_video_path, "rb") as f:
            files = {"file": ("test.mp4", f, "video/mp4")}
            with self.client.post("/upload", files=files, catch_response=True) as response:
                if response.status_code == 200:
                    response.success()
                else:
                    response.failure(f"Upload failed: {response.text}")


class V2AIMLUser(HttpUser):
    """Direct ML Pipeline testing (internal endpoints)"""

    wait_time = between(0.5, 2)

    @task(5)
    def health_check(self):
        """Health check on ML pipeline"""
        self.client.get("/health")

    @task(1)
    def summarize(self):
        """Test summarization endpoint"""
        test_text = "This is a test lecture about machine learning. " * 50
        self.client.post("/summarize", json={"text": test_text})

    @task(1)
    def generate_questions(self):
        """Test QA endpoint"""
        test_text = "Machine learning is a subset of artificial intelligence. " * 30
        self.client.post("/qa", json={"text": test_text})
```

### Step 8.3: Run Locust Test

```bash
# Get backend IP
BACKEND_IP=$(gcloud compute instances describe v2ai-backend \
  --project=v2aicloud --zone=us-central1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# Run Locust with web UI
locust -f tests/locustfile.py --host=http://$BACKEND_IP:8000

# Or headless mode for CI
locust -f tests/locustfile.py \
  --host=http://$BACKEND_IP:8000 \
  --users=10 \
  --spawn-rate=2 \
  --run-time=60s \
  --headless \
  --csv=results/multivm
```

Open http://localhost:8089 for Locust web UI.

### Step 8.4: Collect Metrics

After running tests, you'll have:

- `results/multivm_stats.csv` - Request statistics
- `results/multivm_failures.csv` - Failed requests
- `results/multivm_stats_history.csv` - Time series data

---

## Part 9: Document Results

Create `docs/MULTIVM_BENCHMARK.md`:

```markdown
# Multi-VM Deployment Benchmark Results

## Configuration

| Component   | VM Type       | Count | Resources       |
| ----------- | ------------- | ----- | --------------- |
| Backend     | e2-medium     | 1     | 2 vCPU, 4GB RAM |
| ML Pipeline | e2-standard-2 | 2     | 2 vCPU, 8GB RAM |

## Test Parameters

- Duration: 60 seconds
- Users: 10 concurrent
- Spawn rate: 2 users/second

## Results

| Metric          | Value  |
| --------------- | ------ |
| Total Requests  | XXX    |
| Requests/sec    | XXX    |
| Median Latency  | XXX ms |
| 95th Percentile | XXX ms |
| 99th Percentile | XXX ms |
| Failure Rate    | X%     |

## Observations

- ...
- ...

## Screenshots

![Locust Results](screenshots/locust_multivm.png)
```

---

## Part 10: Commit and Push

### Step 10.1: Add New Files

```bash
git add docker-compose.backend.yml
git add docker-compose.ml.yml
git add backend/load_balancer.py
git add tests/locustfile.py
git add docs/MULTIVM_BENCHMARK.md
```

### Step 10.2: Commit

```bash
git commit -m "Add multi-VM deployment with load balancing and Locust tests"
```

### Step 10.3: Push

```bash
git push origin feature/c3-multivm
```

---

## Verification Checklist

- [ ] 3 VMs created (v2ai-backend, v2ai-ml-1, v2ai-ml-2)
- [ ] Docker installed on all VMs
- [ ] Firewall rules configured
- [ ] Backend running on VM-1 (port 8000)
- [ ] ML Pipeline running on VM-2 (port 8001)
- [ ] ML Pipeline running on VM-3 (port 8001)
- [ ] Backend can reach both ML instances
- [ ] End-to-end upload works from public IP
- [ ] Locust tests created
- [ ] Baseline metrics collected
- [ ] Documentation written
- [ ] PR created

---

## Cleanup Commands (After Benchmarking)

```bash
# Delete VMs
gcloud compute instances delete v2ai-backend v2ai-ml-1 v2ai-ml-2 \
  --project=v2aicloud --zone=us-central1-a --quiet

# Delete firewall rules
gcloud compute firewall-rules delete v2ai-backend-external v2ai-ml-internal \
  --project=v2aicloud --quiet
```

---

## Common Issues

### Issue: "Connection refused" from backend to ML

**Check:**

1. ML container is running: `sudo docker-compose -f docker-compose.ml.yml ps`
2. Firewall rule exists: `gcloud compute firewall-rules list`
3. Using internal IP (10.128.x.x), not external

### Issue: "Permission denied" on gcloud

**Solution:** Ask C1 to grant IAM roles again.

### Issue: Docker not found after install

**Solution:** Logout and login again, or use `sudo docker`.

### Issue: Locust can't reach backend

**Check:**

1. Backend external IP is correct
2. Firewall rule `v2ai-backend-external` exists
3. Backend container is running

---

## Timeline

| Day   | Task                          | Hours |
| ----- | ----------------------------- | ----- |
| Day 5 AM | Create 2 new VMs, install Docker | 2-3   |
| Day 5 AM | Configure firewall rules      | 1-2   |
| Day 5 PM | Deploy ML Pipeline to new VMs | 2-3   |
| Day 5 PM | Test inter-VM communication   | 1-2   |
| Day 6 AM | Create Locust scripts         | 2-3   |
| Day 6 AM | Run load tests                | 2-3   |
| Day 6 PM | Collect metrics & document    | 2-3   |

---

## Need Help?

1. Check VM logs: `sudo docker-compose logs -f`
2. Check VM status: `gcloud compute instances list`
3. Ask in team chat with specific error message
4. Include output of commands and error messages
