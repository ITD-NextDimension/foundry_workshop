<#
.SYNOPSIS
    Workshop sanity check —— 验证学员的 azd env 与共享 Foundry 资源是否准备就绪。

.DESCRIPTION
    在 Lab 1 完成 (`azd deploy <agent>` 部署 placeholder hosted agent) 后跑。
    检查项 (全是只读，不创建任何东西):
        1. azd env 必备变量都已填 (AZURE_AI_PROJECT_ENDPOINT / MODEL_DEPLOYMENT_NAME / STUDENT_SUFFIX / ACR)
        2. az / azd 已登录，且能拿到 ai.azure.com 的 access token
        3. 共享 model deployment 存在
        4. 学员自己的 hosted agent (research-agent-stuNN) status 可达
        5. 共享 ACR 可达且学员有 push 权限 (尝试 `az acr login`)

.EXAMPLE
    .\workshop-scripts\sanity-check.ps1

.EXAMPLE
    .\workshop-scripts\sanity-check.ps1 -ExpectedAgent research-agent-stu07
#>
[CmdletBinding()]
param(
    [string]$ExpectedAgent
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
# 1. azd env 变量
# ---------------------------------------------------------------------------
$endpoint = & azd env get-value AZURE_AI_PROJECT_ENDPOINT 2>$null
$model    = & azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME 2>$null
$suffix   = & azd env get-value STUDENT_SUFFIX 2>$null
$acrName  = & azd env get-value AZURE_CONTAINER_REGISTRY_NAME 2>$null
$acrEp    = & azd env get-value AZURE_CONTAINER_REGISTRY_ENDPOINT 2>$null

Write-Result "AZURE_AI_PROJECT_ENDPOINT 已设置" (-not [string]::IsNullOrWhiteSpace($endpoint)) $endpoint
Write-Result "AZURE_AI_MODEL_DEPLOYMENT_NAME 已设置" (-not [string]::IsNullOrWhiteSpace($model)) $model
Write-Result "STUDENT_SUFFIX 已设置" (-not [string]::IsNullOrWhiteSpace($suffix)) $suffix
Write-Result "AZURE_CONTAINER_REGISTRY_NAME 已设置" (-not [string]::IsNullOrWhiteSpace($acrName)) $acrName

if (-not $ExpectedAgent) {
    if ($suffix) { $ExpectedAgent = "research-agent-$suffix" } else { $ExpectedAgent = "research-agent" }
}

# ---------------------------------------------------------------------------
# 2. az/azd 登录态 + token
# ---------------------------------------------------------------------------
$loggedIn = $false
try {
    az account show --output none 2>$null
    $loggedIn = ($LASTEXITCODE -eq 0)
} catch { $loggedIn = $false }
Write-Result "az 已登录" $loggedIn

$token = ""
if ($loggedIn) {
    $token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv 2>$null
}
Write-Result "ai.azure.com access token" (-not [string]::IsNullOrWhiteSpace($token))

# ---------------------------------------------------------------------------
# 3. 共享 model deployment 存在
# ---------------------------------------------------------------------------
if ($endpoint -and $model -and $token) {
    # Foundry deployments REST: GET <endpoint>/deployments?api-version=...
    # 简化为通过 OpenAI 兼容端点的 list models 验证。
    $modelsUrl = "$endpoint/models?api-version=2024-10-01-preview"
    try {
        $r = Invoke-RestMethod -Method GET -Uri $modelsUrl `
            -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 15
        $found = $false
        if ($r.data) { $found = ($r.data | Where-Object { $_.id -eq $model -or $_.deployment -eq $model }).Count -gt 0 }
        Write-Result "模型 deployment '$model' 在共享 project 中" $found
    } catch {
        Write-Result "模型 deployment '$model' 在共享 project 中" $false $_.Exception.Message
    }
} else {
    Write-Result "模型 deployment 在共享 project 中" $false "缺前置条件 (endpoint/model/token)"
}

# ---------------------------------------------------------------------------
# 4. 学员自己的 hosted agent 可达
# ---------------------------------------------------------------------------
if ($endpoint -and $token) {
    $envVarName = "AGENT_" + ($ExpectedAgent.ToUpper() -replace '[^A-Z0-9]', '_') + "_RESPONSES_ENDPOINT"
    $url = & azd env get-value $envVarName 2>$null
    if (-not $url) {
        $url = "$endpoint/agents/$ExpectedAgent/endpoint/protocols/openai/responses?api-version=2025-11-15-preview"
    }
    $body = @{ input = "ping" } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Method POST -Uri $url `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" -Body $body -TimeoutSec 30
        Write-Result "Hosted agent '$ExpectedAgent' 可达" $true
    } catch {
        Write-Result "Hosted agent '$ExpectedAgent' 可达" $false $_.Exception.Message
    }
} else {
    Write-Result "Hosted agent '$ExpectedAgent' 可达" $false "缺前置条件 (endpoint/token)"
}

# ---------------------------------------------------------------------------
# 5. ACR 登录 (验证 AcrPush 角色)
# ---------------------------------------------------------------------------
if ($acrName -and $loggedIn) {
    az acr login --name $acrName --output none 2>$null
    Write-Result "ACR '$acrName' 可推送 (acr login OK)" ($LASTEXITCODE -eq 0)
} else {
    Write-Result "ACR '$acrName' 可推送" $false "缺 ACR name 或未登录"
}

Write-Host "`n如有 ❌，把整段输出贴到助教频道。`n" -ForegroundColor Cyan
