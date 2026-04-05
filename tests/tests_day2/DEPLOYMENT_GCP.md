# Deployment Guide for V2AI CloudNative (GCP)

This guide provides instructions for deploying the V2AI services on a Google Cloud Platform (GCP) Virtual Machine.

---

## 1. Prepare Docker on VM
Repeat these steps on your VMs (e.g., Ubuntu 22.04).

**Update and install Docker:**
```bash
sudo apt update
sudo apt install -y docker.io docker-compose
```

**Start and enable Docker:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**Allow your user to run Docker without sudo (Optional):**
```bash
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

## 2. Deploy on VM
**Transfer your code:**
- **Simple way (Git):** `git clone <your-repo-url>`
- **Manual way (SCP):** `scp -r ./tests/tests_day2 user@<VM_IP>:~/tests_day2`

**Start Services:**
```bash
cd ~/tests_day2
docker-compose up -d --build
```

## 3. Validate Services Across VMs
**Task: Test API communication (VM-to-VM)**
Suppose you have VM-A (running the API) and VM-B (the client).

1. On VM-A, find its internal IP: `hostname -I` (e.g., 10.0.0.5)
2. On VM-B, try to ping VM-A: `ping 10.0.0.5`
3. On VM-B, run a curl request targeting VM-A's IP:
```bash
curl -X POST http://10.0.0.5:8000/qa \
     -H "Content-Type: application/json" \
     -d '{"context": "The Eiffel Tower is in Paris."}'
```

## 4. Verify External Access (Public IP)
### Step A: Configure Firewall
On your Cloud Provider (AWS, GCP, Azure, etc.):
1. Locate "Security Groups" or "Firewall Rules."
2. Add an Inbound Rule to allow TCP Port 8000 for the API.
3. Add an Inbound Rule to allow TCP Port 8081 for Redis Commander.

### Step B: Test with Public IP
From your local machine (Laptop):
1. Find the VM's Public IP (from the cloud console).
2. Open your browser to: `http://<PUBLIC_IP>:8000/` (Should see the "running" message).
3. Open your browser to: `http://<PUBLIC_IP>:8081/` (Should see Redis Commander).

### Step C: Curl from local terminal
```bash
curl -X POST http://<PUBLIC_IP>:8000/qa \
     -H "Content-Type: application/json" \
     -d '{"context": "Deepmind is located in London."}'
```

---

## 5. Google Cloud Platform (GCP) VM Setup Instructions
This section explains how to set up the GCP environment to perform the steps above.

### Step 1: Create a VM Instance
1. Go to the [GCP Console](https://console.cloud.google.com/).
2. In the search bar, type **Compute Engine** and select it.
3. Click **CREATE INSTANCE**.
4. **Name**: `v2ai-instance`
5. **Region/Zone**: Choose the one closest to you (e.g., `us-central1`).
6. **Machine configuration**: 
   - **Machine family**: General-purpose
   - **Series**: `E2`
   - **Machine type**: `e2-medium` (2 vCPU, 4GB RAM) — *This is recommended for running the T5 model efficiently.*
7. **Boot disk**: 
   - Click **CHANGE**.
   - **Operating System**: Ubuntu
   - **Version**: Ubuntu 22.04 LTS
   - **Size**: 20 GB (Standard persistent disk is fine).
   - Click **SELECT**.
8. **Firewall**: 
   - Check **Allow HTTP traffic**.
   - Check **Allow HTTPS traffic**.
9. Click **CREATE**.

### Step 2: Configure Firewall Rules for Ports 8000 and 8081
By default, GCP blocks custom ports. You must explicitly allow them.
1. In the search bar, type **VPC network** and select **Firewall**.
2. Click **CREATE FIREWALL RULE**.
3. **Name**: `v2ai-allow-api-ports`
4. **Targets**: All instances in the network (or use a Target tag if you assigned one to your VM).
5. **Source IPv4 ranges**: `0.0.0.0/0` (Allows access from anywhere—use your local IP for better security).
6. **Protocols and ports**: 
   - Check **Specified protocols and ports**.
   - Check **TCP** and enter: `8000, 8081`.
7. Click **CREATE**.

### Step 3: Access your VM via SSH
1. Go back to **Compute Engine > VM instances**.
2. In the row for your instance, click the **SSH** button.
3. A browser-based terminal will open. You can now start with **Section 1 (Prepare Docker on VM)** above.

### Step 4: Find your Public and Internal IPs
- **Internal IP**: Needed for VM-to-VM communication (Section 3). Found in the **Internal IP** column on the VM instances page.
- **External (Public) IP**: Needed for testing from your local machine (Section 4). Found in the **External IP** column.
