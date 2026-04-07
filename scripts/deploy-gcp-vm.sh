#!/bin/bash
# Day 4 GCP VM Deployment Script
# Usage: ./scripts/deploy-gcp-vm.sh

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-v2aicloud}"
ZONE="${GCP_ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-v2ai-vm-1}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-medium}"
DISK_SIZE="${DISK_SIZE:-30GB}"

echo "=== V2AI Day 4 GCP VM Deployment ==="
echo "Project: $PROJECT_ID"
echo "Zone: $ZONE"
echo "VM: $VM_NAME"
echo ""

# Check gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 > /dev/null; then
    echo "[ERROR] gcloud not authenticated. Run: gcloud auth login"
    exit 1
fi

# Step 1: Create VM
echo "=== Step 1: Creating VM Instance ==="
if gcloud compute instances describe "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" &>/dev/null; then
    echo "[SKIP] VM $VM_NAME already exists"
else
    gcloud compute instances create "$VM_NAME" \
        --project="$PROJECT_ID" \
        --zone="$ZONE" \
        --machine-type="$MACHINE_TYPE" \
        --boot-disk-size="$DISK_SIZE" \
        --image-family=ubuntu-2204-lts \
        --image-project=ubuntu-os-cloud \
        --tags=v2ai-server
    echo "[OK] VM created"
fi

# Step 2: Create Firewall Rule
echo ""
echo "=== Step 2: Creating Firewall Rule ==="
if gcloud compute firewall-rules describe v2ai-allow-http --project="$PROJECT_ID" &>/dev/null; then
    echo "[SKIP] Firewall rule already exists"
else
    gcloud compute firewall-rules create v2ai-allow-http \
        --project="$PROJECT_ID" \
        --allow=tcp:8000,tcp:8001,tcp:9090 \
        --target-tags=v2ai-server \
        --description="Allow HTTP traffic for V2AI services"
    echo "[OK] Firewall rule created"
fi

# Get VM IP
VM_IP=$(gcloud compute instances describe "$VM_NAME" \
    --project="$PROJECT_ID" --zone="$ZONE" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo ""
echo "VM External IP: $VM_IP"

# Step 3: Install Docker on VM
echo ""
echo "=== Step 3: Installing Docker on VM ==="
gcloud compute ssh "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" --command="
    if command -v docker &>/dev/null; then
        echo '[SKIP] Docker already installed'
        docker --version
    else
        echo 'Installing Docker...'
        curl -fsSL https://get.docker.com | sudo sh
        echo '[OK] Docker installed'
        docker --version
    fi
"

# Step 4: Install Docker Compose
echo ""
echo "=== Step 4: Installing Docker Compose ==="
gcloud compute ssh "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" --command="
    if command -v docker-compose &>/dev/null; then
        echo '[SKIP] Docker Compose already installed'
        docker-compose --version
    else
        echo 'Installing Docker Compose...'
        sudo curl -L 'https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64' \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo '[OK] Docker Compose installed'
        docker-compose --version
    fi
"

# Step 5: Create directory on VM
echo ""
echo "=== Step 5: Creating project directory ==="
gcloud compute ssh "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" --command="
    mkdir -p ~/V2AI-CloudNative/monitoring
"

# Step 6: Copy files to VM
echo ""
echo "=== Step 6: Copying project files to VM ==="
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check required files exist
for file in backend ml_pipeline docker-compose.yml .env gcp-key.json; do
    if [ ! -e "$PROJECT_ROOT/$file" ]; then
        echo "[ERROR] Required file/directory not found: $PROJECT_ROOT/$file"
        exit 1
    fi
done

gcloud compute scp --recurse --project="$PROJECT_ID" --zone="$ZONE" \
    "$PROJECT_ROOT/backend" \
    "$PROJECT_ROOT/ml_pipeline" \
    "$PROJECT_ROOT/docker-compose.yml" \
    "$PROJECT_ROOT/.env" \
    "$PROJECT_ROOT/gcp-key.json" \
    "$VM_NAME:~/V2AI-CloudNative/"

echo "[OK] Files copied"

# Step 7: Create Prometheus config
echo ""
echo "=== Step 7: Creating Prometheus config ==="
gcloud compute ssh "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" --command="
cat > ~/V2AI-CloudNative/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: [\"localhost:9090\"]
  - job_name: backend
    static_configs:
      - targets: [\"backend:8000\"]
  - job_name: ml_pipeline
    static_configs:
      - targets: [\"ml_pipeline:8001\"]
EOF
echo '[OK] Prometheus config created'
"

# Step 8: Build and start containers
echo ""
echo "=== Step 8: Building and starting containers ==="
gcloud compute ssh "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" --command="
    cd ~/V2AI-CloudNative
    sudo docker-compose up -d --build
"

# Wait for containers to start
echo ""
echo "Waiting 30s for containers to initialize..."
sleep 30

# Step 9: Verify deployment
echo ""
echo "=== Step 9: Verifying deployment ==="
gcloud compute ssh "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" --command="
    cd ~/V2AI-CloudNative
    sudo docker-compose ps
"

# Step 10: Test health endpoints
echo ""
echo "=== Step 10: Testing health endpoints ==="
echo "Testing backend (http://$VM_IP:8000/health)..."
BACKEND_HEALTH=$(curl -s --connect-timeout 10 "http://$VM_IP:8000/health" || echo "FAILED")
echo "Backend: $BACKEND_HEALTH"

echo "Testing ML pipeline (http://$VM_IP:8001/health)..."
ML_HEALTH=$(curl -s --connect-timeout 10 "http://$VM_IP:8001/health" || echo "FAILED")
echo "ML Pipeline: $ML_HEALTH"

# Summary
echo ""
echo "=========================================="
echo "      DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "VM Name:     $VM_NAME"
echo "External IP: $VM_IP"
echo ""
echo "Endpoints:"
echo "  Backend:     http://$VM_IP:8000"
echo "  ML Pipeline: http://$VM_IP:8001"
echo "  Prometheus:  http://$VM_IP:9090"
echo ""
echo "Test commands:"
echo "  curl http://$VM_IP:8000/health"
echo "  curl -X POST -F 'file=@video.mp4' http://$VM_IP:8000/upload"
echo ""
echo "SSH into VM:"
echo "  gcloud compute ssh $VM_NAME --project=$PROJECT_ID --zone=$ZONE"
echo ""
echo "View logs:"
echo "  gcloud compute ssh $VM_NAME --project=$PROJECT_ID --zone=$ZONE --command='cd ~/V2AI-CloudNative && sudo docker-compose logs -f'"
echo ""
