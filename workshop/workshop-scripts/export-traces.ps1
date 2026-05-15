<#
.SYNOPSIS
    Export recent traces from Application Insights as a JSON file
    (consumed by the offline observability HTML in Lab 4).

.PARAMETER AgentName
    Foundry agent name to filter on. Default: billing-agent.

.PARAMETER Minutes
    Time window in minutes. Default: 60.

.PARAMETER Output
    Output JSON path. Default: observability/offline/data/my-traces.json

.EXAMPLE
    .\workshop-scripts\export-traces.ps1 -AgentName billing-agent -Minutes 60
#>
[CmdletBinding()]
param(
    [string]$AgentName = "billing-agent",
    [int]$Minutes = 60,
    [string]$Output = "..\observability\offline\data\my-traces.json"
)

$swa = & azd env get-value SWA_URL 2>$null
if (-not $swa) {
    Write-Host "❌ SWA_URL not set. Falling back to direct Application Insights query is not supported in this script." -ForegroundColor Red
    Write-Host "   You can still use the sample JSON shipped in observability/offline/data/." -ForegroundColor Yellow
    exit 1
}

$url = "$swa/api/traces?agentName=$AgentName&minutes=$Minutes&format=offline"
Write-Host "→ Pulling traces from $url" -ForegroundColor Cyan

try {
    $resp = Invoke-RestMethod -Uri $url -TimeoutSec 30
} catch {
    Write-Host "❌ SWA API call failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

$outPath = Join-Path -Path (Get-Location) -ChildPath $Output
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force $outDir | Out-Null
}

$resp | ConvertTo-Json -Depth 20 | Set-Content -Path $outPath -Encoding UTF8

Write-Host "✅ Wrote $outPath ($((Get-Item $outPath).Length) bytes)" -ForegroundColor Green
Write-Host "   Open observability/offline/index.html and pick 'my-traces.json' from the data dropdown." -ForegroundColor DarkGray
