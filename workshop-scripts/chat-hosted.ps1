<#
.SYNOPSIS
    打开本地图形化 chat UI，跟 Lab 1/3 部署的 hosted agent 聊天 (无 az login 依赖)。

.DESCRIPTION
    流程:
        1. 从 .env / 进程 env / azd env 读 SP 凭据 + endpoint + agent name
        2. 直接 OAuth2 client_credentials grant 拿 AAD token (audience: https://ai.azure.com)
           — 不依赖 `az login`, 也不依赖 azd auth, 只用学员手里的 SP 凭据
        3. 把 endpoint / agent / token 序列化成 base64-JSON 写进 URL #cfg=
        4. 在默认浏览器中打开 workshop-scripts/chat-hosted/index.html

    凭据来源优先级 (越靠前优先级越高):
        1. 命令行参数 -ClientId / -ClientSecret / -TenantId / -Endpoint / -AgentName
        2. 进程环境变量 AZURE_CLIENT_ID / AZURE_CLIENT_SECRET / AZURE_TENANT_ID /
                       AZURE_AI_PROJECT_ENDPOINT / AGENT_NAME
        3. track-A/.env (KEY=VALUE 行)
        4. azd env (azd env get-value <KEY>) — 仅当 azd 已安装且当前目录是 azd env

    设计意图:
        - 学员没 azure portal / 没 az CLI 也能用; 唯一前提是 SP 凭据填进 .env
        - token 只在本地 PowerShell 内存 -> base64 -> URL hash, 不写文件
        - 适合 WSL / 远程 / Codespaces / 任何没装 az 的机器

.PARAMETER AgentName
    Hosted agent 名 (e.g. research-agent-stu07)。默认从 env 推导。

.PARAMETER ClientId
    SP appId / client ID。默认 $env:AZURE_CLIENT_ID。

.PARAMETER ClientSecret
    SP secret。默认 $env:AZURE_CLIENT_SECRET。

.PARAMETER TenantId
    AAD tenant ID。默认 $env:AZURE_TENANT_ID。

.PARAMETER Endpoint
    Foundry project endpoint。默认 $env:AZURE_AI_PROJECT_ENDPOINT。

.PARAMETER EnvFile
    从哪读 .env, 默认 .\.env (相对当前目录, 学员一般在 track-A 里跑)。

.PARAMETER NoOpen
    不自动打开浏览器, 只打印 URL。

.PARAMETER ApiVersion
    Foundry agents responses API 版本 (默认 2025-11-15-preview)。

.EXAMPLE
    # 推荐: 在 track-A 目录, .env 已填好 SP + endpoint
    cd track-A
    ..\workshop-scripts\chat-hosted.ps1

.EXAMPLE
    # 显式传参 (绕开 .env / azd env)
    ..\workshop-scripts\chat-hosted.ps1 `
      -ClientId  cd34465a-... `
      -ClientSecret 's...' `
      -TenantId  9aea4c40-... `
      -Endpoint  'https://itd-foundry.services.ai.azure.com/api/projects/itd-foundry-workshop' `
      -AgentName research-agent
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$TenantId,
    [string]$Endpoint,
    [string]$EnvFile = '.\.env',
    [switch]$NoOpen,
    [string]$ApiVersion = '2025-11-15-preview'
)

$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Warn2 { param([string]$m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Ok    { param([string]$m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Err   { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Load .env into a hashtable (KEY=VALUE, '#' comments ignored)
# ---------------------------------------------------------------------------
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
    Write-Info "从 $EnvFile 读到 $($envFromFile.Count) 个变量"
}

# Helper: resolve a value from (param > process env > .env > azd env)
function Resolve-Var {
    param(
        [string]$ParamValue,
        [string]$Name
    )
    if ($ParamValue) { return $ParamValue }
    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($procVal) { return $procVal }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    # azd env fallback (silent if azd missing or not in env dir)
    try {
        $azdVal = (& azd env get-value $Name 2>$null | Out-String).Trim()
        if ($azdVal -and -not $azdVal.StartsWith('ERROR')) { return $azdVal }
    } catch {}
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

# Validate
$missing = @()
if (-not $ClientId)     { $missing += 'AZURE_CLIENT_ID' }
if (-not $ClientSecret) { $missing += 'AZURE_CLIENT_SECRET' }
if (-not $TenantId)     { $missing += 'AZURE_TENANT_ID' }
if (-not $Endpoint)     { $missing += 'AZURE_AI_PROJECT_ENDPOINT' }
if ($missing.Count -gt 0) {
    Write-Err "缺以下变量: $($missing -join ', ')"
    Write-Host "   填到 track-A\.env 里, 或显式传 -ClientId/-ClientSecret/-TenantId/-Endpoint 参数。" -ForegroundColor DarkGray
    Write-Host "   .env 例:" -ForegroundColor DarkGray
    Write-Host "     AZURE_CLIENT_ID=<sp appId>" -ForegroundColor DarkGray
    Write-Host "     AZURE_CLIENT_SECRET=<sp secret>" -ForegroundColor DarkGray
    Write-Host "     AZURE_TENANT_ID=<tenant guid>" -ForegroundColor DarkGray
    Write-Host "     AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>" -ForegroundColor DarkGray
    exit 1
}

Write-Info "endpoint  = $Endpoint"
Write-Info "agent     = $AgentName"
Write-Info "tenant    = $TenantId"
Write-Info "client_id = $ClientId"
Write-Info "apiVer    = $ApiVersion"

# ---------------------------------------------------------------------------
# 2. AAD OAuth2 client_credentials grant — no az / azd needed
# ---------------------------------------------------------------------------
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$body = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = 'https://ai.azure.com/.default'
    grant_type    = 'client_credentials'
}
try {
    $resp = Invoke-RestMethod -Method POST -Uri $tokenUrl `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $body -TimeoutSec 30
    $token = $resp.access_token
    $expIn = $resp.expires_in
    if (-not $token) { throw "no access_token in response" }
    Write-Ok "拿到 AAD token (audience=ai.azure.com, expires_in=${expIn}s, len=$($token.Length))"
} catch {
    $err = $_.Exception.Message
    if ($_.ErrorDetails.Message) { $err = $_.ErrorDetails.Message }
    Write-Err "OAuth2 token 拿不到: $err"
    Write-Host "   常见原因: secret 写错 / secret 过期 / tenant 错 / SP 没在该 audience 上有权限" -ForegroundColor DarkGray
    exit 2
}

