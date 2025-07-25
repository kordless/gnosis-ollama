#!/bin/bash
# Gnosis Ollama Cloud Run Deployment Script (macOS/Linux)
# Builds and deploys the Ollama service to Cloud Run with a persistent GCS model cache.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Default Configuration ---
TAG="latest"
REBUILD_FLAG=""

# --- Parse Command-Line Arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --tag) TAG="$2"; shift ;;
        --rebuild) REBUILD_FLAG="--no-cache" ;;
        --help)
            echo "Gnosis Ollama Deployment Script"
            echo "USAGE: ./deploy-ollama.sh [--tag <tag>] [--rebuild]"
            exit 0
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- Project Configuration ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
IMAGE_NAME="gnosis-ollama"
DOCKERFILE="Dockerfile.ollama"

echo "=== Gnosis Ollama Deployment ==="
echo "Image: ${IMAGE_NAME}:${TAG}"

# --- Validate Configuration ---
if [ ! -f "${SCRIPT_DIR}/${DOCKERFILE}" ]; then
    echo "ERROR: Dockerfile not found: ${SCRIPT_DIR}/${DOCKERFILE}"
    exit 1
fi

# --- Load Cloud Run Environment ---
ENV_FILE="${SCRIPT_DIR}/.env.cloudrun"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "ERROR: .env.cloudrun not found. Please create it."
    exit 1
fi

PROJECT_ID=${PROJECT_ID}
SERVICE_ACCOUNT=${GCP_SERVICE_ACCOUNT}
MODEL_BUCKET=${MODEL_BUCKET_NAME}
REGION="us-central1"

if [ -z "$PROJECT_ID" ] || [ -z "$SERVICE_ACCOUNT" ] || [ -z "$MODEL_BUCKET" ]; then
    echo "ERROR: PROJECT_ID, GCP_SERVICE_ACCOUNT, or MODEL_BUCKET_NAME missing in .env.cloudrun"
    exit 1
fi

# --- Check and Create GCS Bucket ---
echo -e "\n=== Checking GCS Bucket: $MODEL_BUCKET ==="
if ! gcloud storage buckets list --filter="name=$MODEL_BUCKET" --format="value(name)" | grep -q "^$MODEL_BUCKET$"; then
    echo "Bucket not found. Creating GCS bucket '$MODEL_BUCKET' in region '$REGION'..."
    gcloud storage buckets create "gs://$MODEL_BUCKET" --project="$PROJECT_ID" --location="$REGION"
    echo "✓ Bucket created successfully."
else
    echo "✓ Bucket already exists."
fi

# --- Grant Bucket Permissions ---
echo -e "\n=== Granting Service Account Permissions for GCS Bucket ==="
echo "Granting 'Storage Object Admin' to '$SERVICE_ACCOUNT' on bucket '$MODEL_BUCKET'..."
gcloud storage buckets add-iam-policy-binding "gs://$MODEL_BUCKET" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/storage.objectAdmin" --condition=None >/dev/null # Suppress verbose output
echo "✓ Permissions granted."

# --- Build Docker Image ---
echo -e "\n=== Building Docker Image ==="
GCR_IMAGE="gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${TAG}"
echo "Running: docker build -f $DOCKERFILE -t $GCR_IMAGE . ${REBUILD_FLAG}"
docker build -f "$DOCKERFILE" -t "$GCR_IMAGE" . ${REBUILD_FLAG}
echo "✓ Build completed successfully"

# --- Push Docker Image ---
echo -e "\n=== Pushing Image to GCR ==="
gcloud auth configure-docker --quiet
echo "Pushing image to $GCR_IMAGE..."
docker push "$GCR_IMAGE"
echo "✓ Image pushed successfully."

# --- Deploy to Cloud Run ---
echo -e "\n=== Deploying to Cloud Run ==="
SERVICE_NAME="gnosis-ollama"
echo "Deploying service '$SERVICE_NAME' to Cloud Run..."

gcloud run deploy "$SERVICE_NAME" \
    --image "$GCR_IMAGE" \
    --region "$REGION" \
    --platform "managed" \
    --allow-unauthenticated \
    --memory "32Gi" \
    --cpu "8" \
    --gpu "1" \
    --gpu-type "nvidia-l4" \
    --concurrency "1" \
    --min-instances "1" \
    --max-instances "2" \
    --session-affinity \
    --execution-environment "gen2" \
    --no-cpu-throttling \
    --port "11434" \
    --timeout "3600" \
    --cpu-boost \
    --service-account "$SERVICE_ACCOUNT" \
    --add-volume "name=model-cache,type=cloud-storage,bucket=$MODEL_BUCKET" \
    --add-volume-mount "volume=model-cache,mount-path=/models"

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="value(status.url)")
echo "✓ CLOUD RUN DEPLOYMENT SUCCESSFUL!"
echo "🔗 Service URL: $SERVICE_URL"

echo -e "\n=== Deployment Complete ==="
