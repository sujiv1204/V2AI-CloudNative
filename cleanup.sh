#!/bin/bash

echo "=== Cleaning up test files ==="
echo ""

echo "1. Local files:"
if [ -d "uploads" ]; then
    rm -rf uploads/*
    mkdir -p uploads/audio
    echo "   ✓ Cleared uploads/ directory"
else
    echo "   ✗ uploads/ not found"
fi

echo ""
echo "2. Docker volumes:"
docker compose down -v 2>/dev/null || true
echo "   ✓ Stopped containers and removed volumes"

echo ""
echo "3. GCS cleanup:"
if command -v gcloud &> /dev/null; then
    echo "   Deleting videos..."
    gcloud storage rm --recursive gs://v2aibucket/videos/ 2>/dev/null || true
    echo "   ✓ Deleted gs://v2aibucket/videos/"

    echo "   Deleting audio..."
    gcloud storage rm --recursive gs://v2aibucket/audio/ 2>/dev/null || true
    echo "   ✓ Deleted gs://v2aibucket/audio/"
else
    echo "    gcloud not found, run manually:"
    echo "   gcloud storage rm --recursive gs://v2aibucket/videos/"
    echo "   gcloud storage rm --recursive gs://v2aibucket/audio/"
fi

echo ""
echo "4. Firestore cleanup:"
echo "    Run manually in GCP Console:"
echo "   Firestore → v2aidb → videos → select all → delete"

echo ""
echo "=== Cleanup complete ==="

