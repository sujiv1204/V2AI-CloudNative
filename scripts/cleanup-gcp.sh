#!/bin/bash
# V2AI Cleanup Script - Clears GCP buckets, Firestore, and local uploads
# Usage: ./scripts/cleanup-gcp.sh [--all|--local|--gcs|--firestore]

set -e

PROJECT_ID="${GCP_PROJECT_ID:-241955658779}"
BUCKET_NAME="${GCS_BUCKET_NAME:-v2aibucket}"
FIRESTORE_DB="${FIRESTORE_DB_NAME:-v2aidb}"
COLLECTION="${FIRESTORE_COLLECTION:-videos}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup_local() {
    echo "=== Cleaning Local Uploads ==="
    if [ -d "uploads" ]; then
        rm -rf uploads/*
        mkdir -p uploads/audio
        print_status "Cleared uploads/ directory"
    else
        print_warn "uploads/ directory not found"
    fi
}

cleanup_gcs() {
    echo "=== Cleaning GCS Bucket ==="
    
    if ! command -v gsutil &> /dev/null; then
        print_error "gsutil not found. Install Google Cloud SDK."
        return 1
    fi

    echo "Clearing gs://${BUCKET_NAME}/videos/..."
    gsutil -m rm -r "gs://${BUCKET_NAME}/videos/**" 2>/dev/null || print_warn "No videos to delete"
    
    echo "Clearing gs://${BUCKET_NAME}/audio/..."
    gsutil -m rm -r "gs://${BUCKET_NAME}/audio/**" 2>/dev/null || print_warn "No audio to delete"
    
    print_status "GCS bucket cleaned"
}

cleanup_firestore() {
    echo "=== Cleaning Firestore Collection ==="
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud not found. Install Google Cloud SDK."
        return 1
    fi

    echo "Deleting collection '${COLLECTION}' from database '${FIRESTORE_DB}'..."
    
    # Use Python script with google-cloud-firestore
    python3 -c "
from google.cloud import firestore
import os
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = 'gcp-key.json'
db = firestore.Client(project='${PROJECT_ID}', database='${FIRESTORE_DB}')
docs = db.collection('${COLLECTION}').stream()
deleted = 0
for doc in docs:
    doc.reference.delete()
    deleted += 1
print(f'Deleted {deleted} documents from Firestore')
" 2>/dev/null || print_warn "Firestore cleanup requires gcp-key.json or manual deletion"
    
    print_status "Firestore collection cleaned"
}

show_usage() {
    echo "V2AI Cleanup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all        Clean everything (local + GCS + Firestore)"
    echo "  --local      Clean local uploads only"
    echo "  --gcs        Clean GCS bucket only"
    echo "  --firestore  Clean Firestore collection only"
    echo "  --help       Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID     GCP project ID (default: 241955658779)"
    echo "  GCS_BUCKET_NAME    GCS bucket name (default: v2aibucket)"
    echo "  FIRESTORE_DB_NAME  Firestore database (default: v2aidb)"
    echo "  FIRESTORE_COLLECTION  Collection name (default: videos)"
}

# Main
case "${1:-}" in
    --all)
        cleanup_local
        cleanup_gcs
        cleanup_firestore
        echo ""
        print_status "All cleanup complete!"
        echo "NOTE: Restart containers after cleanup: docker compose restart"
        ;;
    --local)
        cleanup_local
        ;;
    --gcs)
        cleanup_gcs
        ;;
    --firestore)
        cleanup_firestore
        ;;
    --help|-h)
        show_usage
        ;;
    "")
        echo "Running full cleanup (--all)..."
        echo ""
        cleanup_local
        cleanup_gcs
        cleanup_firestore
        echo ""
        print_status "All cleanup complete!"
        echo "NOTE: Restart containers after cleanup: docker compose restart"
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
