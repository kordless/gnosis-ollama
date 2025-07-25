#!/bin/bash
# Loads a specified model into the Gnosis Ollama Cloud Run service.

set -e

# --- Configuration ---
SERVICE_URL="https://gnosis-ollama-949870462453.us-central1.run.app"
MODEL_NAME=""

# --- Parse Command-Line Arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --model) MODEL_NAME="$2"; shift ;;
        --url) SERVICE_URL="$2"; shift ;;
        --help)
            echo "USAGE: ./load-model.sh --model <model_name> [--url <service_url>]"
            exit 0
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$MODEL_NAME" ]; then
    echo "Error: Model name is required."
    echo "USAGE: ./load-model.sh --model <model_name>"
    exit 1
fi

echo "=== Loading Model into Ollama Service ==="
echo "Service URL: $SERVICE_URL"
echo "Model to load: $MODEL_NAME"

# --- Trigger model pull ---
echo -e "\nTriggering pull for model: '$MODEL_NAME'. This may take several minutes..."
PULL_URI="${SERVICE_URL}/api/pull"
PAYLOAD="{\"name\":\"$MODEL_NAME\",\"stream\":false}"

# Use curl to send the request. The command will wait for the full download.
curl -s -X POST "$PULL_URI" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD"

# Check the exit code of curl
if [ $? -eq 0 ]; then
    echo -e "\n✓ Model '$MODEL_NAME' pull request sent successfully. It is now stored in the GCS bucket."
else
    echo -e "\n✗ Failed to pull model '$MODEL_NAME'."
    exit 1
fi

echo -e "\n=== Model Loading Complete ==="