# ---------------------------------------------------------------------------
# 3. 序列化 cfg 进 URL #cfg=
# ---------------------------------------------------------------------------
$cfg = [ordered]@{
    endpoint   = $Endpoint
    agent      = $AgentName
    token      = $token
    store      = $false
    apiVersion = $ApiVersion
}
$json = $cfg | ConvertTo-Json -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$b64 = [Convert]::ToBase64String($bytes)
$cfgFragment = [Uri]::EscapeDataString($b64)

$htmlPath = Join-Path $PSScriptRoot 'chat-hosted\index.html'
if (-not (Test-Path $htmlPath)) {
    Write-Err "找不到 $htmlPath。仓库被改坏了？"
    exit 1
}
$absPath = (Resolve-Path $htmlPath).Path
$fileUri = 'file:///' + ($absPath -replace '\\', '/') + '#cfg=' + $cfgFragment

Write-Host ""
Write-Ok "Chat UI URL (含 token, 不要分享):"
Write-Host "    $fileUri" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# 4. 开浏览器
# ---------------------------------------------------------------------------
if ($NoOpen) {
    Write-Info "(-NoOpen) 复制上面 URL 到浏览器里打开即可。"
    exit 0
}

try {
    Start-Process $fileUri
    Write-Ok "已在默认浏览器中打开。Token ${expIn}s 后失效, 重跑此脚本即可换新。"
} catch {
    Write-Warn2 "Start-Process 失败 ($($_.Exception.Message))，请手动粘上面 URL 到浏览器。"
}
