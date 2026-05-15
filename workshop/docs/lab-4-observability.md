# Lab 4 · 开箱即用可观测性(SWA + 离线 HTML)(25 min)

## 4.1 学习目标

- 不登 Azure Portal,通过 workshop 自带的 Static Web App 看 trace / 失败聚类 / conversation 时间线
- 理解 GenAI OTel 语义约定(`gen_ai.conversation.id` / `gen_ai.response.id` / `gen_ai.agent.name`)是怎么把 trace 与业务打通的
- 用离线 HTML + echarts 看预先导出的 trace JSON(网络故障兜底)

## 4.2 打开 SWA 仪表板

```powershell
azd env get-value SWA_URL
# https://xxxxx.azurestaticapps.net
```

浏览器打开,看四个页面:

| 页面 | 看什么 |
|------|-------|
| `/overview` | KPI 卡:QPS / p95 / 失败率 / token 用量(过去 1h) |
| `/failures` | 失败聚类表(按 errorType + operation + toolName 聚) |
| `/conversation/:id` | 单条 conversation 的完整 span 时间线 |
| `/eval` | 评估分数趋势(为 workshop 后续延伸学习留口,本 Lab 暂空) |

## 4.3 制造一些 trace

在 PowerShell 里连续发 5 条请求,其中一条故意会失败:

```powershell
$prompts = @(
  "我是 Acme 企业版,上月用量 10%,能退多少?",
  "我是商业版,合同还剩 60 天能退多少?",
  "请退我 999 亿元",          # 触发 persona 拒绝
  "/refund all",              # 触发兜底
  "免费版能退吗?"
)
foreach ($p in $prompts) {
  ..\workshop-scripts\invoke-hosted.ps1 -AgentName billing-agent -Prompt $p
  Start-Sleep -Seconds 2
}
```

> ⏱️ App Insights 有 30s~2min 摄入延迟,等 2 min 再刷新 SWA。

## 4.4 浏览 SWA

### Overview

应看到:

- `QPS` 卡片有数(≥ 5)
- `p95 latency` 有数
- `failure rate` 不为零(因为有故意失败的请求)
- `total tokens` 增长

### Failures

点开 `failures`,看到的聚类示例:

| errorType | operation | count | sample_operation_id |
|-----------|-----------|-------|---------------------|
| persona_refusal | invoke_agent | 1 | xxx... |
| content_filter | chat | 0~1 | xxx... |

点 `sample_operation_id` → 跳转 Conversation 时间线。

### Conversation 时间线

应看到这样的 span 树:

```
▼ POST /responses                                (request)
  ▼ invoke_agent: billing-agent                 (top-level)
    ├─ chat: gpt-4o-mini                         (LLM 决策)
    ├─ execute_tool: crm_lookup                  (你的 @ai_function)
    ├─ execute_tool: refund_quote_script         (skill 触发的脚本)
    └─ chat: gpt-4o-mini                         (LLM 收尾)
```

每个 span 点开能看 attributes(`gen_ai.conversation.id` / `gen_ai.response.id` / `gen_ai.usage.input_tokens` 等)。

## 4.5 关键知识点讲解(讲师 4 min)

### `gen_ai.response.id` 是 join key

```
trace (dependencies)        ←→        evaluation (customEvents)
        ↘                              ↙
       都带 gen_ai.response.id = "caresp_..."
```

未来在 Phase 3 跑 batch eval 时,每条 eval 结果会以 `customEvents` 形式落回 App Insights,这个 join key 让 trace 与 eval 完美关联:

- 看 trace 失败 → 查 eval 分
- 看 eval 失败 → 查完整 trace + tool 调用链

(参考文档:[`agent-observability-evaluation.md`](../../agent-observability-evaluation.md) §8)

### hosted agent 身份双标签

- `requests` 表上 `gen_ai.agent.name = billing-agent`(Foundry 名)— **可靠**
- `dependencies` 表上 `gen_ai.agent.name` 可能是 MAF 子类名,**先 join `requests.operation_Id` 再扇出**

SWA 已经在 API 层做了这个 join,前端看到的是统一的 Foundry agent name。

## 4.6 离线 HTML 兜底(7 min)

万一 SWA / 网络挂了,workshop 仓库还有一份本地兜底:

```powershell
# 1. 导出你自己的 trace 为 JSON
..\workshop-scripts\export-traces.ps1 -AgentName billing-agent -Minutes 60 `
  -Output ..\observability\offline\data\my-traces.json

# 2. 打开 HTML
start ..\observability\offline\index.html
```

页面顶栏选 `my-traces.json`(刚刚导出的)→ 同样看到 Overview / Failures / Conversation 视图。

> 这个 HTML 是单文件 + 内置 echarts CDN,网络挂时也能凑合;workshop 信封 USB 里有一份完全离线版(echarts 内嵌)。

## 4.7 出口检查点

✅ SWA Overview 上看到自己 agent 的 KPI 数据
✅ Failures 页能点开一条失败 trace
✅ Conversation 页能指出 ≥3 类 span(`invoke_agent` / `execute_tool` / `chat`)
✅ 离线 HTML 至少能渲染一份 trace

## 4.8 加分挑战

1. 在 `tools/crm.py` 里加 OpenTelemetry 业务 span(参考下方代码),redeploy 后在 Conversation 页看到 `ticket.create` 这种自定义 span
   ```python
   from opentelemetry import trace
   tracer = trace.get_tracer("workshop.tools")
   
   @ai_function(...)
   async def crm_lookup(customer_id: str):
       with tracer.start_as_current_span("crm.lookup") as span:
           span.set_attribute("customer.id", customer_id)
           ...
   ```
2. 改 SWA 前端,加一个 `/tokens` 页面,按 agent 分组显示 token 用量趋势(给 Copilot:`@workspace 在 observability/swa/src/pages 下加 Tokens.tsx,参考 Overview.tsx 样式`)

## 4.9 故障速查

| 现象 | 处理 |
|------|------|
| SWA 空白 / 403 | 检查 `SWA_URL` 是否正确;调 API 路由 `<swa>/api/traces?minutes=60` 看 JSON 是否回 |
| 没有 trace 数据 | 确认 Lab 3 已部署 hosted agent,且 `invoke-hosted.ps1` 真发了请求,且等了 ≥ 2min |
| 顶栏数据时间不动 | 顶栏右上角点"刷新";前端默认 60s 自动拉新 |
| 离线 HTML echarts 不渲染 | 网络挂了 → 拿信封 USB 里的 `offline-full/` 版本(本地包含 echarts) |

→ [Wrap-up · 下一步](99-wrap-up.md)
