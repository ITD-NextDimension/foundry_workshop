<#
.SYNOPSIS
    Workshop sanity check —— 验证学员的 .env + 凭据 + 共享 Foundry 资源是否准备就绪。

.DESCRIPTION
    在 Lab 0/1 后跑一次。**不依赖 az/azd CLI**, 直接走 OAuth2 client_credentials grant
    拿 ai.azure.com token, 然后逐项查只读 API:

        1. .env 关键变量都已填 (AZURE_AI_PROJECT_ENDPOINT / AZURE_AI_MODEL_DEPLOYMENT_NAME /
                                STUDENT_SUFFIX / AZURE_CONTAINER_REGISTRY_NAME +
                                SP: AZURE_CLIENT_ID / SECRET / TENANT_ID)
        2. SP OAuth2 token 能拿到 (audience https://ai.azure.com/.default)
        3. 共享 model deployment 存在 (GET <project>/deployments)
        4. 学员自己的 hosted agent (research-agent-stuNN) 可达
        5. ACR (尝试 management.azure.com token + GET /listBuildSourceUploadUrl) -- 验证
           AcrPush + Contributor 角色

.EXAMPLE
    .\scripts\sanity-check.ps1

.EXAMPLE
    .\scripts\sanity-check.ps1 -ExpectedAgent research-agent-stu07
#>
[CmdletBinding()]
param(
    [string]$ExpectedAgent,
    [string]$EnvFile
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

Write-Host "`n=== Workshop Sanity Check ===`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------
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
    param([string]$Name)
    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($procVal) { return $procVal }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    return $null
}

$endpoint = Resolve-Var 'AZURE_AI_PROJECT_ENDPOINT'
$model    = Resolve-Var 'AZURE_AI_MODEL_DEPLOYMENT_NAME'
$suffix   = Resolve-Var 'STUDENT_SUFFIX'
$acrName  = Resolve-Var 'AZURE_CONTAINER_REGISTRY_NAME'
$clientId     = Resolve-Var 'AZURE_CLIENT_ID'
$clientSecret = Resolve-Var 'AZURE_CLIENT_SECRET'
$tenantId     = Resolve-Var 'AZURE_TENANT_ID'
$subId        = Resolve-Var 'AZURE_SUBSCRIPTION_ID'

Write-Result ".env: AZURE_AI_PROJECT_ENDPOINT"      ([bool]$endpoint)     $endpoint
Write-Result ".env: AZURE_AI_MODEL_DEPLOYMENT_NAME" ([bool]$model)        $model
Write-Result ".env: STUDENT_SUFFIX"                 ([bool]$suffix)       $suffix
Write-Result ".env: AZURE_CONTAINER_REGISTRY_NAME"  ([bool]$acrName)      $acrName
Write-Result ".env: AZURE_TENANT_ID"                ([bool]$tenantId)
Write-Result ".env: AZURE_CLIENT_ID"                ([bool]$clientId)
Write-Result ".env: AZURE_CLIENT_SECRET"            ([bool]$clientSecret)

if (-not $ExpectedAgent) {
    if ($suffix) { $ExpectedAgent = "research-agent-$suffix" } else { $ExpectedAgent = "research-agent" }
}

# ---------------------------------------------------------------------------
# OAuth2 token
# ---------------------------------------------------------------------------
$aiToken = $null
if ($clientId -and $clientSecret -and $tenantId) {
    try {
        $aiToken = (Invoke-RestMethod -Method POST `
            -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{
                client_id     = $clientId
                client_secret = $clientSecret
                scope         = 'https://ai.azure.com/.default'
                grant_type    = 'client_credentials'
            } -TimeoutSec 30).access_token
    } catch {}
}
Write-Result "OAuth2 token (ai.azure.com)" ([bool]$aiToken)

# ---------------------------------------------------------------------------
# Model deployment exists
# ---------------------------------------------------------------------------
if ($endpoint -and $model -and $aiToken) {
    $modelsUrl = "$endpoint/deployments?api-version=2025-05-15-preview"
    try {
        $r = Invoke-RestMethod -Method GET -Uri $modelsUrl `
            -Headers @{ Authorization = "Bearer $aiToken" } -TimeoutSec 15
        $items = @()
        if ($r.PSObject.Properties.Name -contains 'value') { $items = @($r.value) }
        elseif ($r.PSObject.Properties.Name -contains 'data') { $items = @($r.data) }
        $found = @($items | Where-Object { $_.name -eq $model -or $_.id -eq $model }).Count -gt 0
        Write-Result "模型 deployment '$model' 在共享 project 中" $found "items=$($items.Count)"
    } catch {
        Write-Result "模型 deployment '$model' 在共享 project 中" $false $_.Exception.Message
    }
} else {
    Write-Result "模型 deployment 在共享 project 中" $false "缺前置 (endpoint/model/token)"
}

# ---------------------------------------------------------------------------
# Hosted agent reachable
# ---------------------------------------------------------------------------
if ($endpoint -and $aiToken) {
    $url = "$endpoint/agents/$ExpectedAgent/endpoint/protocols/openai/responses?api-version=2025-11-15-preview"
    $body = @{ input = "ping" } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Method POST -Uri $url `
            -Headers @{ Authorization = "Bearer $aiToken" } `
            -ContentType "application/json" -Body $body -TimeoutSec 30
        Write-Result "Hosted agent '$ExpectedAgent' 可达" $true
    } catch {
        Write-Result "Hosted agent '$ExpectedAgent' 可达" $false $_.Exception.Message
    }
} else {
    Write-Result "Hosted agent '$ExpectedAgent' 可达" $false "缺前置 (endpoint/token)"
}

# ---------------------------------------------------------------------------
# ACR push capability (Contributor + AcrPush) via ARM management token
# ---------------------------------------------------------------------------
if ($acrName -and $clientId -and $clientSecret -and $tenantId -and $subId) {
    try {
        $armToken = (Invoke-RestMethod -Method POST `
            -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{
                client_id     = $clientId
                client_secret = $clientSecret
                scope         = 'https://management.azure.com/.default'
                grant_type    = 'client_credentials'
            } -TimeoutSec 30).access_token
        # listBuildSourceUploadUrl 是 ACR remote build 的关键 action
        $acrUrl = "https://management.azure.com/subscriptions/$subId/resourceGroups/foundry-workshop/providers/Microsoft.ContainerRegistry/registries/$acrName/listBuildSourceUploadUrl?api-version=2019-06-01-preview"
        $r = Invoke-RestMethod -Method POST -Uri $acrUrl -Headers @{ Authorization = "Bearer $armToken" } -TimeoutSec 15
        Write-Result "ACR '$acrName' 可远程构建 (AcrPush + Contributor)" ([bool]$r.uploadUrl)
    } catch {
        Write-Result "ACR '$acrName' 可远程构建 (AcrPush + Contributor)" $false $_.Exception.Message
    }
} else {
    Write-Result "ACR '$acrName' 可远程构建" $false "缺 ACR name 或 SP 凭据"
}

Write-Host "`n如有 ❌, 把整段输出贴到助教频道。`n" -ForegroundColor Cyan
