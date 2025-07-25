# Gnosis Ollama on Cloud Run

This project contains a set of PowerShell scripts to deploy and manage a scalable Ollama service on Google Cloud Run with GPU acceleration and a persistent model cache using Google Cloud Storage.

## Features

- **Automated Deployment**: Deploy the entire Ollama service with a single command.
- **Persistent Model Storage**: Models are stored in a GCS bucket, so they persist across deployments and service restarts.
- **Dynamic Model Loading**: Load new models into the service on-demand without needing to rebuild or redeploy.
- **GPU Acceleration**: Configured to use NVIDIA L4 GPUs on Cloud Run for optimal performance.
- **Scales to Zero**: The service can scale down to zero instances to save costs when not in use.

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.
- A Google Cloud Project with billing enabled and the Cloud Run API enabled.
- A service account with permissions to manage Cloud Run and GCS.

## Files

- `deploy-ollama.ps1`: The main deployment script. It handles GCS bucket creation, permissions, Docker image build/push, and Cloud Run service deployment.
- `load-model.ps1`: A utility script to pull a new model into the running service.
- `test-ollama.ps1`: A simple script to verify that the service is running and can respond to prompts.
- `Dockerfile.ollama`: The Dockerfile for the Ollama service.
- `.env.cloudrun`: A configuration file holding your specific project ID, service account, and bucket names.

## Setup

1.  **Clone the repository.**
2.  **Create the `.env.cloudrun` file**: Copy the contents of `.env.sample` (or use the one checked in) and fill in the values for your Google Cloud project.
    - `PROJECT_ID`: Your Google Cloud project ID.
    - `GCP_SERVICE_ACCOUNT`: The email of the service account Cloud Run will use.
    - `MODEL_BUCKET_NAME`: The name for the GCS bucket that will store the models.

## Usage

### 1. Deploy the Service

Run the main deployment script. This only needs to be done once or when infrastructure changes are made.

```powershell
.\deploy-ollama.ps1
```

This will create the GCS bucket, build and push the Docker image, and deploy the service to Cloud Run.

### 2. Load a Model

After the service is deployed, you can load any model from the Ollama library.

```powershell
.\load-model.ps1 -ModelName "llama3"
```

You can run this command multiple times to load different models.

### 3. Test the Service

Verify that the service is working and that your model is available.

```powershell
.\test-ollama.ps1
```

This script will list the available models and then send a test prompt to `llama3`.

