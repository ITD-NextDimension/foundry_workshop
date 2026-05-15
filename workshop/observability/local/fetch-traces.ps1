<#
.SYNOPSIS
    把本学员 hosted agent 在共享 Foundry project 中的最近运行拉成本地 JSON，
    供 observability/local/index.html 渲染。

.DESCRIPTION
    Foundry hosted agent 每次被调用都会在 project 上产生 threads/runs/run-steps。
    本脚本通过 SP token + Foundry agents 数据平面 REST API 列出最近 N 个 thread，
    抓 runs+steps，规范化为 spans-like 结构 (与 traces.sample.json 同 schema)，
    写入 data/my-traces.json。

    全程不需要 portal、不需要 Application Insights。

    若 API 路径在你的 preview 版本下不一致，脚本会回退到 sample 数据并提示。

.PARAMETER AgentName
    要查询的 hosted agent 名（如 research-agent-stu01）。默认从 azd env 推导。

.PARAMETER Minutes
    时间窗口（分钟），默认 60。

.PARAMETER MaxThreads
    最多拉多少个 thread，默认 20。

.PARAMETER ApiVersion
    Foundry agents 数据平面 API 版本，默认 2025-05-15-preview。

.PARAMETER OutputPath
    输出 JSON 路径。默认 .\data\my-traces.json (相对脚本)。

.EXAMPLE
    .\fetch-traces.ps1 -Minutes 60

.EXAMPLE
    .\fetch-traces.ps1 -AgentName research-agent-stu07 -Minutes 180 -MaxThreads 50
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [int]$Minutes = 60,
    [int]$MaxThreads = 20,
    [string]$ApiVersion = '2025-05-15-preview',
    [string]$OutputPath = (Join-Path $PSScriptRoot 'data\my-traces.json')
)

