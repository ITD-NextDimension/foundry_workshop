# Cloud-based Agent Harness 可观测性与评估方案

> **场景**:Phase 2 的 agent harness(`agent-harness-architecture.md`)已经按目录约定部署上线。本文回答:**怎么知道它跑得好不好,怎么持续提升质量,怎么三角色协同**?
> **配套文档**:
> - Phase 1 [`azd-foundry-research.md`](./azd-foundry-research.md) — provision
> - Phase 2 [`agent-harness-architecture.md`](./agent-harness-architecture.md) — harness 架构
> **贯穿示例**:**企业客户支持 agent harness**(TriageAgent → TechSupportAgent / BillingAgent / KBAgent)

---

## 0. TL;DR

**一句话**:可观测性 + 评估 = **三大数据面**(Telemetry / Evaluation / Correlation)+ **Foundry Flywheel**(Production → Trace → Harvest → Curate → Dataset → Eval → Compare → Deploy)+ **三角色工作流**(Dev 改完跑 P0;Manager 看趋势;SRE 盯告警)。

**数据面架构**:

```
┌──────────────────────────────────────────────────────────────────────┐
│  L4 角色入口   Dev: agentdev + 本地 eval 循环                         │
│                Manager: Foundry portal 趋势/对比/回归仪表板          │
│                SRE: KQL alert rules + Container 健康 + on-call        │
├──────────────────────────────────────────────────────────────────────┤
│  L3 关联层    response_id / conversation_id 作主键                    │
│              eval scores ↔ trace spans 互跳                          │
├─────────────────────────────────┬────────────────────────────────────┤
│  L2a Telemetry(App Insights)  │  L2b Evaluation(Foundry MCP)      │
│  ─ requests(hosted-agent 入口) │  ─ evaluator_catalog_*             │
│  ─ dependencies(LLM/tool 调用) │  ─ evaluation_agent_batch_eval_create│
│  ─ customEvents(评估结果)      │  ─ evaluation_dataset_*            │
│  ─ traces(GenAI 事件)          │  ─ evaluation_comparison_create     │
│  ─ exceptions(stack trace)     │  ─ prompt_optimize                  │
├─────────────────────────────────┴────────────────────────────────────┤
│  L1 埋点层    GenAI OTel 语义约定(Foundry agentserver 自动注入)      │
│              + MAF 客户端埋点(@ai_function / handoff 业务 span)      │
└──────────────────────────────────────────────────────────────────────┘
```

**三角色速查**:

| 角色 | 核心工具 | 看什么 | 改什么 |
|------|---------|--------|--------|
| **Dev** | `agentdev` + `evaluation_agent_batch_eval_create` + `prompt_optimize` | P0 smoke 分、失败案例 trace 详情 | persona / skill / tool / instructions |
| **Manager** | Foundry portal Evaluations / `evaluation_comparison_create` | 评估趋势、版本回归、SLO 达成率 | 排期、目标分、阈值 |
| **SRE** | App Insights Alert Rules + `agent_container_status_get` + KQL | 失败率、p95 延迟、容器状态、token 成本 | 副本数、超时、回滚到上一版本 |

---

## 1. 调研目标与贯穿例

### 1.1 目标问题

| 角色 | 问题 |
|------|------|
| Dev | "我刚改了 BillingAgent 的 persona,质量是涨还是跌?哪条具体响应不对?" |
| Manager | "本周 v3 比上周 v2 的 task_adherence 怎么样?有没有回归?" |
| SRE | "前 10 分钟客户支持失败率突然涨到 8%,先看哪儿?" |

本文回答这三类问题的**数据来源**、**查询路径**、**响应工作流**。

### 1.2 贯穿例数据切面

| 数据点 | 出现位置 | 用法 |
|--------|---------|------|
| `gen_ai.agent.name = triage-agent-prod` | `requests`.customDimensions | 按 agent 过滤 |
| `gen_ai.conversation.id = conv_abc` | 所有表 | 同一对话所有 span 汇总 |
| `gen_ai.response.id = caresp_xyz` | `dependencies` + `customEvents` | **关联 trace 与 eval 的主键** |
| `evaluator: behavioral_adherence, score: 2.0` | `customEvents` | 该响应被 LLM judge 判定为不达标 |

---

## 2. 总体架构

### 2.1 三层数据面

| 层 | 提供方 | 存哪 | 主要消费者 |
|----|--------|------|-----------|
| **Telemetry** | hosted-agent runtime + MAF 客户端埋点 | Application Insights(`requests` / `dependencies` / `customEvents` / `traces` / `exceptions`) | Dev / SRE |
| **Evaluation** | Foundry control plane | Foundry project(eval runs / datasets / evaluators) | Dev / Manager |
| **Correlation** | OTel `gen_ai.response.id` / `gen_ai.conversation.id` | 同时落在 trace `dependencies` 与 eval `customEvents` | 三角色都用 |

### 2.2 数据流

```
[Hosted Agent 容器] ──OTel──→ App Insights ───────┐
       │                                          │ KQL
       │ 业务事件                                  ▼
       └─ traces / customEvents ──→  [Dev / SRE 查询]
       │
       │ response_id
       ▼
[Foundry batch eval(MCP)] ──customEvents──→ App Insights
       │
       │ 评估分
       ▼
[Foundry portal] ←─ trending / comparison ─→ [Manager 仪表板]
       │
       │ 失败聚类 → prompt_optimize
       ▼
[新版 agent_update] ──→ [redeploy]
```

### 2.3 与 Phase 2 目录的对齐

```text
support-agent-harness/
├── .foundry/                              # ★ Phase 3 主战场
│   ├── agent-metadata.yaml                # observability + testCases 配置
│   ├── datasets/                          # seed/traces/curated/prod 四类
│   ├── evaluators/                        # built-in 引用 + 自定义 YAML
│   └── results/                           # 评估结果 + 失败聚类
├── .github/workflows/                     # ★ Phase 3 CI/CD
│   ├── agent-eval.yml                     # PR P0 门禁
│   └── agent-eval-scheduled.yml           # nightly P0+P1 回归
└── (Phase 2 其它目录不变)
```

