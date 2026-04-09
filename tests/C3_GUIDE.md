# C3 (Harshil) Execution Guide: Multi-VM & Load Testing

This guide provides step-by-step instructions for completing the Day 5-6 tasks: Multi-VM deployment and performance benchmarking.

## Phase 1: Environment Setup

1.  **Infrastructure Verification:**
    *   Ensure VM-1 (`v2ai-vm-1` at `35.193.246.44`) is running.
    *   Verify you have the `gcp-key.json` and `.env` files.
    *   Authenticate with GCP: `gcloud auth login` and `gcloud config set project v2aicloud`.

2.  **Code Preparation:**
    *   You are currently on the `feature/c3-multivm` branch.
    *   Ensure `backend/load_balancer.py` exists (created by Antigravity).
    *   Ensure `tests/locustfile.py` is updated (updated by Antigravity).

## Phase 2: Multi-VM Deployment

### 1. Create ML Pipeline VMs
Run the following commands to create two new VMs for the ML Pipeline:

```bash
# Create ML-1
gcloud compute instances create v2ai-ml-1 \
  --project=v2aicloud --zone=us-central1-a \
  --machine-type=e2-standard-2 --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud --tags=v2ai-ml

# Create ML-2
gcloud compute instances create v2ai-ml-2 \
  --project=v2aicloud --zone=us-central1-a \
  --machine-type=e2-standard-2 --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud --tags=v2ai-ml
```

### 2. Networking & Firewalls
Configure firewalls to allow the backend to talk to the ML instances:

```bash
# Allow external access to Backend (Port 8000)
gcloud compute firewall-rules create v2ai-backend-external --allow=tcp:8000 --target-tags=v2ai-backend

# Allow internal Backend-to-ML communication (Port 8001)
gcloud compute firewall-rules create v2ai-ml-internal --allow=tcp:8001 --source-tags=v2ai-backend --target-tags=v2ai-ml
```

### 3. Deploy Containers
*   **On ML VMs:** Copy the `ml_pipeline` folder and `docker-compose.ml.yml`, then run `docker-compose up -d`.
*   **On Backend VM:** 
    *   Update `.env` with `ML_PIPELINE_URLS=http://<ML1_INTERNAL_IP>:8001,http://<ML2_INTERNAL_IP>:8001`.
    *   Deploy using `docker-compose.backend.yml`.

## Phase 3: Load Testing with Locust

1.  **Install Locust:** `pip install locust`
2.  **Run Test:**
    ```bash
    locust -f tests/locustfile.py --host=http://35.193.246.44:8000
    ```
3.  **Analysis:** Open `http://localhost:8089` to view real-time metrics and verify that requests are being distributed across the ML instances.

## Phase 4: Final Verification
*   Check Firestore to ensure ML results are being stored correctly.
*   Verify the UI (built by C2) displays the processed results from the multi-VM backend.
