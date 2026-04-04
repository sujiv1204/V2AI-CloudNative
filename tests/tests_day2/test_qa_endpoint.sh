#!/bin/bash

# Test the /qa endpoint using curl
echo "Testing /qa endpoint..."
RESPONSE=$(curl -s -X POST "http://localhost:8000/qa" \
     -H "Content-Type: application/json" \
     -d '{"context": "The T5 model is a unified framework that converts all text-based language problems into a text-to-text format."}')

echo "Response from API:"
echo $RESPONSE | jq . 2>/dev/null || echo $RESPONSE