---

## 3. Telemetry 接入

### 3.1 默认开启 App Insights

Phase 1 用的 `azd-ai-starter-basic` 模板默认 `ENABLE_MONITORING=true`,会创建 Application Insights + Log Analytics,并把 connection string 注入到 hosted agent 容器:

```bash
azd env get-value APPLICATIONINSIGHTS_CONNECTION_STRING
```

hosted-agent runtime(`azure-ai-agentserver-agentframework` 适配器)会**自动**用这个 connection string 启动 OpenTelemetry exporter,无需写代码。

### 3.2 在 `agent-metadata.yaml` 中固化 observability

```yaml
defaultEnvironment: prod
environments:
  prod:
    projectEndpoint: https://contoso.services.ai.azure.com/api/projects/support-prod
    agentName: triage-agent-prod
    observability:
      applicationInsightsResourceId: /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/components/support-prod-ai
      applicationInsightsConnectionString: InstrumentationKey=...;IngestionEndpoint=...
    testCases: [ ... ]   # 见 §7.2
```

这一段是 Phase 3 所有 trace / eval 工作流的**默认入参**——观测/评估的 skill 会优先从这里读出。

### 3.3 GenAI OTel 语义约定(关键属性)

存在 `dependencies` 表的 `customDimensions` 里:

| 属性 | 含义 | 例 |
|------|------|---|
| `gen_ai.operation.name` | 操作类型 | `chat` / `invoke_agent` / `execute_tool` / `create_agent` |
| `gen_ai.conversation.id` | 会话 ID | `conv_5j66...` |
| `gen_ai.response.id` | **响应 ID(关联主键)** | hosted agent `caresp_...` / prompt agent `resp_...` / Azure OpenAI `chatcmpl-...` |
| `gen_ai.agent.name` | agent 名(`requests` 上是 Foundry 名;`dependencies` 上可能是 sub-agent 类名) | `triage-agent-prod` |
| `gen_ai.agent.id` | hosted agent 还会带 `<name>:<version>` | `triage-agent-prod:3` |
| `gen_ai.request.model` / `gen_ai.response.model` | 模型 | `gpt-4o` / `gpt-4o-2024-05-13` |
| `gen_ai.usage.input_tokens` / `output_tokens` | token 用量(成本核算) | `450` / `120` |
| `gen_ai.response.finish_reasons` | 结束原因 | `["stop"]` / `["tool_calls"]` |
| `error.type` | 错误分类 | `timeout` / `rate_limited` / `content_filter` |
| `gen_ai.tool.name` | tool 名(execute_tool span 上) | `crm_lookup` |

> ⚠️ **hosted agent 身份规则**:Foundry agent 名只在 `requests` 表上可靠;`dependencies` 上的 `gen_ai.agent.name` 可能是子类(例如 `TechSupportAgent`)。**总是先用 `requests` 筛 Foundry 名,拿 `operation_Id` 再 join `dependencies`**。

### 3.4 MAF 客户端埋点(业务级 span)

OTel 自动埋点只覆盖 LLM 调用与 tool execute。**业务级 span**(创建工单、退款审核)需要自己加:

```python
# tools/ticketing.py
from agent_framework import ai_function
from opentelemetry import trace

tracer = trace.get_tracer("support-harness.tools")

@ai_function(name="create_ticket", description="为客户创建工单")
async def create_ticket(customer_id: str, category: str, summary: str) -> str:
    with tracer.start_as_current_span("ticket.create") as span:
        span.set_attribute("ticket.customer_id", customer_id)
        span.set_attribute("ticket.category", category)
        ticket_id = await _internal.create(customer_id, category, summary)
        span.set_attribute("ticket.id", ticket_id)
        return ticket_id
```

这些自定义属性也会进 `dependencies.customDimensions`,可以在 KQL 里直接 `extend ticketId = tostring(customDimensions["ticket.id"])`。

**handoff 也要埋**:`handoff_to_tech(...)` 函数里加 span `subagent.handoff`,属性 `from=triage`、`to=tech-support`、`reason=...`,Manager 仪表板就能看到子 agent 之间的路由分布。

### 3.5 PII 防泄露

OTel 默认会把 `gen_ai.input.messages` / `gen_ai.output.messages` 完整落库。生产环境应:

- 在 `azure.ai.agentserver` 适配器层配置 `OTEL_GENAI_CAPTURE_MESSAGE_CONTENT=false`,或
- 自定义 `SpanProcessor` 在导出前 redact 敏感字段,或
- 在 App Insights 端用 Log Filter Function 删除字段(成本最高)

### 3.6 贯穿示例

`agent-metadata.yaml` 写好 `observability` 段后,所有后续 `trace` / `observe` skill 自动读取;`tools/ticketing.py` 加 `ticket.id` span 属性后,SRE 在 P0 失败聚类后能直接 join 工单系统反查影响面。

---

## 4. Trace 工作流(Dev + SRE 共用)

### 4.1 基础查询入口

> **总是先显示 KQL,再执行**;**总是带时间窗**(默认 24h)。

#### 4.1.1 按 conversation_id 拉一条对话所有 span

```kql
dependencies
| where timestamp > ago(24h)
| where customDimensions["gen_ai.conversation.id"] == "<conversation_id>"
| project timestamp, name, duration, resultCode, success,
    operation = tostring(customDimensions["gen_ai.operation.name"]),
    model = tostring(customDimensions["gen_ai.request.model"]),
    inputTokens = toint(customDimensions["gen_ai.usage.input_tokens"]),
    outputTokens = toint(customDimensions["gen_ai.usage.output_tokens"]),
    operation_Id, id, operation_ParentId
| order by timestamp asc
```

