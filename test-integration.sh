#!/bin/bash

# Integration test script for V2AI Cloud-Native pipeline
# Uploads lecture.mp4, polls status, validates all stages

set -e

BACKEND_URL="${BACKEND_URL:-http://35.222.254.140}"
VIDEO_FILE="${VIDEO_FILE:-lecture.mp4}"
MAX_WAIT=300
POLL_INTERVAL=10

echo "=== V2AI Integration Test ==="
echo "Backend URL: $BACKEND_URL"
echo "Video file: $VIDEO_FILE"

if [ ! -f "$VIDEO_FILE" ]; then
    echo "ERROR: Video file not found: $VIDEO_FILE"
    exit 1
fi

echo ""
echo "Uploading video..."
UPLOAD_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/upload" \
    -F "file=@${VIDEO_FILE}" \
    -H "accept: application/json")

echo "Upload response: $UPLOAD_RESPONSE"

FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.file_id // .id // empty')
if [ -z "$FILE_ID" ]; then
    echo "ERROR: Could not extract file_id from upload response"
    exit 1
fi

echo "File ID: $FILE_ID"
echo ""
echo "Polling status (max ${MAX_WAIT}s)..."

ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS_RESPONSE=$(curl -s "${BACKEND_URL}/status/${FILE_ID}")
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // "unknown"')
    
    echo "[$ELAPSED s] Status: $STATUS"
    
    if [ "$STATUS" = "completed" ] || [ "$STATUS" = "processed" ]; then
        echo ""
        echo "=== Pipeline Completed ==="
        echo "$STATUS_RESPONSE" | jq '.'
        
        # Validate all stages
        TRANSCRIPT=$(echo "$STATUS_RESPONSE" | jq -r '.ml_results.transcript.status // "missing"')
        SUMMARY=$(echo "$STATUS_RESPONSE" | jq -r '.ml_results.summary.status // "missing"')
        QA=$(echo "$STATUS_RESPONSE" | jq -r '.ml_results.questions.status // "missing"')
        
        echo ""
        echo "=== Stage Validation ==="
        echo "Transcript: $TRANSCRIPT"
        echo "Summary: $SUMMARY"
        echo "QA: $QA"
        
        if [ "$TRANSCRIPT" = "success" ] && [ "$SUMMARY" = "success" ] && [ "$QA" = "success" ]; then
            echo ""
            echo "SUCCESS: All pipeline stages completed successfully"
            exit 0
        else
            echo ""
            echo "WARNING: Some stages did not complete successfully"
            exit 1
        fi
    elif [ "$STATUS" = "failed" ]; then
        echo ""
        echo "ERROR: Pipeline failed"
        echo "$STATUS_RESPONSE" | jq '.'
        exit 1
    fi
    
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo ""
echo "ERROR: Timeout waiting for pipeline to complete"
exit 1
