# GKE Deployment Benchmark Results (C1)

## Summary

C1 tasks for GKE monitoring and load testing were completed on cluster `v2ai-cluster` (regional: `us-central1`), with Prometheus/Grafana running in namespace `monitoring`, app workloads running in namespace `v2ai`, and Locust benchmarks executed against the GKE LoadBalancer backend endpoint.

---

## How Prometheus and Grafana Were Set Up on GKE

### 1) Connect to the correct (regional) GKE cluster

```bash
gcloud container clusters get-credentials v2ai-cluster --region=us-central1 --project=v2aicloud
kubectl get ns --request-timeout=20s
```

### 2) Add/update Helm repo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 3) Install/upgrade kube-prometheus-stack with GKE Autopilot-safe values

`kube-prometheus-stack` defaults are not fully Autopilot-safe. These flags were used to avoid blocked components:

```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set defaultRules.rules.kubeControllerManager=false \
  --set defaultRules.rules.kubeProxy=false \
  --set defaultRules.rules.kubeSchedulerAlerting=false \
  --set defaultRules.rules.kubeSchedulerRecording=false \
  --set defaultRules.rules.kubeEtcd=false \
  --set defaultRules.rules.nodeExporterAlerting=false \
  --set defaultRules.rules.nodeExporterRecording=false \
  --set kubeControllerManager.enabled=false \
  --set kubeEtcd.enabled=false \
  --set kubeScheduler.enabled=false \
  --set kubeProxy.enabled=false \
  --set kubeDns.enabled=false \
  --set coreDns.enabled=false \
  --set prometheus-node-exporter.enabled=false \
  --set nodeExporter.enabled=false \
  --set prometheusOperator.admissionWebhooks.enabled=false \
  --set prometheusOperator.admissionWebhooks.patch.enabled=false
```

### 4) Verify stack health

```bash
helm status prometheus -n monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Expected: Helm status `deployed`, Prometheus operator/state-metrics/Prometheus/Grafana pods running.

### 5) Access Grafana and Prometheus locally

```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 19090:9090
```

Open:

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:19090`

### 6) Get Grafana login credentials

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

---

## Environment and Access Validation

### Cluster Context and Reachability

```bash
gcloud container clusters get-credentials v2ai-cluster --region=us-central1 --project=v2aicloud
kubectl get ns --request-timeout=20s
```

Result: kubeconfig refreshed and API reachable; namespaces include `monitoring` and `v2ai`.

### Monitoring Port-Forward Access (Validated)

```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 19090:9090
```

Result:

- Grafana reachable on `http://localhost:3000`
- Prometheus reachable on `http://localhost:19090`
- Active connection handling confirmed in both forwards.

### Grafana Credentials

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Result: admin user/password successfully retrieved from Kubernetes secret.

---

## Application and E2E Status on GKE

### Backend External Endpoint

`http://35.222.254.140`

### Health Check

`GET /health` returned:

```json
{"status":"ok"}
```

### End-to-End Pipeline Test

Executed against GKE backend using `test-integration.sh` with `BACKEND_URL=http://35.222.254.140`.

Observed result:

- Upload accepted and `file_id` returned
- Status progressed to `processed`
- `transcript`, `summary`, and `questions` all returned `status: "success"`
- End-to-end script completed with success.

---

## Monitoring Stack Status

### Helm Release

- Release: `prometheus`
- Namespace: `monitoring`
- Final status: `deployed`

### Runtime Components

Healthy components observed:

- `prometheus-kube-prometheus-operator`
- `prometheus-kube-state-metrics`
- `prometheus-prometheus-kube-prometheus-prometheus-0`
- `alertmanager-prometheus-kube-prometheus-alertmanager-0`
- `prometheus-grafana` (running serving pod)

Note: On GKE Autopilot, some default kube-prometheus-stack options required disabling (node-exporter / managed-control-plane scraping / admission patch behavior) to stay compatible with Autopilot constraints.

---

## Locust Benchmark Runs Against GKE

## 1) Health-Focused Run (`results/gke_*.csv`)

Command used:

```bash
GKE_IP=$(kubectl get svc v2ai-backend -n v2ai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
venv/bin/python -m locust -f tests/locustfile.py --host=http://$GKE_IP --users=20 --spawn-rate=5 --run-time=120s --headless --csv=results/gke
```

Aggregated output (`results/gke_stats.csv`):

- Request Count: **95**
- Failure Count: **3**
- Requests/sec: **1.3609**
- Average Response Time: **573.63 ms**
- p95: **880 ms**
- p99: **1500 ms**

## 2) End-to-End Traffic Mix Run (`results/gke-e2e_*.csv`)

A local `test_video.mp4` was present to enable `/upload` workload generation.

Command used:

```bash
GKE_IP=$(kubectl get svc v2ai-backend -n v2ai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
venv/bin/python -m locust -f tests/locustfile.py --host=http://$GKE_IP --users=12 --spawn-rate=3 --run-time=90s --headless --csv=results/gke-e2e
```

Aggregated output (`results/gke-e2e_stats.csv`):

- Request Count: **274**
- Failure Count: **2**
- Requests/sec: **3.0918**
- Average Response Time: **1787.23 ms**
- p95: **5000 ms**
- p99: **7700 ms**

Endpoint-level breakdown:

- `GET /health`: 153 req, 1 fail, avg 1241.73 ms
- `GET /status/[file_id]`: 88 req, 0 fail, avg 1798.75 ms
- `POST /upload`: 33 req, 1 fail, avg 4285.60 ms

Failure samples:

- `RemoteDisconnected('Remote end closed connection without response')`
- One upload catch-response failure under load

---

## Grafana Dashboards to Use (Recommended)

Use these first from **Dashboards → Browse**:

1. **Kubernetes / Compute Resources / Pod**  
   Track CPU and memory for `v2ai-backend-*` and `v2ai-ml-pipeline-*`.

2. **Kubernetes / Compute Resources / Namespace (Pods)**  
   Filter namespace `v2ai` to see aggregate workload pressure.

3. **Kubernetes / Compute Resources / Cluster**  
   Node and cluster-wide utilization during Locust runs.

4. **Kubernetes / Networking / Namespace (Workload)**  
   Throughput/traffic behavior for backend service in `v2ai`.

5. **Kubernetes / API server** (optional)  
   Useful if you want cluster control-plane/API stress visibility.

For autoscaling correlation, keep this in a parallel terminal while load runs:

```bash
kubectl get hpa -n v2ai -w
kubectl get pods -n v2ai -w
```

---

## Deliverables Produced

- Monitoring stack running in `monitoring` namespace
- Verified Grafana and Prometheus local access via port-forward
- E2E GKE pipeline success evidence
- Locust result artifacts:
  - `results/gke_stats.csv`
  - `results/gke_failures.csv`
  - `results/gke_stats_history.csv`
  - `results/gke-e2e_stats.csv`
  - `results/gke-e2e_failures.csv`
  - `results/gke-e2e_exceptions.csv`
  - `results/gke-e2e_stats_history.csv`