#### 4.1.2 按 response_id 找到对应 trace(再扇出整个对话)

```kql
let target = dependencies
| where timestamp > ago(24h)
| where customDimensions["gen_ai.response.id"] == "<response_id>"
| project operation_Id;
dependencies
| where operation_Id in (target)
| order by timestamp asc
```

#### 4.1.3 Foundry hosted-agent 入口(从 requests 出发)

```kql
let agentRequests = materialize(
    requests
    | where timestamp > ago(24h)
    | extend
        foundryAgentName = coalesce(
            tostring(customDimensions["gen_ai.agent.name"]),
            tostring(customDimensions["azure.ai.agentserver.agent_name"])),
        agentId = tostring(customDimensions["gen_ai.agent.id"]),
        agentVersion = iff(agentId contains ":", tostring(split(agentId, ":")[1]), ""),
        conversationId = coalesce(
            tostring(customDimensions["gen_ai.conversation.id"]),
            tostring(customDimensions["azure.ai.agentserver.conversation_id"]),
            operation_Id)
    | where foundryAgentName == "triage-agent-prod"
);
agentRequests
| project timestamp, conversationId, agentVersion, operation_Id, duration, success
| order by timestamp desc
```

### 4.2 失败聚类(SRE 第一抓手)

```kql
dependencies
| where timestamp > ago(1h)
| where success == false or toint(resultCode) >= 400
| extend
    errorType = tostring(customDimensions["error.type"]),
    operation = tostring(customDimensions["gen_ai.operation.name"]),
    toolName = tostring(customDimensions["gen_ai.tool.name"])
| summarize
    count = count(),
    firstSeen = min(timestamp),
    lastSeen = max(timestamp),
    avgDuration = avg(duration),
    sampleOperationId = take_any(operation_Id)
  by errorType, operation, toolName, resultCode
| order by count desc
```

输出后按 P0/P1/P2 排序:

| Priority | Error | Operation | Count | resultCode | 建议 |
|----------|-------|-----------|-------|-----------|------|
| P0 | `timeout` | `invoke_agent` | 15 | 504 | 看容器健康、加超时;若 MCP 端 → 服务端拆任务 |
| P1 | `rate_limited` | `chat` | 8 | 429 | 检查模型配额,加退避重试 |
| P2 | `content_filter` | `chat` | 5 | 400 | 重审 prompt 是否触发策略 |
| P3 | `tool_error` | `execute_tool` | 3 | 500 | 看 tool 实现 + 权限(`tools/*.py`) |

### 4.3 延迟分析

```kql
dependencies
| where timestamp > ago(24h)
| where customDimensions["gen_ai.operation.name"] == "invoke_agent"
| summarize
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99),
    count = count()
  by bin(timestamp, 5m),
     agent = tostring(customDimensions["gen_ai.agent.name"])
| render timechart
```

延迟尖刺定位:从 p95 跳变的 5 分钟窗口取 sample `operation_Id`,跑 4.1.1/4.1.3 看完整 span tree,找出哪段(`chat` / `execute_tool` / 子 agent `invoke_agent`)异常变慢。

### 4.4 容器健康(SRE)

```kql
// 平均 RU(replica utilization)
requests
| where timestamp > ago(15m)
| where name startswith "POST /responses"
| extend agent = tostring(customDimensions["gen_ai.agent.name"])
| summarize qps = count() / 900.0, p95 = percentile(duration, 95) by agent
```

配合 Foundry MCP `agent_container_status_get` 看副本状态(`Starting` / `Running` / `Stopped` / `Failed`)。

### 4.5 贯穿示例(SRE 突发告警)

告警触发:过去 5 分钟 BillingAgent 失败率 > 5%。
1. 跑 §4.2,看到 P0 `timeout` 集中在 `execute_tool / pricing-rules-mcp`
2. 取 sample `operation_Id`,§4.1.1 拉完整对话,发现 MCP server 端在 95s 处超时
3. Foundry MCP server 100s 上限触发,`agent_update` 把 BillingAgent 切回 v2(上版本未引入该 MCP),先止血
4. 跟 MCP server owner 改成异步任务模式

---

## 5. Evaluators

### 5.1 Built-in 评估器清单

| Evaluator | 维度 | 适用 | 用法 |
|-----------|------|------|------|
| `relevance` | Quality | 答与问相关 | 通用 |
| `task_adherence` | Quality | 完成了用户实际任务 | 多步 agent |
| `intent_resolution` | Quality | 理解了用户意图 | 路由 / triage |
| `coherence` | Quality | 表达连贯 | 长输出 |
| `fluency` | Quality | 语言自然 | 多语言 |
| `groundedness` | Quality | 有上下文/引用支撑 | RAG |
| `builtin.tool_call_accuracy` | Tool use | tool 选对、参数对、顺序对 | 用 tool 的 agent ★ |
| `indirect_attack` | Safety | 抗 prompt injection | 必含 |
| `violence` / `self_harm` / `sexual` / `hate_unfairness` | Safety | RAI 内容审查 | 所有面向 C 端 |

> ⚠️ **LLM judge 知识截止陷阱**:`groundedness` 这种基于事实的评估器,对于实时数据(Bing / Web Search)会假阳性(把真实事实判定为"超出知识");自定义评估器 prompt 要写"接受来源标注但你无法验证的事实"。

### 5.2 Two-Phase 策略

| 阶段 | 何时 | 评估器 | 数据集字段 |
|------|------|-------|----------|
| **Phase 1** 基线 | 首次部署后立刻 | ≤5 个 built-in:`relevance`, `task_adherence`, `intent_resolution`, `indirect_attack`,**有 tool 时加** `builtin.tool_call_accuracy` | `query` + `expected_behavior`(后者给 Phase 2 留口) |
| **Phase 2** 定向 | 分析 Phase 1 失败后 | 先 `evaluator_catalog_get` 查现有 custom;无覆盖时再 `evaluator_catalog_create` | 复用 `expected_behavior` 作每行的行为标准 |

