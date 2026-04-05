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
echo "3. GCS cleanup (requires gsutil and correct key):"
echo "   Run manually if needed:"
echo "   gsutil -m rm -r gs://v2aibucket/videos/*"
echo "   gsutil -m rm -r gs://v2aibucket/audio/*"

echo ""
echo "4. Firestore cleanup (requires GCP Console):"
echo "   GCP Console → Firestore → v2aidb → videos → select all → delete"

echo ""
echo "=== Cleanup complete ==="
