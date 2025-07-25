# Loads a specified model into the Gnosis Ollama Cloud Run service.

param(
    [Parameter(Mandatory=$true)]
    [string]$ModelName,

    [string]$ServiceUrl = "https://gnosis-ollama-949870462453.us-central1.run.app"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Loading Model into Ollama Service ===" -ForegroundColor Cyan
Write-Host "Service URL: $ServiceUrl"
Write-Host "Model to load: $ModelName"

# --- Trigger model pull ---
Write-Host "`nTriggering pull for model: '$ModelName'. This may take several minutes..." -ForegroundColor White
$pullPayload = @{ name = $ModelName; stream = $false } | ConvertTo-Json

try {
    $pullUri = "$ServiceUrl/api/pull"
    Invoke-RestMethod -Uri $pullUri -Method Post -Body $pullPayload -ContentType "application/json" -TimeoutSec 3600 # 1 hour timeout for large models
    Write-Host "✓ Model '$ModelName' pulled successfully and is now stored in the GCS bucket." -ForegroundColor Green
} catch {
    Write-Error "Failed to pull model '$ModelName'. Error: $_"
}

Write-Host "`n=== Model Loading Complete ===" -ForegroundColor Green