**关键**:每行 `query` 都要配 `expected_behavior`(自然语言写"理想响应应该做什么"),Phase 1 built-in 用不上但 Phase 2 直接复用,**不用重生成数据集**。

### 5.3 Phase 2 自定义 evaluator YAML 例子

#### 5.3.1 `behavioral_adherence` — 基于 `expected_behavior` 的行为符合度

```yaml
# .foundry/evaluators/behavioral-adherence.yaml
name: behavioral_adherence
version: v1
type: prompt
promptText: |
  Given the user query, the agent response, and a per-query rubric
  describing what an ideal response should do, rate adherence on 1-5.

  ## Query
  {{query}}

  ## Response
  {{response}}

  ## Expected Behavior
  {{expected_behavior}}

  ## Scoring
  5 = fully addresses every requirement in Expected Behavior
  4 = addresses all major requirements, minor gaps
  3 = addresses some requirements, notable gaps
  2 = mostly off-target
  1 = irrelevant or refused without cause

  Output JSON: {"score": <int>, "explanation": "<one sentence>"}.
  If a claim is sourced (e.g., "[1]" or "(source: ...)") but you cannot
  verify the underlying fact, accept the claim — do NOT score down for
  facts beyond your knowledge.
```

#### 5.3.2 `citation_quality` — 引用质量(用于 KBAgent)

```yaml
name: citation_quality
version: v1
type: prompt
promptText: |
  Score the response's citation quality on 0-1.

  ## Response
  {{response}}

  ## Retrieved Context
  {{context}}

  ## Rules
  - Every factual claim in Response must have a citation marker like [n]
    or (source: file.md#section)
  - Citation must point to a passage in Retrieved Context that supports
    the claim
  - Score = (supported_claims / total_claims) when total_claims > 0,
    else 1.0 if Response is non-factual chitchat

  Output JSON: {"score": <float 0-1>, "explanation": "<details>"}
```

#### 5.3.3 `refund_policy_adherence` — 业务规则评估器(BillingAgent 专用)

```yaml
name: refund_policy_adherence
version: v1
type: prompt
promptText: |
  Contoso refund policy v3.2:
  - Tier=Enterprise: pro-rata refund within 30 days, max 50% of contract value
  - Tier=Business: pro-rata refund within 14 days, max 25%
  - Tier=Free: no refund

  Given the customer query (which mentions tier) and the agent response,
  determine if the response conforms to policy.

  ## Query
  {{query}}

  ## Response
  {{response}}

  ## Expected Behavior
  {{expected_behavior}}

  Output JSON:
  {
    "score": 0 | 1,
    "violation": "<none|cited-wrong-tier|exceeded-cap|missed-window|other>",
    "explanation": "<one sentence>"
  }

  Reasoning: even if the response is friendly, score 0 if it promises a
  refund that violates the policy above.
```

> 💡 **判官模型选型**:`deploymentName` 用 `gpt-4o` 或 `gpt-4.1`(强一些的判官);**不要用同一个被评估模型**(防止系统性偏差)。

### 5.4 阈值建议

| 维度 | P0(必过) | P1(回归监控) | P2(参考) |
|------|----------|--------------|-----------|
| `relevance`(1-5) | ≥ 4 | ≥ 4 | ≥ 3 |
| `task_adherence` | ≥ 4 | ≥ 4 | ≥ 3 |
| `intent_resolution`(triage) | ≥ 4 | — | — |
| `behavioral_adherence` | ≥ 4 | ≥ 4 | ≥ 3 |
| `citation_quality`(0-1) | ≥ 0.9 | ≥ 0.85 | ≥ 0.7 |
| `refund_policy_adherence` | == 1 | == 1 | == 1 |
| `indirect_attack` | == 0(0=安全) | == 0 | == 0 |
| `violence` / `self_harm` / 等 | ≤ 1(Foundry RAI 0-7) | ≤ 1 | ≤ 1 |

> **关键不变量**:**安全类阈值不能因为分数压力而放宽**;**业务规则评估器(refund 这类)P0 必须 100%**。

### 5.5 贯穿示例

BillingAgent 上 `behavioral_adherence` + `refund_policy_adherence` + `citation_quality`;TechSupportAgent 上 `behavioral_adherence` + `tool_call_accuracy`;TriageAgent 上 `intent_resolution`(分类是否正确)+ `behavioral_adherence`。

---

## 6. Datasets

### 6.1 四类数据集

| 类型 | Foundry 数据集名 | Version | 本地文件 | 来源 |
|------|----------------|---------|---------|------|
| seed | `<agent>-eval-seed` | `v1` | `.foundry/datasets/<agent>-eval-seed-v1.jsonl` | LLM 合成 |
| traces | `<agent>-traces` | `v<N>` | `.foundry/datasets/<agent>-traces-v<N>.jsonl` | 生产 trace 抽取 |
| curated | `<agent>-curated` | `v<N>` | `...-curated-v<N>.jsonl` | traces 人审过 |
| prod | `<agent>-prod` | `v<N>` | `...-prod-v<N>.jsonl` | 上线门禁基准 |

> 文件名前缀 = `agentName`(Phase 2 §8.2 命名约定);如果 agentName 已含环境(`billing-agent-dev`),**不要重复**追加 env。

### 6.2 JSONL 行结构(每行一个测试用例)

```json
{
  "id": "billing-001",
  "query": "我是 Acme 企业版客户,上月用量只有 10% 还能退多少?",
  "expected_behavior": "应按 Enterprise tier 计算 pro-rata 退款,提及 30 天窗口与 50% 上限,引用合同条款。不应直接承诺具体金额。",
  "context": "Customer tier: Enterprise; usage: 10%; days since contract start: 15",
  "ground_truth": null,
  "tags": ["billing", "refund", "enterprise"]
}
```

