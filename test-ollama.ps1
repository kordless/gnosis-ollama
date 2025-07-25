# Test script for the Gnosis Ollama Cloud Run service.

param(
    [string]$ServiceUrl = "https://gnosis-ollama-949870462453.us-central1.run.app"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Testing Ollama Service: $ServiceUrl ===" -ForegroundColor Cyan

# --- 1. Check available models ---
try {
    Write-Host "`n[1/2] Checking for available models at /api/tags..." -ForegroundColor White
    $tagsUri = "$ServiceUrl/api/tags"
    $response = Invoke-RestMethod -Uri $tagsUri -Method Get
    
    if ($response.models) {
        Write-Host "✓ Success! Available models:" -ForegroundColor Green
        $response.models | ForEach-Object { Write-Host "- $($_.name)" }
    } else {
        Write-Warning "Service is running, but no models found. The initial model pull may still be in progress or failed."
    }
} catch {
    Write-Error "Failed to connect to the service at $ServiceUrl. Error: $_"
    exit 1
}

# --- 2. Test text generation ---
try {
    Write-Host "`n[2/2] Sending test prompt to /api/generate..." -ForegroundColor White
    $generateUri = "$ServiceUrl/api/generate"
    $payload = @{
        model  = "llama3"
        prompt = "Why is the sky blue?"
        stream = $false
    } | ConvertTo-Json

    $headers = @{ "Content-Type" = "application/json" }

    $generationResponse = Invoke-RestMethod -Uri $generateUri -Method Post -Body $payload -Headers $headers

    if ($generationResponse.response) {
        Write-Host "✓ Success! Model generated a response:" -ForegroundColor Green
        Write-Host $generationResponse.response -ForegroundColor Gray
    } else {
        Write-Error "The service responded, but the model failed to generate text."
    }
} catch {
    Write-Error "Failed to generate text. The 'phi3' model may not be available or an error occurred. Details: $_"
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
