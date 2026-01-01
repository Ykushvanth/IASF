# Test Groq API connectivity
# Load API key from .env file
$envPath = "config\.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^GROQ_API_KEY=(.+)$") {
            $apiKey = $matches[1]
        }
    }
} else {
    Write-Host "Error: config\.env file not found" -ForegroundColor Red
    exit 1
}

if (-not $apiKey) {
    Write-Host "Error: GROQ_API_KEY not found in .env file" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $apiKey"
}

$body = @{
    model = "llama-3.3-70b-versatile"
    messages = @(
        @{
            role = "user"
            content = "Say 'test successful' in one sentence."
        }
    )
    max_tokens = 20
} | ConvertTo-Json -Depth 10

Write-Host "Testing Groq API..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest `
        -Uri "https://api.groq.com/openai/v1/chat/completions" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -TimeoutSec 10

    Write-Host "✅ Success! Status: $($response.StatusCode)" -ForegroundColor Green
    $result = $response.Content | ConvertFrom-Json
    Write-Host "Response: $($result.choices[0].message.content)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response body: $responseBody" -ForegroundColor Red
    }
}
