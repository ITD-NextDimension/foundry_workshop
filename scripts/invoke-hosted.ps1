<#
.SYNOPSIS
    命令行单次调用一个 hosted Foundry agent (Lab 1/3 自动化验证)。

.DESCRIPTION
    不依赖 az/azd CLI: 直接走 OAuth2 client_credentials grant 拿 token (跟 chat-hosted.ps1 一样)。
    凭据来源优先级: 显式参数 > 进程 env > workshop 根 .env

    Lab 1: 一次性 ping 检查 hosted endpoint 是否 200
    Lab 3: 业务 prompt 验证

.EXAMPLE
    .\scripts\invoke-hosted.ps1 -AgentName research-agent -Prompt "ping"

.EXAMPLE
    .\scripts\invoke-hosted.ps1 -AgentName research-agent -StatusOnly
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$Prompt = "Hello, who are you?",
    [switch]$StatusOnly,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$TenantId,
    [string]$Endpoint,
    [string]$EnvFile,
    [string]$ApiVersion = '2025-11-15-preview'
)

$ErrorActionPreference = 'Stop'

# Load .env
if (-not $EnvFile) { $EnvFile = Join-Path $PSScriptRoot '..\.env' }
$envFromFile = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $eq = $line.IndexOf('=')
            if ($eq -gt 0) {
                $k = $line.Substring(0, $eq).Trim()
                $v = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
                if ($v) { $envFromFile[$k] = $v }
            }
        }
    }
}
function Resolve-Var {
    param([string]$ParamValue, [string]$Name)
    if ($ParamValue) { return $ParamValue }
    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($procVal) { return $procVal }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    return $null
}

$ClientId     = Resolve-Var $ClientId     'AZURE_CLIENT_ID'
$ClientSecret = Resolve-Var $ClientSecret 'AZURE_CLIENT_SECRET'
$TenantId     = Resolve-Var $TenantId     'AZURE_TENANT_ID'
$Endpoint     = Resolve-Var $Endpoint     'AZURE_AI_PROJECT_ENDPOINT'
if (-not $AgentName) {
    $AgentName = Resolve-Var $null 'AGENT_NAME'
    if (-not $AgentName) {
        $suffix = Resolve-Var $null 'STUDENT_SUFFIX'
        if ($suffix) { $AgentName = "research-agent-$suffix" } else { $AgentName = 'research-agent' }
    }
}

$missing = @()
if (-not $ClientId)     { $missing += 'AZURE_CLIENT_ID' }
if (-not $ClientSecret) { $missing += 'AZURE_CLIENT_SECRET' }
if (-not $TenantId)     { $missing += 'AZURE_TENANT_ID' }
if (-not $Endpoint)     { $missing += 'AZURE_AI_PROJECT_ENDPOINT' }
if ($missing.Count -gt 0) {
    Write-Host "❌ 缺以下变量: $($missing -join ', ') — 请把 .env.example 复制成 .env 并填好。" -ForegroundColor Red
    exit 1
}

# Get token via OAuth2 client_credentials
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$tokenResp = Invoke-RestMethod -Method POST -Uri $tokenUrl `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'https://ai.azure.com/.default'
        grant_type    = 'client_credentials'
    } -TimeoutSec 30
$token = $tokenResp.access_token

$responsesUrl = "$Endpoint/agents/$AgentName/endpoint/protocols/openai/responses?api-version=$ApiVersion"

if ($StatusOnly) {
    $url = "$Endpoint/agents/$AgentName"
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing -TimeoutSec 15
        Write-Host "status=Reachable, http=$($r.StatusCode), agent=$AgentName" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "status=Unreachable, error=$($_.Exception.Message)" -ForegroundColor Red
        exit 2
    }
}

$body = @{ input = $Prompt; store = $false } | ConvertTo-Json -Depth 8

Write-Host "→ POST $responsesUrl" -ForegroundColor Cyan
Write-Host "→ prompt: $Prompt" -ForegroundColor DarkGray

try {
    $resp = Invoke-RestMethod -Method POST -Uri $responsesUrl `
        -Headers @{ Authorization = "Bearer $token" } `
        -ContentType "application/json" -Body $body -TimeoutSec 120
    Write-Host "`n--- Response ---" -ForegroundColor Green
    $resp | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ Invocation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor DarkYellow }
    exit 3
}