字段必备:`query` + `expected_behavior`(其它可选)。

### 6.3 Trace-to-Dataset 流水线

```
[1] 用 KQL 从 App Insights 抽 24h 内的对话样本
[2] 排除 PII / 内部测试帐号
[3] 用 expected_behavior 自动生成(LLM)初稿
[4] ★ 人工审 / 改 expected_behavior(强制)
[5] 写入 .foundry/datasets/<agent>-traces-v<N>.jsonl
[6] evaluation_dataset_create 注册到 Foundry
[7] 在 agent-metadata.yaml 的 testCases[] 加引用
```

KQL 抽取例:

```kql
let target = "billing-agent-prod";
let agentRequests = requests
| where timestamp > ago(7d)
| where customDimensions["gen_ai.agent.name"] == target
| project operation_Id, conversationId = tostring(customDimensions["gen_ai.conversation.id"]);
dependencies
| where operation_Id in (agentRequests | project operation_Id)
| where customDimensions["gen_ai.operation.name"] == "invoke_agent"
| extend
    query = tostring(parse_json(tostring(customDimensions["gen_ai.input.messages"]))[0].parts[0].content),
    response = tostring(parse_json(tostring(customDimensions["gen_ai.output.messages"]))[0].parts[0].content),
    responseId = tostring(customDimensions["gen_ai.response.id"])
| project query, response, responseId, conversationId = tostring(customDimensions["gen_ai.conversation.id"])
| take 100
```

> ⚠️ **人审强制**:不要直接 commit 自动抽取结果。展示候选给业务方,审完才进 dataset。

### 6.4 版本化 + lineage

`.foundry/datasets/manifest.json` 记每个数据集 → 上次同步、相邻 eval 运行、对应 agent 版本:

```json
{
  "billing-agent-prod-traces": {
    "currentVersion": "v3",
    "files": {
      "v3": {
        "path": ".foundry/datasets/billing-agent-prod-traces-v3.jsonl",
        "rows": 178,
        "datasetUri": "azureml://.../datasets/billing-agent-prod-traces/versions/v3",
        "createdAt": "2026-04-22T10:00:00Z",
        "harvestedFromTraceRange": ["2026-04-15T00:00:00Z", "2026-04-22T00:00:00Z"],
        "evalRuns": ["eval-run-abc", "eval-run-def"]
      }
    }
  }
}
```

### 6.5 关键守则

- 同一数据集名跨版本**只加不删**(`billing-agent-traces` 永远是它);版本进 `datasetVersion` 字段
- 分数掉了**不要删行/调评估器**回补,先优化 agent
- 同一份 dataset 给所有版本对比,这样 v3 vs v4 才公平

### 6.6 贯穿示例

BillingAgent 每周 nightly 跑 trace harvest,人审通过的 30 行进 `billing-agent-prod-traces-v4`;`agent-metadata.yaml` 加 `testCases[2]` 用这份数据集 + `refund_policy_adherence` + 阈值 1。

---

## 7. Batch Evaluation

### 7.1 MCP 调用

```python
# 概念性伪代码
evaluation_agent_batch_eval_create(
    projectEndpoint="https://contoso.services.ai.azure.com/api/projects/support-prod",
    agentName="billing-agent-prod",
    agentVersion="3",
    evaluatorNames=[
        "relevance", "task_adherence", "indirect_attack",
        "builtin.tool_call_accuracy",
        "behavioral_adherence", "refund_policy_adherence",
    ],
    inputData=<read .foundry/datasets/billing-agent-prod-curated-v2.jsonl>,
    deploymentName="gpt-4o",                  # judge 模型
    evaluationId="<existing-group-id-or-new>",# 同组才能对比
    evaluationName="billing-prod-v3-smoke-2026-04-22",
)
```

### 7.2 `testCases[]` 组织

在 `agent-metadata.yaml`:

```yaml
environments:
  prod:
    testCases:
      - id: smoke-core                       # ★ P0 — PR 门禁
        priority: P0
        dataset: billing-agent-prod-eval-seed
        datasetVersion: v1
        datasetFile: .foundry/datasets/billing-agent-prod-eval-seed-v1.jsonl
        datasetUri: azureml://.../datasets/billing-agent-prod-eval-seed/versions/v1
        evaluators:
          - { name: relevance, threshold: 4 }
          - { name: indirect_attack, threshold: 0 }
          - { name: refund_policy_adherence, threshold: 1, definitionFile: .foundry/evaluators/refund-policy-adherence.yaml }

      - id: trace-regressions                # ★ P1 — nightly
        priority: P1
        dataset: billing-agent-prod-traces
        datasetVersion: v4
        datasetFile: .foundry/datasets/billing-agent-prod-traces-v4.jsonl
        datasetUri: azureml://.../datasets/billing-agent-prod-traces/versions/v4
        evaluators:
          - { name: task_adherence, threshold: 4 }
          - { name: behavioral_adherence, threshold: 4, definitionFile: .foundry/evaluators/behavioral-adherence.yaml }
          - { name: citation_quality, threshold: 0.9, definitionFile: .foundry/evaluators/citation-quality.yaml }

      - id: broad-quality                    # ★ P2 — weekly
        priority: P2
        dataset: billing-agent-prod-curated
        datasetVersion: v2
        datasetFile: .foundry/datasets/billing-agent-prod-curated-v2.jsonl
        evaluators:
          - { name: relevance, threshold: 3 }
          - { name: task_adherence, threshold: 3 }
          - { name: coherence, threshold: 3 }
          - { name: fluency, threshold: 3 }
          - { name: behavioral_adherence, threshold: 3 }
```

### 7.3 三档门禁

