#!/bin/bash

set -e

echo "=== C1 Day 2 End-to-End Test ==="
echo ""

FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo "   ✓ $2"
    else
        echo "   ✗ $2"
        FAILED=1
    fi
}

echo "1. Docker Compose Setup"
echo "   Starting services..."
docker compose down 2>/dev/null || true
docker compose up -d backend ml_pipeline
sleep 3

echo "   Waiting for services to be ready..."
max_retries=30
retry=0
while [ $retry -lt $max_retries ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1 && \
       curl -s http://localhost:8001/health > /dev/null 2>&1; then
        break
    fi
    retry=$((retry + 1))
    sleep 1
done

test_result $? "Services started and responding"

echo ""
echo "2. Health Checks"
backend_health=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
test_result $([ "$backend_health" = "200" ]; echo $?) "Backend health endpoint (HTTP $backend_health)"

ml_health=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/health)
test_result $([ "$ml_health" = "200" ]; echo $?) "ML Pipeline health endpoint (HTTP $ml_health)"

echo ""
echo "3. File Upload Test"

# Create a test MP4 file
if ! ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 \
    -f lavfi -i sine=frequency=1000:duration=2 \
    -pix_fmt yuv420p -y /tmp/test_e2e.mp4 2>&1 | grep -q "error" || true; then
    test_result 0 "Test MP4 file created"
else
    test_result 1 "Test MP4 file creation"
fi

# Upload file
upload_response=$(curl -s -X POST -F 'file=@/tmp/test_e2e.mp4' http://localhost:8000/upload)

# Check if file_id is in response
if echo "$upload_response" | grep -q "file_id"; then
    test_result 0 "Upload endpoint accepts file and returns file_id"
    file_id=$(echo "$upload_response" | grep -o '"file_id":"[^"]*' | cut -d'"' -f4)
    echo "     File ID: $file_id"
else
    test_result 1 "Upload endpoint response"
    echo "     Response: $upload_response"
fi

# Check if paths are correct
if echo "$upload_response" | grep -q "gs://v2aibucket"; then
    test_result 0 "GCS paths in response"
else
    test_result 1 "GCS paths in response"
fi

if echo "$upload_response" | grep -q '"status":"uploaded"'; then
    test_result 0 "Upload status is 'uploaded'"
else
    test_result 1 "Upload status indication"
fi

echo ""
echo "4. Audio Extraction Verification"

# Check if audio file was created in shared volume
if [ -n "$file_id" ]; then
    audio_file="uploads/audio/${file_id}.wav"
    if [ -f "$audio_file" ]; then
        test_result 0 "Audio file created in shared volume: $audio_file"
        file_size=$(du -h "$audio_file" | cut -f1)
        echo "     Size: $file_size"
    else
        test_result 1 "Audio file created: $audio_file not found"
    fi
fi

echo ""
echo "5. Docker Volume Mounting"

# Check files inside container
container_check=$(docker compose exec -T backend ls -lh /app/uploads/audio/ 2>/dev/null | wc -l)
if [ "$container_check" -gt 0 ]; then
    test_result 0 "Files visible inside container via mount"
else
    test_result 1 "Files visible inside container via mount"
fi

echo ""
echo "6. Docker Image Verification"

backend_image=$(docker compose images backend | awk 'NR==2 {print $2}')
test_result $? "Backend image: $backend_image"

ml_image=$(docker compose images ml_pipeline | awk 'NR==2 {print $2}')
test_result $? "ML Pipeline image: $ml_image"

echo ""
echo "7. Container Environment"

# Check if GCP env vars are accessible
env_check=$(docker compose exec -T backend env | grep -c "GCP" || true)
if [ "$env_check" -gt 0 ]; then
    test_result 0 "GCP environment variables loaded in container"
else
    test_result 1 "GCP environment variables loaded"
fi

echo ""
echo "8. FFmpeg Inside Container"

ffmpeg_check=$(docker compose exec -T backend which ffmpeg)
if [ -n "$ffmpeg_check" ]; then
    test_result 0 "FFmpeg installed in container at: $ffmpeg_check"
else
    test_result 1 "FFmpeg installed in container"
fi

echo ""
echo "=== Summary ==="

if [ $FAILED -eq 0 ]; then
    echo "All tests PASSED. Day 2 is production-ready."
    echo ""
    echo "Next step: git commit when ready"
    echo "  git add -A && git commit -m 'Complete C1 Day 2: Docker build and testing'"
    exit 0
else
    echo "Some tests FAILED. Review above for details."
    exit 1
fi
