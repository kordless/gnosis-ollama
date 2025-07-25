#!/bin/bash
# Test script for the Gnosis Ollama Cloud Run service.

set -e

# --- Configuration ---
SERVICE_URL="https://gnosis-ollama-949870462453.us-central1.run.app"
MODEL_TO_TEST="llama3"

echo "=== Testing Ollama Service: $SERVICE_URL ==="

# --- 1. Check available models ---
echo -e "\n[1/2] Checking for available models at /api/tags..."
TAGS_URI="${SERVICE_URL}/api/tags"

# Use curl to get the list of models and check if the request was successful
MODEL_LIST=$(curl -s "$TAGS_URI")
if [ $? -ne 0 ]; then
    echo "✗ Failed to connect to the service at $SERVICE_URL."
    exit 1
fi

# A simple check to see if the response contains the "models" key
if [[ "$MODEL_LIST" == *"models"* ]]; then
    echo "✓ Success! Service is running. Available models:"
    # Use a simple grep/sed combo to list model names for basic parsing
    echo "$MODEL_LIST" | grep '"name"' | sed 's/.*"name": "\(.*\)".*/- \1/'
else
    echo "⚠ Service is running, but no models found or the response was unexpected."
fi

# --- 2. Test text generation ---
echo -e "\n[2/2] Sending test prompt to /api/generate with model '$MODEL_TO_TEST'..."
GENERATE_URI="${SERVICE_URL}/api/generate"
PAYLOAD="{\"model\":\"$MODEL_TO_TEST\",\"prompt\":\"Why is the sky blue?\",\"stream\":false}"

# Send the request and capture the response
GENERATION_RESPONSE=$(curl -s -X POST "$GENERATE_URI" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

if [ $? -ne 0 ]; then
    echo "✗ Failed to send generation request."
    exit 1
fi

# Check if the response contains the "response" key
if [[ "$GENERATION_RESPONSE" == *"response"* ]]; then
    echo "✓ Success! Model generated a response:"
    # A simple grep/sed to extract the response text
    echo "$GENERATION_RESPONSE" | sed -n 's/.*"response":"\([^"]*\)".*/\1/p' | sed 's/\\n/\n/g'
else
    echo "✗ The service responded, but the model failed to generate text."
    echo "Raw response: $GENERATION_RESPONSE"
fi

echo -e "\n=== Test Complete ==="
