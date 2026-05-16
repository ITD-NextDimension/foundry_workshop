<#
.SYNOPSIS
    打开本地图形化 chat UI，跟 Lab 1/3 部署的 hosted agent 聊天。

.DESCRIPTION
    流程:
        1. 从 azd env 读 AZURE_AI_PROJECT_ENDPOINT / AGENT_NAME / STUDENT_SUFFIX
        2. 用学员 SP token (az account get-access-token --resource https://ai.azure.com)
        3. 把 endpoint / agent / token 序列化成 base64-JSON 写进 URL #cfg=
        4. 在默认浏览器中打开 workshop-scripts/chat-hosted/index.html
        5. 浏览器里直接打字聊天，多轮上下文保留在页面里

    设计意图:
        - 学员不需要登 Azure Portal
        - 不需要装额外依赖 (HTML 是单文件、所有逻辑在前端)
        - token 仅注入到 URL hash 不会发到任何服务器
        - 推荐配合 invoke-hosted.ps1 (无 GUI 自检) 一起用

.PARAMETER AgentName
    Hosted agent 名 (e.g. research-agent-stu07)。默认从 azd env 推导。

.PARAMETER NoOpen
    不自动打开浏览器，只打印 URL (方便复制到 WSL / 其它机器)。

.PARAMETER ApiVersion
    Foundry agents responses API 版本 (默认 2025-11-15-preview)。

.EXAMPLE
    .\workshop-scripts\chat-hosted.ps1

.EXAMPLE
    .\workshop-scripts\chat-hosted.ps1 -AgentName research-agent-stu07

.EXAMPLE
    # 在 WSL / 远程机器上跑：拿到 URL 后自己粘到浏览器
    .\workshop-scripts\chat-hosted.ps1 -NoOpen
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [switch]$NoOpen,
    [string]$ApiVersion = '2025-11-15-preview'
)

$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Warn2 { param([string]$m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Ok    { param([string]$m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Err   { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. 从 azd env 读 endpoint / agent name
# ---------------------------------------------------------------------------
$endpoint = (& azd env get-value AZURE_AI_PROJECT_ENDPOINT 2>$null | Out-String).Trim()
if (-not $endpoint) {
    Write-Err "AZURE_AI_PROJECT_ENDPOINT 未设置。请 cd 到 track-A 目录 (含 .azure/dev) 再运行。"
    exit 1
}

if (-not $AgentName) {
    $envAgent = (& azd env get-value AGENT_NAME 2>$null | Out-String).Trim()
    if ($envAgent -and -not $envAgent.StartsWith('ERROR')) {
        $AgentName = $envAgent
    } else {
        $suffix = (& azd env get-value STUDENT_SUFFIX 2>$null | Out-String).Trim()
        if ($suffix -and -not $suffix.StartsWith('ERROR')) {
            $AgentName = "research-agent-$suffix"
        } else {
            $AgentName = "research-agent"
            Write-Warn2 "STUDENT_SUFFIX / AGENT_NAME 都没设, 默认用 'research-agent'."
        }
    }
}

Write-Info "endpoint  = $endpoint"
Write-Info "agent     = $AgentName"
Write-Info "apiVer    = $ApiVersion"

# ---------------------------------------------------------------------------
# 2. 拿 SP token (ai.azure.com audience)
# ---------------------------------------------------------------------------
$token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv 2>$null
if (-not $token) {
    Write-Err "无法获取 ai.azure.com token。先 az login 用学员 SP。"
    Write-Host '   az login --service-principal -u <appId> "--password=<secret>" --tenant <tid>' -ForegroundColor DarkGray
    exit 1
}
Write-Ok "拿到 SP token (长度=$($token.Length))"

# ---------------------------------------------------------------------------
# 3. 序列化 cfg 进 URL #cfg=
# ---------------------------------------------------------------------------
$cfg = @{
    endpoint   = $endpoint
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
    Write-Ok "已在默认浏览器中打开。Token 一小时左右失效, 失效后重新跑此脚本即可。"
} catch {
    Write-Warn2 "Start-Process 失败 ($($_.Exception.Message))，请手动粘上面 URL 到浏览器。"
}
