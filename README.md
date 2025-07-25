# Gnosis Ollama on Cloud Run

<div align="center">

**Scalable Ollama Service on Google Cloud with GPU Acceleration**

*Deploy and manage a powerful, persistent Ollama instance on Cloud Run.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)](https://www.docker.com/)
[![GPU Accelerated](https://img.shields.io/badge/GPU-Accelerated-green?logo=nvidia)](https://developer.nvidia.com/cuda-zone)
[![Cloud Run](https://img.shields.io/badge/Google%20Cloud-Run-4285F4?logo=google-cloud)](https://cloud.google.com/run)

[Quick Start](#-quick-start) • [Features](#-features) • [File Overview](#-file-overview) • [Usage](#-usage)

</div>

## ✨ Features

-   🚀 **Automated Deployment**: Deploy the entire Ollama service with a single command.
-   💾 **Persistent Model Storage**: Models are stored in a GCS bucket, so they persist across deployments and service restarts.
-   🧠 **Dynamic Model Loading**: Load new models into the service on-demand without needing to rebuild or redeploy.
-   ⚡ **GPU Acceleration**: Configured to use NVIDIA L4 GPUs on Cloud Run for optimal performance.
-   💰 **Cost Efficient**: The service can scale down to zero instances to save costs when not in use.

## 🚀 Quick Start

### Prerequisites

-   [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated.
-   [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.
-   A Google Cloud Project with billing enabled and the Cloud Run & Cloud Build APIs enabled.
-   A Service Account with permissions to manage Cloud Run and GCS.

### Setup & Deployment

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/kordless/gnosis-ollama.git
    cd gnosis-ollama
    ```
2.  **Configure your environment:**
    Create a `.env.cloudrun` file and add your project-specific details:
    ```env
    PROJECT_ID="your-gcp-project-id"
    GCP_SERVICE_ACCOUNT="your-service-account-email@your-project-id.iam.gserviceaccount.com"
    MODEL_BUCKET_NAME="your-unique-bucket-name-for-models"
    ```
3.  **Deploy the service:**
    -   **Windows:**
        ```powershell
        .\deploy-ollama.ps1
        ```
    -   **macOS/Linux:**
        ```bash
        chmod +x *.sh
        ./deploy-ollama.sh
        ```

🎉 **That's it!** The script will output the service URL when it's done.

## 📂 File Overview

| File | Platform | Description |
| :--- | :--- | :--- |
| `deploy-ollama.ps1` | Windows | Main deployment script. Handles GCS bucket, permissions, and Cloud Run deployment. |
| `load-model.ps1` | Windows | Utility to pull a new model into the running service. |
| `test-ollama.ps1` | Windows | Verifies the service is running and can respond to prompts. |
| `deploy-ollama.sh` | macOS/Linux | Main deployment script for Unix-based systems. |
| `load-model.sh` | macOS/Linux | Utility to pull models for Unix-based systems. |
| `test-ollama.sh` | macOS/Linux | Test script for Unix-based systems. |
| `Dockerfile.ollama` | All | Dockerfile for building the Ollama service container. |
| `.env.cloudrun` | All | Configuration file for your Cloud Run environment variables. |

## Usage

### 1. Load a Model

After the service is deployed, you can load any model from the Ollama library. This step is crucial as the base deployment contains no models.

-   **Windows:**
    ```powershell
    .\load-model.ps1 -ModelName "llama3"
    ```
-   **macOS/Linux:**
    ```bash
    ./load-model.sh --model "llama3"
    ```

You can run this command multiple times to load different models, including namespaced ones like `benhaotang/Nanonets-OCR-s`.

### 2. Test the Service

Verify that the service is working and that your model is available.

-   **Windows:**
    ```powershell
    .\test-ollama.ps1
    ```
-   **macOS/Linux:**
    ```bash
    ./test-ollama.sh
    ```

This script will list the available models and then send a test prompt to `llama3`.

---

<div align="center">

**⭐ Star this repository if you find it useful! ⭐**

</div>