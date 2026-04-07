#!/bin/bash
# Day 5: GKE Deployment Script
# This script documents all commands used to deploy V2AI to GKE

set -e

PROJECT_ID="v2aicloud"
CLUSTER_NAME="v2ai-cluster"
REGION="us-central1"

echo "=== Day 5: GKE Deployment ==="
echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# Step 1: Enable APIs
echo "Step 1: Enable GKE and GCR APIs"
echo "Command: gcloud services enable container.googleapis.com containerregistry.googleapis.com --project=$PROJECT_ID"
echo "Output: Operation finished successfully"
echo ""

# Step 2: Configure Docker for GCR
echo "Step 2: Configure Docker for GCR"
echo "Command: gcloud auth configure-docker --quiet"
echo "Output: Docker configuration file updated"
echo ""

# Step 3: Tag and Push Images
echo "Step 3: Tag and Push Docker Images"
echo "Commands:"
echo "  docker tag v2ai-cloudnative-backend:latest gcr.io/$PROJECT_ID/v2ai-backend:latest"
echo "  docker tag v2ai-cloudnative-ml_pipeline:latest gcr.io/$PROJECT_ID/v2ai-ml-pipeline:latest"
echo "  docker push gcr.io/$PROJECT_ID/v2ai-backend:latest"
echo "  docker push gcr.io/$PROJECT_ID/v2ai-ml-pipeline:latest"
echo ""
echo "Verify with: gcloud container images list --project=$PROJECT_ID"
echo "Output:"
echo "  gcr.io/v2aicloud/v2ai-backend"
echo "  gcr.io/v2aicloud/v2ai-ml-pipeline"
echo ""

# Step 4: Create GKE Cluster
echo "Step 4: Create GKE Autopilot Cluster"
echo "Note: Standard clusters had stockout issues, so we used Autopilot"
echo "Command: gcloud container clusters create-auto $CLUSTER_NAME --project=$PROJECT_ID --region=$REGION"
echo "Output: kubeconfig entry generated for v2ai-cluster"
echo ""

# Step 5: Get Credentials
echo "Step 5: Configure kubectl"
echo "Command: gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID"
echo "Prerequisite: Install gke-gcloud-auth-plugin"
echo "  sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin"
echo ""

# Step 6: Deploy to Kubernetes
echo "Step 6: Deploy Application"
echo "Commands:"
echo "  kubectl apply -f k8s/namespace.yaml"
echo "  kubectl create secret generic gcp-credentials --from-file=gcp-key.json=./gcp-key.json -n v2ai"
echo "  kubectl apply -f k8s/configmap.yaml"
echo "  kubectl apply -f k8s/backend-deployment.yaml"
echo "  kubectl apply -f k8s/ml-pipeline-deployment.yaml"
echo "  kubectl apply -f k8s/backend-service.yaml"
echo "  kubectl apply -f k8s/ml-pipeline-service.yaml"
echo "  kubectl apply -f k8s/hpa.yaml"
echo ""

# Step 7: Verify Deployment
echo "Step 7: Verify Deployment"
echo "Command: kubectl get all -n v2ai"
echo "Output:"
cat << 'EOF'
NAME                               READY   STATUS    RESTARTS   AGE
pod/v2ai-backend-xxx               1/1     Running   0          5m
pod/v2ai-backend-xxx               1/1     Running   0          5m
pod/v2ai-ml-pipeline-xxx           1/1     Running   0          5m
pod/v2ai-ml-pipeline-xxx           1/1     Running   0          5m

NAME                          TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)
service/ml-pipeline-service   ClusterIP      34.118.233.234   <none>           8001/TCP
service/v2ai-backend          LoadBalancer   34.118.234.214   35.222.254.140   80:32063/TCP

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/v2ai-backend       2/2     2            2           5m
deployment.apps/v2ai-ml-pipeline   2/2     2            2           5m
EOF
echo ""

# Step 8: Test Endpoints
echo "Step 8: Test Endpoints"
echo ""
echo "Health Check:"
echo "  curl http://35.222.254.140/health"
echo "  Output: {\"status\":\"ok\"}"
echo ""
echo "Upload Video:"
echo "  curl -X POST http://35.222.254.140/upload -F 'file=@lecture.mp4'"
echo "  Output:"
cat << 'EOF'
{
  "file_id": "1f132bad-d953-6fdc-84a8-8d101c3e6c8f",
  "filename": "lecture.mp4",
  "message": "Video uploaded. ML pipeline processing started in background.",
  "status": "queued"
}
EOF
echo ""
echo "Check Status:"
echo "  curl http://35.222.254.140/status/{file_id}"
echo "  Output after ~150s:"
cat << 'EOF'
{
  "file_id": "1f132bad-d953-6fdc-84a8-8d101c3e6c8f",
  "status": "processed",
  "ml_results": {
    "transcript": { "status": "success" },
    "summary": { "status": "success" },
    "questions": { "status": "success", "count": 3 }
  }
}
EOF
echo ""

echo "=== Deployment Complete ==="
echo "GKE External IP: 35.222.254.140"
echo "Processing Time: ~150 seconds per video"
