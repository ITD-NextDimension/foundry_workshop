<#
.SYNOPSIS
    Workshop sanity check — verify Lab 1 produced all expected outputs.

.DESCRIPTION
    Run this after `azd up` completes. Prints a ✅ / ❌ summary so students
    can self-diagnose before moving to Lab 2/3.

.EXAMPLE
    .\workshop-scripts\sanity-check.ps1
#>
[CmdletBinding()]
param(
    [string]$ExpectedAgent = "BasicAgent"
)

$ErrorActionPreference = "Continue"

function Write-Result {
    param([string]$Label, [bool]$Pass, [string]$Detail = "")
    if ($Pass) {
        Write-Host "✅ $Label" -ForegroundColor Green
        if ($Detail) { Write-Host "   $Detail" -ForegroundColor DarkGray }
    } else {
        Write-Host "❌ $Label" -ForegroundColor Red
        if ($Detail) { Write-Host "   $Detail" -ForegroundColor DarkYellow }
    }
}

Write-Host "`n=== Workshop Lab 1 Sanity Check ===`n" -ForegroundColor Cyan

# 1. azd env values present
$endpoint = & azd env get-value AZURE_AI_PROJECT_ENDPOINT 2>$null
$model    = & azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME 2>$null
$appI     = & azd env get-value APPLICATIONINSIGHTS_CONNECTION_STRING 2>$null
$swaUrl   = & azd env get-value SWA_URL 2>$null

Write-Result "AZURE_AI_PROJECT_ENDPOINT present" ($endpoint -ne $null -and $endpoint -ne "") $endpoint
Write-Result "AZURE_AI_MODEL_DEPLOYMENT_NAME present" ($model -ne $null -and $model -ne "") $model
Write-Result "APPLICATIONINSIGHTS_CONNECTION_STRING present" ($appI -ne $null -and $appI -ne "") ($appI -replace "Key=[^;]*", "Key=***")
Write-Result "SWA_URL present" ($swaUrl -ne $null -and $swaUrl -ne "") $swaUrl

# 2. Get a token; ensure Foundry endpoint reachable
$tokenOk = $false
$token = ""
try {
    $token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv 2>$null
    $tokenOk = ($LASTEXITCODE -eq 0 -and $token)
} catch {
    $tokenOk = $false
}
Write-Result "az access token for ai.azure.com" $tokenOk

# 3. Call hosted agent (placeholder)
if ($endpoint -and $tokenOk) {
    $url = "$endpoint/agents/$ExpectedAgent/responses"
    $body = @{ input = "ping" } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Method POST -Uri $url -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" -Body $body -TimeoutSec 30
        Write-Result "Hosted agent '$ExpectedAgent' reachable" $true
    } catch {
        Write-Result "Hosted agent '$ExpectedAgent' reachable" $false $_.Exception.Message
    }
} else {
    Write-Result "Hosted agent '$ExpectedAgent' reachable" $false "Skipped (endpoint or token missing)"
}

# 4. SWA reachable
if ($swaUrl) {
    try {
        $head = Invoke-WebRequest -Uri $swaUrl -Method Head -TimeoutSec 10 -UseBasicParsing
        Write-Result "SWA endpoint reachable" ($head.StatusCode -lt 500) ("HTTP " + $head.StatusCode)
    } catch {
        Write-Result "SWA endpoint reachable" $false $_.Exception.Message
    }
} else {
    Write-Result "SWA endpoint reachable" $false "SWA_URL not set"
}

Write-Host "`nIf any ❌ above, copy this entire output to the helper channel #help-lab-1.`n" -ForegroundColor Cyan
