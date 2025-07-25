# Gnosis Ollama Cloud Run Deployment Script
# Builds and deploys the Ollama service to Cloud Run with a persistent GCS model cache.

param(
    [string]$ModelToLoad = "phi3", # Model to load after deployment
    [string]$Tag = "latest",
    [switch]$Rebuild = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "Gnosis Ollama Deployment Script" -ForegroundColor Cyan
    Write-Host "USAGE: .\deploy-ollama.ps1 [-ModelToLoad <model_name>] [-Tag <tag>] [-Rebuild]" -ForegroundColor White
    exit 0
}

$ErrorActionPreference = "Stop"

# --- Project Configuration ---
$projectRoot = $PSScriptRoot
$imageName = "gnosis-ollama"
$fullImageName = "${imageName}:${Tag}"
$dockerfile = "Dockerfile.ollama"

Write-Host "=== Gnosis Ollama Deployment ===" -ForegroundColor Cyan
Write-Host "Image: $fullImageName, Initial Model: $ModelToLoad" -ForegroundColor White

# --- Validate Configuration ---
$dockerfilePath = Join-Path $projectRoot $dockerfile
if (-not (Test-Path $dockerfilePath)) { Write-Error "Dockerfile not found: $dockerfilePath" }

# --- Load Cloud Run Environment ---
$envConfig = @{}
$envFile = Join-Path $projectRoot ".env.cloudrun"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        $envConfig[$key.Trim()] = $value.Trim()
    }
} else {
    Write-Error ".env.cloudrun not found. Please create it from .env.sample."
}

$projectId = $envConfig["PROJECT_ID"]
$serviceAccount = $envConfig["GCP_SERVICE_ACCOUNT"]
$modelBucket = $envConfig["MODEL_BUCKET_NAME"]
$region = "us-central1" # Statically set region

if (-not $projectId -or -not $serviceAccount -or -not $modelBucket) {
    Write-Error "PROJECT_ID, GCP_SERVICE_ACCOUNT, or MODEL_BUCKET_NAME missing in .env.cloudrun"
}

# --- Check and Create GCS Bucket ---
Write-Host "`n=== Checking GCS Bucket: $modelBucket ===" -ForegroundColor Green
$bucketExists = & gcloud storage buckets list --filter="name=$modelBucket" --format="value(name)"
if (-not $bucketExists) {
    Write-Host "Bucket not found. Creating GCS bucket '$modelBucket' in region '$region'..." -ForegroundColor Yellow
    & gcloud storage buckets create "gs://$modelBucket" --project=$projectId --location=$region
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create GCS bucket." }
    Write-Host "✓ Bucket created successfully." -ForegroundColor Green
} else {
    Write-Host "✓ Bucket already exists." -ForegroundColor Green
}

# --- Grant Bucket Permissions ---
Write-Host "`n=== Granting Service Account Permissions for GCS Bucket ===" -ForegroundColor Green
Write-Host "Granting 'Storage Object Admin' to '$serviceAccount' on bucket '$modelBucket'..." -ForegroundColor White
& gcloud storage buckets add-iam-policy-binding "gs://$modelBucket" --member="serviceAccount:$serviceAccount" --role="roles/storage.objectAdmin"
if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to set IAM policy. This may be okay if it's already set." } else { Write-Host "✓ Permissions granted." -ForegroundColor Green }

# --- Build Docker Image ---
Write-Host "`n=== Building Docker Image ===" -ForegroundColor Green
$gcrImage = "gcr.io/$projectId/${imageName}:${Tag}"
$buildArgs = @("build", "-f", $dockerfile, "-t", $gcrImage, ".")
if ($Rebuild) { $buildArgs += "--no-cache" }

Write-Host "Running: docker $($buildArgs -join ' ')" -ForegroundColor Gray
& docker @buildArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Docker build failed." }
Write-Host "✓ Build completed successfully" -ForegroundColor Green

# --- Push Docker Image ---
Write-Host "`n=== Pushing Image to GCR ===" -ForegroundColor Green
& gcloud auth configure-docker --quiet
Write-Host "Pushing image to $gcrImage..." -ForegroundColor Gray
& docker push $gcrImage
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to push image to GCR." }
Write-Host "✓ Image pushed successfully." -ForegroundColor Green

# --- Deploy to Cloud Run ---
Write-Host "`n=== Deploying to Cloud Run ===" -ForegroundColor Green
$serviceName = "gnosis-ollama"
Write-Host "Deploying service '$serviceName' to Cloud Run..." -ForegroundColor White

# Build the environment variable string separately for reliability
$envVarString = ($envConfig.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ","

$deployArgs = @(
    "run", "deploy", $serviceName,
    "--image", $gcrImage,
    "--region", $region,
    "--platform", "managed",
    "--allow-unauthenticated",
    "--memory", "16Gi",
    "--cpu", "4",
    "--gpu", "1",
    "--gpu-type", "nvidia-l4",
    "--concurrency", "4",
    "--min-instances", "0",
    "--max-instances", "1",
    "--session-affinity",
    "--execution-environment", "gen2",
    "--no-cpu-throttling",
    "--port", "11434",
    "--timeout", "3600",
    "--service-account", $serviceAccount,
    "--add-volume", "name=model-cache,type=cloud-storage,bucket=$modelBucket",
    "--add-volume-mount", "volume=model-cache,mount-path=/models",
    "--set-env-vars", $envVarString
)

& gcloud @deployArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Cloud Run deployment failed." }

$serviceUrl = & gcloud run services describe $serviceName --region=$region --format="value(status.url)"
Write-Host "✓ CLOUD RUN DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "🔗 Service URL: $serviceUrl" -ForegroundColor Cyan

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