| 优先级 | 跑的时机 | 评估器组 | Gate 行为 |
|--------|---------|----------|----------|
| **P0** | 每次 PR + 每次 deploy | 安全(`indirect_attack`、RAI)+ 业务硬规则(`refund_policy_adherence`)+ `relevance` | **任何一项不过 → 阻止 merge / 阻止 deploy** |
| **P1** | nightly | trace-harvested 数据集 + `task_adherence` / `behavioral_adherence` | 任何回归 → 自动开 issue,标记 P1 |
| **P2** | weekly | 全量 curated + 所有评估器 | 用于 trending,不阻塞 |

### 7.4 关键参数命名陷阱

| 工具 | 用 `evaluationId` | 用 `evalId` |
|------|------------------|-------------|
| `evaluation_agent_batch_eval_create` | ✅(声明组) | ❌ |
| `evaluation_get` | ❌ | ✅(`isRequestForRuns=true` 列组内所有 run) |
| `evaluation_comparison_create` | ❌ | ✅(在 `insightRequest.request.evalId`) |

> **同组(evaluationId)不可变**:评估器列表或阈值变了,**必须开新组**,不能往老组里塞。

### 7.5 贯穿示例

PR #128 改 BillingAgent 的 persona;CI 触发 P0:`smoke-core` 数据集 + 上面 3 个评估器跑过 → 部署到 prod;nightly 拿同一 `evaluationId` 跑 `trace-regressions`,把 v3 与 v2 的 run 都在一组,Manager 仪表板看 task_adherence 4.2 → 4.4 涨了 5%。

---

## 8. Trace × Eval 关联(本文核心)

### 8.1 主键:`response_id`

Foundry batch eval 跑完后,**每条评估结果都会以 `customEvents` 的形式回写到 App Insights**,字段 `gen_ai.response.id` 与 agent 响应当时的 trace 共享,从而:

| 起点 | 终点 | 怎么跳 |
|------|------|--------|
| 我看到一条 trace 失败 → 想知道这条被评估为多少分 | 评估分 | KQL `customEvents` where `gen_ai.response.id == <id>` |
| 我看到一条 eval 失败案例 → 想知道当时上下文/工具调用链 | 完整 trace | KQL `dependencies` where `gen_ai.response.id == <id>` |
| 我想统计某次 eval run 里所有 P0 失败行的 trace | 所有 trace | 先把失败行的 responseId 拉出,再批量 join |

### 8.2 拉单条响应的所有评估分

```kql
customEvents
| where timestamp > ago(30d)
| where name == "gen_ai.evaluation.result"
| where customDimensions["gen_ai.response.id"] == "caresp_xyz"
| extend
    evalName = tostring(customDimensions["gen_ai.evaluation.name"]),
    score = todouble(customDimensions["gen_ai.evaluation.score.value"]),
    label = tostring(customDimensions["gen_ai.evaluation.score.label"]),
    explanation = tostring(customDimensions["gen_ai.evaluation.explanation"])
| project timestamp, evalName, score, label, explanation
| order by evalName asc
```

输出示例:

| evaluator | score | label | explanation |
|-----------|-------|-------|-------------|
| relevance | 4.0 | pass | Addresses the refund question... |
| refund_policy_adherence | 0 | fail | Promised 60% refund, exceeds 50% cap for Enterprise tier |
| behavioral_adherence | 2.0 | fail | Did not cite policy section |

### 8.3 拉单条响应的所有 span(再附评估分)

```kql
let evalScores = customEvents
| where timestamp > ago(30d)
| where name == "gen_ai.evaluation.result"
| where customDimensions["gen_ai.response.id"] == "caresp_xyz"
| project
    evalName = tostring(customDimensions["gen_ai.evaluation.name"]),
    score = todouble(customDimensions["gen_ai.evaluation.score.value"]);
dependencies
| where timestamp > ago(30d)
| where customDimensions["gen_ai.response.id"] == "caresp_xyz"
| project timestamp, name, duration, success,
    operation = tostring(customDimensions["gen_ai.operation.name"]),
    toolName = tostring(customDimensions["gen_ai.tool.name"]),
    spanId = id, parentId = operation_ParentId
| order by timestamp asc
| extend evals = toscalar(evalScores | summarize make_bag(pack(evalName, score)))
```

### 8.4 失败案例的反向链路(eval → trace 详情)

Dev 在 `.foundry/results/<run>/failures.jsonl` 里看到某行 `refund_policy_adherence=0`:

1. 取行内 `responseId`
2. 跑 §8.3,拿到完整 span tree
3. 看到 `execute_tool: pricing-rules-mcp` 返回了错误的 tier 映射 → 锁定 root cause
4. 修 MCP server,或者改 BillingAgent 的 persona 要求双重确认 tier

### 8.5 守则

> **`gen_ai.response.id` 是这套数据系统的"join key"**。不放就废:
> - hosted agent runtime 自动注入 ✅
> - MAF 客户端埋点也要保留 ✅(在自定义 span 上 `set_attribute("gen_ai.response.id", ...)`)
> - 自建 MCP server 务必透传 ✅

---

## 9. 优化循环

> 注意:**先升级数据集再升级模型**——不要为了"分数好看"删行或弱化评估器。

### 9.1 失败聚类(Dev 第一抓手)

```bash
# 概念性脚本(放在 scripts/cluster_failures.py)
python scripts/cluster_failures.py \
    --results .foundry/results/billing-agent-prod-v3-trace-regressions/ \
    --output .foundry/results/billing-agent-prod-v3-trace-regressions/clusters.json
```

按 `evalName + 失败原因关键词`(LLM 提取)做 k-means;输出表:

| Cluster | 评估器 | 失败原因 | 样本 query | 占失败 % |
|---------|-------|---------|-----------|----------|
| C1 | refund_policy_adherence | 弄错 tier | "我是商业版,能退多少" | 38% |
| C2 | citation_quality | 未引用合同条款 | "依据是什么" | 24% |
| C3 | behavioral_adherence | 直接给具体金额 | "退我 X 元行不行" | 18% |

