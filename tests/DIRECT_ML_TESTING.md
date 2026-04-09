# Direct ML Pipeline Load Testing Guide

This guide provides the necessary commands and steps to perform direct load testing on the ML Pipeline instances, bypassing the Backend API.

## Prerequisites

1.  **ML Instance IPs**: You must have the internal or external IPs of your ML Pipeline instances (e.g., `v2ai-ml-1`, `v2ai-ml-2`).
2.  **Locust Installed**: Ensure Locust is installed in your environment:
    ```bash
    pip install locust
    ```

## Step-by-Step Instructions

### Step 1: Navigate to the Project Root
Open your terminal and ensure you are in the root directory of the project:
```bash
cd /home/harshil/Documents/vcc/vcc-project-final/V2AI-CloudNative
```

### Step 2: Target a Specific ML Instance
To benchmark a single ML instance directly, run the following command. Replace `<ML_IP>` with the actual IP of the ML instance:

```bash
# Run against port 8001
locust -f tests/ml_locustfile.py --host=http://<ML_IP>:8001
```

### Step 3: Target the ML Load Balancer (Internal)
If you want to test how the system behaves when targeting the group of ML VMs via an internal load balancer or Service IP (in K8s), use:

```bash
locust -f tests/ml_locustfile.py --host=http://<ML_SERVICE_IP>:8001
```

### Step 4: Running in Headless Mode
For automated benchmarking without the UI, use the following template:

```bash
# -u: number of users, -r: spawn rate, -t: run time
locust -f tests/ml_locustfile.py --host=http://<ML_IP>:8001 --headless -u 10 -r 2 -t 5m
```

## Summary of Commands

| Context | Command Location | Exact Command |
|---------|------------------|---------------|
| Direct ML-1 Test | Local / Testing VM | `locust -f tests/ml_locustfile.py --host=http://<ML1_IP>:8001` |
| Direct ML-2 Test | Local / Testing VM | `locust -f tests/ml_locustfile.py --host=http://<ML2_IP>:8001` |
| Headless Benchmarking | CLI | `locust -f tests/ml_locustfile.py --host=http://<ML1_IP>:8001 --headless -u 5 -r 1 -t 2m` |

## Key Differences from Backend Testing
- **Port**: ML Services run on **8001** (Backend runs on 8000).
- **Endpoints**: Direct testing hits `/health`, `/summarize`, `/qa`, and `/transcript` directly.
- **Payload**: The JSON structure must match exactly: `{"text": "your text here"}`.

> [!IMPORTANT]
> Ensure that your firewall rules allow traffic to port **8001** from the machine where you are running Locust.
