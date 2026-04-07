#!/bin/bash
# Setup GCP IAM permissions for C2 and C3
# Run this as project owner (C1 - sujiv)

set -e

PROJECT_ID="${GCP_PROJECT_ID:-v2aicloud}"

echo "=== V2AI GCP Permissions Setup ==="
echo "Project: $PROJECT_ID"
echo ""

# Check if emails are provided
if [ -z "$C2_EMAIL" ] || [ -z "$C3_EMAIL" ]; then
    echo "Usage:"
    echo "  C2_EMAIL=sagnik@email.com C3_EMAIL=harshil@email.com ./scripts/setup-gcp-permissions.sh"
    echo ""
    read -p "Enter C2 (Sagnik) email: " C2_EMAIL
    read -p "Enter C3 (Harshil) email: " C3_EMAIL
fi

echo ""
echo "=== Granting permissions to C2 ($C2_EMAIL) ==="

# C2 needs Firestore access and basic viewer access
echo "Adding roles/datastore.user..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C2_EMAIL" \
  --role="roles/datastore.user" \
  --quiet

echo "Adding roles/storage.objectViewer..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C2_EMAIL" \
  --role="roles/storage.objectViewer" \
  --quiet

echo "Adding roles/compute.viewer..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C2_EMAIL" \
  --role="roles/compute.viewer" \
  --quiet

echo "[OK] C2 permissions granted"

echo ""
echo "=== Granting permissions to C3 ($C3_EMAIL) ==="

# C3 needs full VM and networking access
echo "Adding roles/compute.instanceAdmin.v1..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C3_EMAIL" \
  --role="roles/compute.instanceAdmin.v1" \
  --quiet

echo "Adding roles/compute.networkAdmin..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C3_EMAIL" \
  --role="roles/compute.networkAdmin" \
  --quiet

echo "Adding roles/storage.objectViewer..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C3_EMAIL" \
  --role="roles/storage.objectViewer" \
  --quiet

echo "Adding roles/datastore.viewer..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$C3_EMAIL" \
  --role="roles/datastore.viewer" \
  --quiet

echo "[OK] C3 permissions granted"

echo ""
echo "=== Permissions Summary ==="
echo ""
echo "C2 ($C2_EMAIL):"
echo "  - roles/datastore.user (read/write Firestore)"
echo "  - roles/storage.objectViewer (view GCS)"
echo "  - roles/compute.viewer (view VMs)"
echo ""
echo "C3 ($C3_EMAIL):"
echo "  - roles/compute.instanceAdmin.v1 (manage VMs)"
echo "  - roles/compute.networkAdmin (manage firewall)"
echo "  - roles/storage.objectViewer (view GCS)"
echo "  - roles/datastore.viewer (view Firestore)"
echo ""
echo "=== Files to Share ==="
echo ""
echo "Send these files to C2 and C3 via SECURE channel (not email/git):"
echo "  1. gcp-key.json - Service account credentials"
echo "  2. .env - Environment variables"
echo ""
echo "=== Done ==="