Dev 选一类聚焦优化。

### 9.2 `prompt_optimize`

```python
prompt_optimize(
    developerMessage=<current billing-agent persona>,
    deploymentName="gpt-4o-mini",
    projectEndpoint="...",
    requestedChanges=(
        "1) Always re-confirm customer tier before quoting refund; "
        "2) Cite policy section by name; "
        "3) Never commit to a specific currency amount, only ranges."
    ),
)
```

返回优化后的 prompt。**Dev 审核 diff,确认后再用**;**不要让 prompt_optimize 直接覆盖 persona**——把它的输出贴回 `personas/billing-agent.md`,git commit,走正常 PR 评审。

### 9.3 redeploy(版本管理)

```python
agent_update(
    projectEndpoint="...",
    agentName="billing-agent-prod",
    agentDefinition=<new definition with updated instructions>,
)
# Foundry 自动创建新版本(v4)
agent_container_control(agentName="billing-agent-prod", action="start")
# 轮询直到 Running
```

> **保留旧版本至少 1 周**,失败回滚直接 `agent_update --version v3 reactivate`。

### 9.4 版本对比

```python
evaluation_comparison_create(
    insightRequest={
        "displayName": "billing v3 vs v4 (trace-regressions)",
        "state": "NotStarted",
        "request": {
            "type": "EvaluationComparison",
            "evalId": "<eval-group-id>",     # 注意:这里是 evalId,不是 evaluationId
            "baselineRunId": "<v3-run-id>",
            "treatmentRunIds": ["<v4-run-id>"],
        }
    }
)
# 然后 evaluation_comparison_get(insightId=...)
```

输出:每个评估器 baseline vs treatment 的均值、p95、显著性提示。

### 9.5 关键决策点

```
v4 跑完比 v3:
  ├─ 全部维度 ↑                → 接受,保留 v4
  ├─ 主要目标维度 ↑,其它持平 → 接受
  ├─ 主要目标维度 ↑,但 safety ↓ → 拒绝,回到 9.1 重做
  └─ 主要目标维度 ↑,但 token 用量 ↑ 50% → 评估成本/效益,可能接受/可能否
```

### 9.6 贯穿示例

C1(tier 误判)→ `prompt_optimize` 输出加 "always confirm tier first" → persona 改完 → v4 deploy → eval comparison:`refund_policy_adherence` 0.62→0.97,但 `task_adherence` 4.4→4.2(因为每次会先反问拖慢任务) → Dev 决定加一条 "if tier is in conversation history, skip confirmation" → v5。

---

## 10. 三角色工作流

### 10.1 Dev 本地循环

```
1. 改 personas/billing-agent.md(或 skills/refund-quote/SKILL.md)
2. agentdev run src/billing_agent/main.py --port 8087
3. 本地手动跑几个 case,Agent Inspector 看 trace
4. evaluation_agent_batch_eval_create 跑 P0 smoke-core(只 10-20 行,~1 分钟)
5. P0 过 → git commit
6. P0 不过 → §8.4 反向链路定位 → 改回去
7. PR push → CI 跑 P0(.github/workflows/agent-eval.yml)
```

**Dev IDE 体验**:VS Code AI Toolkit 装好,`.foundry/datasets/*.jsonl` 直接 Open in Data Viewer 看测试用例;`.foundry/results/*` 看 score 分布。

### 10.2 Manager 趋势 + 回归

**仪表板(Foundry portal)**:
- Evaluations → 选 evaluationId → 看 run 时间序列(score over time)
- Comparison → v(n-1) vs v(n) 自动生成
- Regression → 任何评估器跌破阈值标红

**自建仪表板(可选,KQL feeding Power BI / Grafana)**:

```kql
customEvents
| where timestamp > ago(30d)
| where name == "gen_ai.evaluation.result"
| extend
    agentName = tostring(customDimensions["gen_ai.agent.name"]),
    agentVersion = tostring(customDimensions["gen_ai.agent.version"]),
    evalName = tostring(customDimensions["gen_ai.evaluation.name"]),
    score = todouble(customDimensions["gen_ai.evaluation.score.value"])
| summarize avg(score), p95 = percentile(score, 95) by bin(timestamp, 1d), agentName, evalName, agentVersion
| render timechart
```

**周会数据视角**:
- 各专科 agent 的 task_adherence 周环比
- 安全评估器是否 100% 通过(若 < 100% 拉警)
- token 成本趋势(看 `gen_ai.usage.*`)
- 用户求助量(invoke_agent 次数)

### 10.3 SRE 生产告警 + on-call

#### 告警规则(基于 App Insights Alert Rules)

| 告警 | KQL | 阈值 | Action |
|------|-----|------|--------|
| 失败率突增 | `requests \| where success == false \| summarize fr=count()/toscalar(toscalar(requests \| count)) by bin(timestamp,5m)` | > 5% 持续 2 个窗口 | PageDuty P1 |
| p95 延迟突增 | `requests \| summarize p95=percentile(duration,95) by bin(timestamp,5m)` | > 2× 历史中位 | Slack 通知 |
| 容器 Failed | Foundry MCP `agent_container_status_get` + scheduled job | status == "Failed" | PageDuty P0 |
| 评估器分数掉 | 在 nightly run 之后跑 KQL | 某评估器均值环比掉 ≥ 10% | 自动开 GitHub Issue |
| token 成本异常 | `dependencies \| summarize sumTokens=sum(toint(customDimensions["gen_ai.usage.input_tokens"])) by bin(timestamp,1h)` | > 2× 历史中位 | Slack 通知 |

#### on-call runbook(精简版)

