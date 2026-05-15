# 速查卡 · KQL 与 SWA URL

> 本 workshop 不要求学员登 Azure Portal,SWA 已经把常用 KQL 包了一层 REST API。
> 本卡片提供:① SWA API 路径 ② 如果你想自己跑 KQL(高阶) 的语句。

## SWA URL 路径

| 路径 | 干嘛 | 参数 |
|------|------|------|
| `<SWA_URL>/overview` | KPI 总览 | — |
| `<SWA_URL>/failures` | 失败聚类 | `?agentName=&minutes=60` |
| `<SWA_URL>/conversation/:id` | 单条对话时间线 | `:id` 是 `gen_ai.conversation.id` |
| `<SWA_URL>/eval` | 评估分(workshop 后续延伸) | — |

## SWA API(REST)

| 端点 | 返回 |
|------|------|
| `<SWA_URL>/api/traces?agentName=&minutes=60` | 过去 N 分钟的 agent 调用样本 |
| `<SWA_URL>/api/traces/:conversationId` | 单条 conversation 的所有 span |
| `<SWA_URL>/api/failures?agentName=&minutes=60` | 失败聚类 |
| `<SWA_URL>/api/eval-scores?responseId=` | 单条响应的所有 eval 分(等 Phase 3 跑了 batch eval 才有数据) |
| `<SWA_URL>/api/agent-status?agentName=` | hosted agent 容器状态(Running/Failed) |

## 关键 GenAI OTel 字段(在 customDimensions 里)

| 字段 | 含义 |
|------|------|
| `gen_ai.operation.name` | `chat` / `invoke_agent` / `execute_tool` / `create_agent` |
| `gen_ai.conversation.id` | 会话 ID |
| `gen_ai.response.id` | **响应 ID(trace 与 eval join key)** |
| `gen_ai.agent.name` | agent 名(`requests` 上可靠;`dependencies` 上可能是子类) |
| `gen_ai.agent.id` | hosted agent `<name>:<version>` |
| `gen_ai.request.model` / `response.model` | 模型 |
| `gen_ai.usage.input_tokens` / `output_tokens` | token 用量 |
| `gen_ai.response.finish_reasons` | `["stop"]` / `["tool_calls"]` |
| `error.type` | `timeout` / `rate_limited` / `content_filter` |
| `gen_ai.tool.name` | `crm_lookup` 等 |

## 如果你想直接跑 KQL(高阶)

> 需要在 Azure Portal 里打开 App Insights → Logs。本 workshop 不强制。

### 按 conversation_id 拉完整对话

```kql
dependencies
| where timestamp > ago(24h)
| where customDimensions["gen_ai.conversation.id"] == "<conversation_id>"
| project timestamp, name, duration, resultCode, success,
    operation = tostring(customDimensions["gen_ai.operation.name"]),
    model = tostring(customDimensions["gen_ai.request.model"]),
    inputTokens = toint(customDimensions["gen_ai.usage.input_tokens"]),
    outputTokens = toint(customDimensions["gen_ai.usage.output_tokens"])
| order by timestamp asc
```

### 失败聚类(SRE 第一抓手)

```kql
dependencies
| where timestamp > ago(1h)
| where success == false or toint(resultCode) >= 400
| extend
    errorType = tostring(customDimensions["error.type"]),
    operation = tostring(customDimensions["gen_ai.operation.name"]),
    toolName = tostring(customDimensions["gen_ai.tool.name"])
| summarize count = count() by errorType, operation, toolName, resultCode
| order by count desc
```

### p50 / p95 / p99 延迟趋势

```kql
dependencies
| where timestamp > ago(24h)
| where customDimensions["gen_ai.operation.name"] == "invoke_agent"
| summarize
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99)
  by bin(timestamp, 5m), agent = tostring(customDimensions["gen_ai.agent.name"])
| render timechart
```

### Hosted agent 入口(从 requests 出发)

```kql
requests
| where timestamp > ago(24h)
| extend
    foundryAgentName = tostring(customDimensions["gen_ai.agent.name"]),
    agentVersion = tostring(split(tostring(customDimensions["gen_ai.agent.id"]), ":")[1]),
    conversationId = tostring(customDimensions["gen_ai.conversation.id"])
| where foundryAgentName == "billing-agent"
| project timestamp, conversationId, agentVersion, operation_Id, duration, success
| order by timestamp desc
```

## 离线版本:同样的数据在 echarts HTML 里怎么看

打开 `observability/offline/index.html`,顶栏切换数据源(`my-traces.json` / `failures.json` / `conversation.json`):

| 视图 | 字段映射 |
|------|---------|
| Overview KPI | 统计 `duration` p50/p95、`success=false` 占比、`gen_ai.usage.*` 求和 |
| Failures Bar | 按 `errorType` 分组,echarts bar chart |
| Conversation Timeline | echarts custom series,X 轴时间,Y 轴 span 名,色块表示成功/失败 |
