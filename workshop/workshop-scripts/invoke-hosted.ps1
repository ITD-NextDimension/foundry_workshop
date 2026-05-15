<#
.SYNOPSIS
    Invoke a hosted Foundry agent end-to-end (Lab 3 verification).

.PARAMETER AgentName
    Foundry agent name (case-sensitive). Default: billing-agent.

.PARAMETER Prompt
    User prompt to send. Ignored if -StatusOnly is set.

.PARAMETER StatusOnly
    Skip invocation; only print container status (placeholder via env).

.EXAMPLE
    .\workshop-scripts\invoke-hosted.ps1 -AgentName billing-agent -Prompt "我是 Acme 企业版,能退多少?"

.EXAMPLE
    .\workshop-scripts\invoke-hosted.ps1 -AgentName billing-agent -StatusOnly
#>
[CmdletBinding()]
param(
    [string]$AgentName = "billing-agent",
    [string]$Prompt = "Hello, who are you?",
    [switch]$StatusOnly
)

$endpoint = & azd env get-value AZURE_AI_PROJECT_ENDPOINT 2>$null
if (-not $endpoint) {
    Write-Host "❌ AZURE_AI_PROJECT_ENDPOINT not set. Run from inside an azd env (cd to your Track folder)." -ForegroundColor Red
    exit 1
}

$token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv 2>$null
if (-not $token) {
    Write-Host "❌ Could not get token. Re-run: az login --service-principal -u <appId> -p <secret> --tenant <tid>" -ForegroundColor Red
    exit 1
}

if ($StatusOnly) {
    # Minimal status probe: HEAD on agent root.
    $url = "$endpoint/agents/$AgentName"
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing -TimeoutSec 15
        Write-Host "status=Reachable, http=$($r.StatusCode), agent=$AgentName" -ForegroundColor Green
        Write-Host "(For real container status, ask instructor — it uses Foundry MCP agent_container_status_get.)" -ForegroundColor DarkGray
        exit 0
    } catch {
        Write-Host "status=Unreachable, error=$($_.Exception.Message)" -ForegroundColor Red
        exit 2
    }
}

$url = "$endpoint/agents/$AgentName/responses"
$body = @{ input = $Prompt } | ConvertTo-Json -Depth 8

Write-Host "→ POST $url" -ForegroundColor Cyan
Write-Host "→ prompt: $Prompt" -ForegroundColor DarkGray

try {
    $resp = Invoke-RestMethod -Method POST -Uri $url -Headers @{ Authorization = "Bearer $token" } `
        -ContentType "application/json" -Body $body -TimeoutSec 60
    Write-Host "`n--- Response ---" -ForegroundColor Green
    $resp | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ Invocation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor DarkYellow
    }
    exit 3
}
