# Test script for the Gnosis Ollama Cloud Run service.
# This script sends multiple parallel requests to test concurrency.

param(
    [string]$ServiceUrl = "https://gnosis-ollama-949870462453.us-central1.run.app"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Testing Ollama Service Concurrency: $ServiceUrl ===" -ForegroundColor Cyan

# --- 1. Check for Service Availability ---
try {
    Write-Host "`n[1/3] Checking service availability at $ServiceUrl..." -ForegroundColor White
    $healthCheck = Invoke-RestMethod -Uri $ServiceUrl -Method Get -TimeoutSec 10
    Write-Host "✓ Service is responding." -ForegroundColor Green
} catch {
    Write-Error "Service is not available at $ServiceUrl. Please check the URL and ensure the service is running. Error: $_"
    exit 1
}

# --- 2. Check available models ---
try {
    Write-Host "`n[2/3] Checking for available models at /api/tags..." -ForegroundColor White
    $tagsUri = "$ServiceUrl/api/tags"
    $response = Invoke-RestMethod -Uri $tagsUri -Method Get

    if ($response.models) {
        Write-Host "✓ Success! Available models found." -ForegroundColor Green
        $response.models | ForEach-Object { Write-Host "- $($_.name)" }
    } else {
        Write-Warning "Service is running, but no models found. The initial model pull may still be in progress or failed."
        # We will still attempt to generate text in case the model is available but not listed yet.
    }
} catch {
    Write-Error "Failed to check for models. Error: $_"
    exit 1
}


# --- 3. Test Parallel Text Generation ---
$prompts = @(
    "Why is the sky blue?",
    "What is the speed of light?",
    "Write a short poem about a robot.",
    "What are the main ingredients in a pizza?"
)
$jobs = @()

Write-Host "`n[3/3] Sending 4 parallel requests to /api/generate..." -ForegroundColor White

foreach ($prompt in $prompts) {
    $scriptBlock = {
        param($ServiceUrl, $prompt)
        $generateUri = "$ServiceUrl/api/generate"
        $payload = @{
            model  = "llama3"
            prompt = $prompt
            stream = $false
        } | ConvertTo-Json
        $headers = @{ "Content-Type" = "application/json" }
        
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-RestMethod -Uri $generateUri -Method Post -Body $payload -Headers $headers
            $stopwatch.Stop()
            
            return [PSCustomObject]@{
                Prompt   = $prompt
                Success  = $true
                Response = $response.response
                Duration = $stopwatch.Elapsed.TotalSeconds
            }
        } catch {
            return [PSCustomObject]@{
                Prompt   = $prompt
                Success  = $false
                Response = "Request failed: $($_.Exception.Message)"
                Duration = -1
            }
        }
    }
    
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $ServiceUrl, $prompt
    $jobs += $job
}

Write-Host "Waiting for all 4 jobs to complete..." -ForegroundColor Gray
$results = $jobs | Receive-Job -Wait -AutoRemoveJob

Write-Host "✓ All jobs complete. Results:" -ForegroundColor Green

$results | ForEach-Object {
    if ($_.Success) {
        Write-Host "---"
        Write-Host "Prompt: $($_.Prompt)" -ForegroundColor Cyan
        Write-Host "Duration: $($_.Duration) seconds" -ForegroundColor Yellow
        Write-Host "Response: $($_.Response)" -ForegroundColor Gray
    } else {
        Write-Host "---"
        Write-Host "Prompt: $($_.Prompt)" -ForegroundColor Cyan
        Write-Host "Status: FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Response)" -ForegroundColor Red
    }
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green