```
Step 0: 看告警类型 → 选 §10.3 表中的 KQL 模板
Step 1: §4.2 失败聚类 → 拿到 top 错误类
Step 2: 取 sample operation_Id → §4.1 拉完整 trace
Step 3: §8.3 加 eval 分(若 eval 已跑过)
Step 4: 判断:
  - L2 模型问题(rate_limit / content_filter) → 联系 model team
  - L3 应用问题(tool / persona) → 切上版本(agent_update),开 ticket 给 dev
  - L2b MCP / 外部依赖 → 切断该 tool(env var 关) + 通知依赖方
Step 5: 故障复盘:traces → 加入 trace-harvest → 下版本评估覆盖
```

#### 容器健康监控

```bash
# 定时任务(SRE 的定时 job)
agent_container_status_get(projectEndpoint=..., agentName="billing-agent-prod")
# 若 status != "Running",触发告警 + 自动 agent_container_control(action="start")
```

---

## 11. CI/CD 集成原则

### 11.1 PR 门禁(P0)

```yaml
# .github/workflows/agent-eval.yml(原则示意)
name: agent-eval
on: [pull_request]
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      # 1. 部署 PR 版本到 dev 环境的临时 agent
      - run: azd deploy <agent>
      # 2. 跑 P0 testCase
      - run: python scripts/run_eval.py --testCase smoke-core --env dev
      # 3. 任意评估器跌破阈值 → exit 1
```

要点:
- **每个 PR 部署到 dev**(短 TTL,跑完销毁),不要直接评估 prod 版本
- **P0 用 seed dataset**(快,10-20 行,1 分钟内出结果)
- **失败时把 .foundry/results/ 上传成 artifact**,PR comment 给详情链接

### 11.2 Nightly 回归(P1)

```yaml
# .github/workflows/agent-eval-scheduled.yml
on:
  schedule: [{cron: "0 2 * * *"}]   # 02:00 UTC
jobs:
  regression:
    steps:
      - run: python scripts/run_eval.py --testCase trace-regressions --env prod
      # 若任何评估器环比掉 > 10%,自动开 issue
      - if: failure()
        run: python scripts/open_regression_issue.py
```

跑在 **prod agent 上**,数据集是 trace-harvested。

### 11.3 Weekly trace harvest + curate

```yaml
on:
  schedule: [{cron: "0 8 * * MON"}]   # 周一 08:00 UTC
jobs:
  harvest:
    steps:
      - run: python scripts/harvest_traces.py --agent billing-agent-prod --days 7
      # 输出 .foundry/datasets/billing-agent-prod-traces-v<N+1>.draft.jsonl
      - run: gh pr create --title "[harvest] billing v<N+1>" --body "需人工审 expected_behavior"
```

人工审完合并后,自动注册到 Foundry(`evaluation_dataset_create`)。

### 11.4 失败回滚

```bash
# 触发条件:nightly P1 跌破阈值 + 没有相关 PR
# SRE 操作:
agent_update --agentName billing-agent-prod --version 3 --reactivate
```

或脚本化:`scripts/rollback.py --agent <n> --to-version <v>`,告警里直接附此命令。

---

## 12. 风险与最佳实践

| 风险 | 缓解 |
|------|------|
| **LLM judge 知识截止假阳性** | 评估器 prompt 中显式写"接受来源标注但你不能验证的事实";real-time 数据评估优先看 `groundedness on retrieved context`,不要拿训练集知识对 |
| **评估漂移**(模型升级后基线失效) | 每次升级模型前,先用同一 dataset 在新旧模型上跑 baseline,记入 manifest |
| **数据集污染** | judge 模型与 agent 模型不要同款;dataset 与 production 用户输入定期去重 |
| **PII 泄露到 trace** | 默认 `OTEL_GENAI_CAPTURE_MESSAGE_CONTENT=false`;或加 SpanProcessor 在导出前 redact;App Insights 端 Data Collection Rules 兜底 |
| **同组 evaluationId 被错误重用** | 每次改 evaluators / thresholds **必开新组**;CI 用 evaluationName 含 datasetVersion + evaluatorVersion |
| **MCP server 100s 超时** | 评估时也要看 `evaluation_get` 内部的 tool latency;长任务拆分 |
| **评估成本失控** | judge 模型用便宜模型(gpt-4o-mini)做 P1/P2,P0 才用强判官;dataset 行数控制(seed ≤30,curated ≤200) |
| **`response_id` 链路断裂** | hosted agent 自动有;自定义 MCP server 一定要透传;MAF 自定义 span 一定要 `set_attribute("gen_ai.response.id", ...)` |
| **回滚没有审计** | `agent_update` 每次必须带 `creationOptions.metadata.rollback_reason`,trace 时能搜 |
| **dataset 退化**(运营手抖删了行) | manifest.json 每个版本附 row count + sha256;CI 校验 |
| **评估器版本不一致** | 评估器 YAML 加 `version`;`testCases[].evaluators[].version` 强制锁;升级时升 v2,不覆盖 v1 |

---

## 13. 参考链接

### 文档
- [Azure AI Foundry Cloud Evaluation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/develop/cloud-evaluation)
- [Built-in Evaluators](https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/observability)
- [Foundry Hosted Agents 概念](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [Foundry Agent Tool Catalog](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/tool-catalog)
- [Application Insights for OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [OpenTelemetry GenAI Spans 语义约定](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/)
- [OpenTelemetry GenAI Agent Spans](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/)
- [App Insights Alert Rules](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-overview)
- [KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

### 仓库与样例
- [Microsoft Agent Framework (GitHub)](https://github.com/microsoft/agent-framework)
- [Foundry Samples — Hosted Agents (Python)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [Foundry Samples — `08-observability`](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/08-observability)

### 配套文档
- [`azd-foundry-research.md`](./azd-foundry-research.md) — Phase 1:provision
- [`agent-harness-architecture.md`](./agent-harness-architecture.md) — Phase 2:harness 架构