$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Warn2 { param([string]$m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Err   { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. 读 endpoint / agent name / 拿 token
# ---------------------------------------------------------------------------
$endpoint = & azd env get-value AZURE_AI_PROJECT_ENDPOINT 2>$null
if (-not $endpoint) { throw "AZURE_AI_PROJECT_ENDPOINT 未设置。请 cd workshop\track-A 后再跑。" }

if (-not $AgentName) {
    $suffix = & azd env get-value STUDENT_SUFFIX 2>$null
    if (-not $suffix) { throw "STUDENT_SUFFIX 未设置；显式 -AgentName research-agent-stuNN" }
    $AgentName = "research-agent-$suffix"
}
Write-Info "agent=$AgentName endpoint=$endpoint window=${Minutes}min"

$token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv 2>$null
if (-not $token) { throw "无法获取 ai.azure.com token。先 az login 用学员 SP。" }
$headers = @{ Authorization = "Bearer $token" }

# ---------------------------------------------------------------------------
# 2. 列 threads (尽力而为；不同 preview 版本路径可能差异)
# ---------------------------------------------------------------------------
$since = [DateTimeOffset]::UtcNow.AddMinutes(-$Minutes)
$threadsUrl = "$endpoint/threads?api-version=$ApiVersion&limit=$MaxThreads&order=desc"

$threads = @()
try {
    $r = Invoke-RestMethod -Method GET -Uri $threadsUrl -Headers $headers -TimeoutSec 30
    if ($r -is [array]) { $threads = $r } elseif ($r.data) { $threads = $r.data } elseif ($r.value) { $threads = $r.value } else { $threads = @() }
} catch {
    Write-Warn2 "列 threads 失败 ($($_.Exception.Message))；将回退到 sample 数据。"
}

if (-not $threads -or $threads.Count -eq 0) {
    Write-Warn2 "无 thread 可用。可能原因：1) 学员还未调用过 hosted agent；2) API 路径在你的 preview 版本下不同。"
    Write-Warn2 "data/my-traces.json 不会更新；HTML 会显示 traces.sample.json。"
    return
}

# ---------------------------------------------------------------------------
# 3. 对每个 thread 拉 runs + steps，过滤本人 agent
# ---------------------------------------------------------------------------
$conversations = @()
$kpiInTokens = 0; $kpiOutTokens = 0; $failCount = 0; $okCount = 0
$durs = @()
$clusters = @{}

function Add-Cluster {
    param([string]$err, [string]$op, [string]$tool, [string]$sampleId)
    if (-not $err) { return }
    $key = "$err|$op|$tool"
    if (-not $clusters.ContainsKey($key)) {
        $clusters[$key] = [pscustomobject]@{
            error_type = $err; operation = $op; tool_name = $tool; count = 0
            sample_conversation_id = $sampleId
        }
    }
    $clusters[$key].count++
}

foreach ($t in $threads) {
    $threadId = $t.id
    if (-not $threadId) { continue }
    $createdAt = $null
    try { $createdAt = [DateTimeOffset]::FromUnixTimeSeconds([int]$t.created_at) } catch {}
    if ($createdAt -and $createdAt -lt $since) { continue }

    $runsUrl = "$endpoint/threads/$threadId/runs?api-version=$ApiVersion&limit=20&order=desc"
    $runs = @()
    try {
        $rr = Invoke-RestMethod -Method GET -Uri $runsUrl -Headers $headers -TimeoutSec 30
        if ($rr.data) { $runs = $rr.data } elseif ($rr.value) { $runs = $rr.value } else { $runs = @() }
    } catch { continue }

    foreach ($run in $runs) {
        $runAgent = if ($run.assistant_id) { $run.assistant_id } elseif ($run.agent_id) { $run.agent_id } else { $null }
        if ($runAgent -and $AgentName -and $runAgent -notlike "*$AgentName*") { continue }

        $stepsUrl = "$endpoint/threads/$threadId/runs/$($run.id)/steps?api-version=$ApiVersion&limit=50&order=asc"
        $steps = @()
        try {
            $rs = Invoke-RestMethod -Method GET -Uri $stepsUrl -Headers $headers -TimeoutSec 30
            if ($rs.data) { $steps = $rs.data } elseif ($rs.value) { $steps = $rs.value } else { $steps = @() }
        } catch {}

        $start = if ($run.started_at) { [DateTimeOffset]::FromUnixTimeSeconds([int]$run.started_at) } else { [DateTimeOffset]::UtcNow }
        $end   = if ($run.completed_at) { [DateTimeOffset]::FromUnixTimeSeconds([int]$run.completed_at) } else { [DateTimeOffset]::UtcNow }
        $durMs = [int]($end - $start).TotalMilliseconds
        $durs += $durMs
        $success = ($run.status -eq 'completed')
        if ($success) { $okCount++ } else { $failCount++ }

        $spans = @()
        $spans += [pscustomobject]@{ name = "POST /responses"; type = "request"; start = 0; duration_ms = $durMs; success = $success }
        $spans += [pscustomobject]@{ name = "invoke_agent: $AgentName"; type = "invoke_agent"; start = 5; duration_ms = ($durMs - 10); success = $success }

        $cursorMs = 30
        foreach ($s in $steps) {
            $sStart = if ($s.created_at) { [DateTimeOffset]::FromUnixTimeSeconds([int]$s.created_at) } else { $null }
            $sEnd   = if ($s.completed_at) { [DateTimeOffset]::FromUnixTimeSeconds([int]$s.completed_at) } else { $sStart }
            $sDur   = if ($sStart -and $sEnd) { [int]($sEnd - $sStart).TotalMilliseconds } else { 0 }
            $sOk    = ($s.status -eq 'completed')
            $sStartOff = if ($sStart) { [int]($sStart - $start).TotalMilliseconds } else { $cursorMs }

            if ($s.step_details -and $s.step_details.tool_calls) {
                foreach ($tc in $s.step_details.tool_calls) {
                    $toolName = if ($tc.type) { $tc.type } else { 'unknown' }
                    if ($tc.function -and $tc.function.name) { $toolName = $tc.function.name }
                    $spans += [pscustomobject]@{
                        name = "execute_tool: $toolName"; type = "execute_tool"
                        start = $sStartOff; duration_ms = $sDur; success = $sOk
                        tool_name = $toolName
                    }
                    if (-not $sOk) { Add-Cluster -err 'tool_error' -op 'execute_tool' -tool $toolName -sampleId $threadId }
                }
            } else {
                $spans += [pscustomobject]@{
                    name = "chat: $($run.model)"; type = "chat"
                    start = $sStartOff; duration_ms = $sDur; success = $sOk
                    tokens_in  = (if ($s.usage) { [int]$s.usage.prompt_tokens } else { 0 })
                    tokens_out = (if ($s.usage) { [int]$s.usage.completion_tokens } else { 0 })
                }
                if ($s.usage) {
                    $kpiInTokens  += [int]$s.usage.prompt_tokens
                    $kpiOutTokens += [int]$s.usage.completion_tokens
                }
            }
            $cursorMs = $sStartOff + $sDur
        }

        if (-not $success) {
            Add-Cluster -err 'run_failed' -op 'invoke_agent' -tool $null -sampleId $threadId
        }

        $conversations += [pscustomobject]@{
            conversation_id = $threadId
            started_at      = $start.ToString('o')
            agent_name      = $AgentName
            success         = $success
            user_input      = ($run.metadata.user_input)
            spans           = $spans
        }
    }
}

# ---------------------------------------------------------------------------
# 4. KPI 汇总
# ---------------------------------------------------------------------------
function Percentile($arr, $p) {
    if (-not $arr -or $arr.Count -eq 0) { return 0 }
    $sorted = $arr | Sort-Object
    $idx = [math]::Min($sorted.Count - 1, [int]([math]::Ceiling($p * $sorted.Count) - 1))
    return $sorted[$idx]
}

$total = $okCount + $failCount
$result = [pscustomobject]@{
    agent_name           = $AgentName
    generated_at         = (Get-Date).ToUniversalTime().ToString('o')
    time_window_minutes  = $Minutes
    kpi = [pscustomobject]@{
        qps           = if ($Minutes -gt 0) { [math]::Round($total / ($Minutes * 60.0), 4) } else { 0 }
        p50_ms        = Percentile $durs 0.50
        p95_ms        = Percentile $durs 0.95
        p99_ms        = Percentile $durs 0.99
        failure_rate  = if ($total -gt 0) { [math]::Round($failCount / [double]$total, 3) } else { 0 }
        total_tokens  = ($kpiInTokens + $kpiOutTokens)
        input_tokens  = $kpiInTokens
        output_tokens = $kpiOutTokens
    }
    conversations    = $conversations
    failure_clusters = @($clusters.Values)
}

$json = $result | ConvertTo-Json -Depth 12
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$outDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

Write-Host ""
Write-Host "✅ 写出 $OutputPath" -ForegroundColor Green
Write-Host ("   conversations={0}  ok={1}  fail={2}  p95={3}ms" -f $conversations.Count, $okCount, $failCount, $result.kpi.p95_ms) -ForegroundColor DarkGray
Write-Host ""
Write-Host "用浏览器打开 ..\index.html，顶栏选 my-traces.json 即可查看。" -ForegroundColor Yellow
