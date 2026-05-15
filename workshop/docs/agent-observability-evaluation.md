# Cloud-based Agent Harness 鍙娴嬫€т笌璇勪及鏂规

> **鍦烘櫙**:Phase 2 鐨?agent harness(`agent-harness-architecture.md`)宸茬粡鎸夌洰褰曠害瀹氶儴缃蹭笂绾裤€傛湰鏂囧洖绛?**鎬庝箞鐭ラ亾瀹冭窇寰楀ソ涓嶅ソ,鎬庝箞鎸佺画鎻愬崌璐ㄩ噺,鎬庝箞涓夎鑹插崗鍚?*?
> **閰嶅鏂囨。**:
> - Phase 1 [`azd-foundry-research.md`](./azd-foundry-research.md) 鈥?provision
> - Phase 2 [`agent-harness-architecture.md`](./agent-harness-architecture.md) 鈥?harness 鏋舵瀯
> **璐┛绀轰緥**:**浼佷笟瀹㈡埛鏀寔 agent harness**(TriageAgent 鈫?TechSupportAgent / BillingAgent / KBAgent)

---

## 0. TL;DR

**涓€鍙ヨ瘽**:鍙娴嬫€?+ 璇勪及 = **涓夊ぇ鏁版嵁闈?*(Telemetry / Evaluation / Correlation)+ **Foundry Flywheel**(Production 鈫?Trace 鈫?Harvest 鈫?Curate 鈫?Dataset 鈫?Eval 鈫?Compare 鈫?Deploy)+ **涓夎鑹插伐浣滄祦**(Dev 鏀瑰畬璺?P0;Manager 鐪嬭秼鍔?SRE 鐩憡璀?銆?

**鏁版嵁闈㈡灦鏋?*:

```
鈹屸攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L4 瑙掕壊鍏ュ彛   Dev: agentdev + 鏈湴 eval 寰幆                         鈹?
鈹?               Manager: Foundry portal 瓒嬪娍/瀵规瘮/鍥炲綊浠〃鏉?         鈹?
鈹?               SRE: KQL alert rules + Container 鍋ュ悍 + on-call        鈹?
鈹溾攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L3 鍏宠仈灞?   response_id / conversation_id 浣滀富閿?                   鈹?
鈹?             eval scores 鈫?trace spans 浜掕烦                          鈹?
鈹溾攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L2a Telemetry(App Insights)  鈹? L2b Evaluation(Foundry MCP)      鈹?
鈹? 鈹€ requests(hosted-agent 鍏ュ彛) 鈹? 鈹€ evaluator_catalog_*             鈹?
鈹? 鈹€ dependencies(LLM/tool 璋冪敤) 鈹? 鈹€ evaluation_agent_batch_eval_create鈹?
鈹? 鈹€ customEvents(璇勪及缁撴灉)      鈹? 鈹€ evaluation_dataset_*            鈹?
鈹? 鈹€ traces(GenAI 浜嬩欢)          鈹? 鈹€ evaluation_comparison_create     鈹?
鈹? 鈹€ exceptions(stack trace)     鈹? 鈹€ prompt_optimize                  鈹?
鈹溾攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹粹攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L1 鍩嬬偣灞?   GenAI OTel 璇箟绾﹀畾(Foundry agentserver 鑷姩娉ㄥ叆)      鈹?
鈹?             + MAF 瀹㈡埛绔煁鐐?@ai_function / handoff 涓氬姟 span)      鈹?
鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
```

**涓夎鑹查€熸煡**:

| 瑙掕壊 | 鏍稿績宸ュ叿 | 鐪嬩粈涔?| 鏀逛粈涔?|
|------|---------|--------|--------|
| **Dev** | `agentdev` + `evaluation_agent_batch_eval_create` + `prompt_optimize` | P0 smoke 鍒嗐€佸け璐ユ渚?trace 璇︽儏 | persona / skill / tool / instructions |
| **Manager** | Foundry portal Evaluations / `evaluation_comparison_create` | 璇勪及瓒嬪娍銆佺増鏈洖褰掋€丼LO 杈炬垚鐜?| 鎺掓湡銆佺洰鏍囧垎銆侀槇鍊?|
| **SRE** | App Insights Alert Rules + `agent_container_status_get` + KQL | 澶辫触鐜囥€乸95 寤惰繜銆佸鍣ㄧ姸鎬併€乼oken 鎴愭湰 | 鍓湰鏁般€佽秴鏃躲€佸洖婊氬埌涓婁竴鐗堟湰 |

---

## 1. 璋冪爺鐩爣涓庤疮绌夸緥

### 1.1 鐩爣闂

| 瑙掕壊 | 闂 |
|------|------|
| Dev | "鎴戝垰鏀逛簡 BillingAgent 鐨?persona,璐ㄩ噺鏄定杩樻槸璺?鍝潯鍏蜂綋鍝嶅簲涓嶅?" |
| Manager | "鏈懆 v3 姣斾笂鍛?v2 鐨?task_adherence 鎬庝箞鏍?鏈夋病鏈夊洖褰?" |
| SRE | "鍓?10 鍒嗛挓瀹㈡埛鏀寔澶辫触鐜囩獊鐒舵定鍒?8%,鍏堢湅鍝効?" |

鏈枃鍥炵瓟杩欎笁绫婚棶棰樼殑**鏁版嵁鏉ユ簮**銆?*鏌ヨ璺緞**銆?*鍝嶅簲宸ヤ綔娴?*銆?

### 1.2 璐┛渚嬫暟鎹垏闈?

| 鏁版嵁鐐?| 鍑虹幇浣嶇疆 | 鐢ㄦ硶 |
|--------|---------|------|
| `gen_ai.agent.name = triage-agent-prod` | `requests`.customDimensions | 鎸?agent 杩囨护 |
| `gen_ai.conversation.id = conv_abc` | 鎵€鏈夎〃 | 鍚屼竴瀵硅瘽鎵€鏈?span 姹囨€?|
| `gen_ai.response.id = caresp_xyz` | `dependencies` + `customEvents` | **鍏宠仈 trace 涓?eval 鐨勪富閿?* |
| `evaluator: behavioral_adherence, score: 2.0` | `customEvents` | 璇ュ搷搴旇 LLM judge 鍒ゅ畾涓轰笉杈炬爣 |

---

## 2. 鎬讳綋鏋舵瀯

### 2.1 涓夊眰鏁版嵁闈?

| 灞?| 鎻愪緵鏂?| 瀛樺摢 | 涓昏娑堣垂鑰?|
|----|--------|------|-----------|
| **Telemetry** | hosted-agent runtime + MAF 瀹㈡埛绔煁鐐?| Application Insights(`requests` / `dependencies` / `customEvents` / `traces` / `exceptions`) | Dev / SRE |
| **Evaluation** | Foundry control plane | Foundry project(eval runs / datasets / evaluators) | Dev / Manager |
| **Correlation** | OTel `gen_ai.response.id` / `gen_ai.conversation.id` | 鍚屾椂钀藉湪 trace `dependencies` 涓?eval `customEvents` | 涓夎鑹查兘鐢?|

### 2.2 鏁版嵁娴?

```
[Hosted Agent 瀹瑰櫒] 鈹€鈹€OTel鈹€鈹€鈫?App Insights 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
       鈹?                                         鈹?KQL
       鈹?涓氬姟浜嬩欢                                  鈻?
       鈹斺攢 traces / customEvents 鈹€鈹€鈫? [Dev / SRE 鏌ヨ]
       鈹?
       鈹?response_id
       鈻?
[Foundry batch eval(MCP)] 鈹€鈹€customEvents鈹€鈹€鈫?App Insights
       鈹?
       鈹?璇勪及鍒?
       鈻?
[Foundry portal] 鈫愨攢 trending / comparison 鈹€鈫?[Manager 浠〃鏉縘
       鈹?
       鈹?澶辫触鑱氱被 鈫?prompt_optimize
       鈻?
[鏂扮増 agent_update] 鈹€鈹€鈫?[redeploy]
```

### 2.3 涓?Phase 2 鐩綍鐨勫榻?

```text
support-agent-harness/
鈹溾攢鈹€ .foundry/                              # 鈽?Phase 3 涓绘垬鍦?
鈹?  鈹溾攢鈹€ agent-metadata.yaml                # observability + testCases 閰嶇疆
鈹?  鈹溾攢鈹€ datasets/                          # seed/traces/curated/prod 鍥涚被
鈹?  鈹溾攢鈹€ evaluators/                        # built-in 寮曠敤 + 鑷畾涔?YAML
鈹?  鈹斺攢鈹€ results/                           # 璇勪及缁撴灉 + 澶辫触鑱氱被
鈹溾攢鈹€ .github/workflows/                     # 鈽?Phase 3 CI/CD
鈹?  鈹溾攢鈹€ agent-eval.yml                     # PR P0 闂ㄧ
鈹?  鈹斺攢鈹€ agent-eval-scheduled.yml           # nightly P0+P1 鍥炲綊
鈹斺攢鈹€ (Phase 2 鍏跺畠鐩綍涓嶅彉)
```

---

## 3. Telemetry 鎺ュ叆

### 3.1 榛樿寮€鍚?App Insights

Phase 1 鐢ㄧ殑 `azd-ai-starter-basic` 妯℃澘榛樿 `ENABLE_MONITORING=true`,浼氬垱寤?Application Insights + Log Analytics,骞舵妸 connection string 娉ㄥ叆鍒?hosted agent 瀹瑰櫒:

```bash
azd env get-value APPLICATIONINSIGHTS_CONNECTION_STRING
```

hosted-agent runtime(`azure-ai-agentserver-agentframework` 閫傞厤鍣?浼?*鑷姩**鐢ㄨ繖涓?connection string 鍚姩 OpenTelemetry exporter,鏃犻渶鍐欎唬鐮併€?

### 3.2 鍦?`agent-metadata.yaml` 涓浐鍖?observability

```yaml
defaultEnvironment: prod
environments:
  prod:
    projectEndpoint: https://contoso.services.ai.azure.com/api/projects/support-prod
    agentName: triage-agent-prod
    observability:
      applicationInsightsResourceId: /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/components/support-prod-ai
      applicationInsightsConnectionString: InstrumentationKey=...;IngestionEndpoint=...
    testCases: [ ... ]   # 瑙?搂7.2
```

杩欎竴娈垫槸 Phase 3 鎵€鏈?trace / eval 宸ヤ綔娴佺殑**榛樿鍏ュ弬**鈥斺€旇娴?璇勪及鐨?skill 浼氫紭鍏堜粠杩欓噷璇诲嚭銆?

### 3.3 GenAI OTel 璇箟绾﹀畾(鍏抽敭灞炴€?

瀛樺湪 `dependencies` 琛ㄧ殑 `customDimensions` 閲?

| 灞炴€?| 鍚箟 | 渚?|
|------|------|---|
| `gen_ai.operation.name` | 鎿嶄綔绫诲瀷 | `chat` / `invoke_agent` / `execute_tool` / `create_agent` |
| `gen_ai.conversation.id` | 浼氳瘽 ID | `conv_5j66...` |
| `gen_ai.response.id` | **鍝嶅簲 ID(鍏宠仈涓婚敭)** | hosted agent `caresp_...` / prompt agent `resp_...` / Azure OpenAI `chatcmpl-...` |
| `gen_ai.agent.name` | agent 鍚?`requests` 涓婃槸 Foundry 鍚?`dependencies` 涓婂彲鑳芥槸 sub-agent 绫诲悕) | `triage-agent-prod` |
| `gen_ai.agent.id` | hosted agent 杩樹細甯?`<name>:<version>` | `triage-agent-prod:3` |
| `gen_ai.request.model` / `gen_ai.response.model` | 妯″瀷 | `gpt-4o` / `gpt-4o-2024-05-13` |
| `gen_ai.usage.input_tokens` / `output_tokens` | token 鐢ㄩ噺(鎴愭湰鏍哥畻) | `450` / `120` |
| `gen_ai.response.finish_reasons` | 缁撴潫鍘熷洜 | `["stop"]` / `["tool_calls"]` |
| `error.type` | 閿欒鍒嗙被 | `timeout` / `rate_limited` / `content_filter` |
| `gen_ai.tool.name` | tool 鍚?execute_tool span 涓? | `crm_lookup` |

> 鈿狅笍 **hosted agent 韬唤瑙勫垯**:Foundry agent 鍚嶅彧鍦?`requests` 琛ㄤ笂鍙潬;`dependencies` 涓婄殑 `gen_ai.agent.name` 鍙兘鏄瓙绫?渚嬪 `TechSupportAgent`)銆?*鎬绘槸鍏堢敤 `requests` 绛?Foundry 鍚?鎷?`operation_Id` 鍐?join `dependencies`**銆?

### 3.4 MAF 瀹㈡埛绔煁鐐?涓氬姟绾?span)

OTel 鑷姩鍩嬬偣鍙鐩?LLM 璋冪敤涓?tool execute銆?*涓氬姟绾?span**(鍒涘缓宸ュ崟銆侀€€娆惧鏍?闇€瑕佽嚜宸卞姞:

```python
# tools/ticketing.py
from agent_framework import ai_function
from opentelemetry import trace

tracer = trace.get_tracer("support-harness.tools")

@ai_function(name="create_ticket", description="涓哄鎴峰垱寤哄伐鍗?)
async def create_ticket(customer_id: str, category: str, summary: str) -> str:
    with tracer.start_as_current_span("ticket.create") as span:
        span.set_attribute("ticket.customer_id", customer_id)
        span.set_attribute("ticket.category", category)
        ticket_id = await _internal.create(customer_id, category, summary)
        span.set_attribute("ticket.id", ticket_id)
        return ticket_id
```

杩欎簺鑷畾涔夊睘鎬т篃浼氳繘 `dependencies.customDimensions`,鍙互鍦?KQL 閲岀洿鎺?`extend ticketId = tostring(customDimensions["ticket.id"])`銆?

**handoff 涔熻鍩?*:`handoff_to_tech(...)` 鍑芥暟閲屽姞 span `subagent.handoff`,灞炴€?`from=triage`銆乣to=tech-support`銆乣reason=...`,Manager 浠〃鏉垮氨鑳界湅鍒板瓙 agent 涔嬮棿鐨勮矾鐢卞垎甯冦€?

### 3.5 PII 闃叉硠闇?

OTel 榛樿浼氭妸 `gen_ai.input.messages` / `gen_ai.output.messages` 瀹屾暣钀藉簱銆傜敓浜х幆澧冨簲:

- 鍦?`azure.ai.agentserver` 閫傞厤鍣ㄥ眰閰嶇疆 `OTEL_GENAI_CAPTURE_MESSAGE_CONTENT=false`,鎴?
- 鑷畾涔?`SpanProcessor` 鍦ㄥ鍑哄墠 redact 鏁忔劅瀛楁,鎴?
- 鍦?App Insights 绔敤 Log Filter Function 鍒犻櫎瀛楁(鎴愭湰鏈€楂?

### 3.6 璐┛绀轰緥

`agent-metadata.yaml` 鍐欏ソ `observability` 娈靛悗,鎵€鏈夊悗缁?`trace` / `observe` skill 鑷姩璇诲彇;`tools/ticketing.py` 鍔?`ticket.id` span 灞炴€у悗,SRE 鍦?P0 澶辫触鑱氱被鍚庤兘鐩存帴 join 宸ュ崟绯荤粺鍙嶆煡褰卞搷闈€?

---

## 4. Trace 宸ヤ綔娴?Dev + SRE 鍏辩敤)

### 4.1 鍩虹鏌ヨ鍏ュ彛

> **鎬绘槸鍏堟樉绀?KQL,鍐嶆墽琛?*;**鎬绘槸甯︽椂闂寸獥**(榛樿 24h)銆?

#### 4.1.1 鎸?conversation_id 鎷変竴鏉″璇濇墍鏈?span

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

#### 4.1.2 鎸?response_id 鎵惧埌瀵瑰簲 trace(鍐嶆墖鍑烘暣涓璇?

```kql
let target = dependencies
| where timestamp > ago(24h)
| where customDimensions["gen_ai.response.id"] == "<response_id>"
| project operation_Id;
dependencies
| where operation_Id in (target)
| order by timestamp asc
```

#### 4.1.3 Foundry hosted-agent 鍏ュ彛(浠?requests 鍑哄彂)

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

### 4.2 澶辫触鑱氱被(SRE 绗竴鎶撴墜)

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

杈撳嚭鍚庢寜 P0/P1/P2 鎺掑簭:

| Priority | Error | Operation | Count | resultCode | 寤鸿 |
|----------|-------|-----------|-------|-----------|------|
| P0 | `timeout` | `invoke_agent` | 15 | 504 | 鐪嬪鍣ㄥ仴搴枫€佸姞瓒呮椂;鑻?MCP 绔?鈫?鏈嶅姟绔媶浠诲姟 |
| P1 | `rate_limited` | `chat` | 8 | 429 | 妫€鏌ユā鍨嬮厤棰?鍔犻€€閬块噸璇?|
| P2 | `content_filter` | `chat` | 5 | 400 | 閲嶅 prompt 鏄惁瑙﹀彂绛栫暐 |
| P3 | `tool_error` | `execute_tool` | 3 | 500 | 鐪?tool 瀹炵幇 + 鏉冮檺(`tools/*.py`) |

### 4.3 寤惰繜鍒嗘瀽

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

寤惰繜灏栧埡瀹氫綅:浠?p95 璺冲彉鐨?5 鍒嗛挓绐楀彛鍙?sample `operation_Id`,璺?4.1.1/4.1.3 鐪嬪畬鏁?span tree,鎵惧嚭鍝(`chat` / `execute_tool` / 瀛?agent `invoke_agent`)寮傚父鍙樻參銆?

### 4.4 瀹瑰櫒鍋ュ悍(SRE)

```kql
// 骞冲潎 RU(replica utilization)
requests
| where timestamp > ago(15m)
| where name startswith "POST /responses"
| extend agent = tostring(customDimensions["gen_ai.agent.name"])
| summarize qps = count() / 900.0, p95 = percentile(duration, 95) by agent
```

閰嶅悎 Foundry MCP `agent_container_status_get` 鐪嬪壇鏈姸鎬?`Starting` / `Running` / `Stopped` / `Failed`)銆?

### 4.5 璐┛绀轰緥(SRE 绐佸彂鍛婅)

鍛婅瑙﹀彂:杩囧幓 5 鍒嗛挓 BillingAgent 澶辫触鐜?> 5%銆?
1. 璺?搂4.2,鐪嬪埌 P0 `timeout` 闆嗕腑鍦?`execute_tool / pricing-rules-mcp`
2. 鍙?sample `operation_Id`,搂4.1.1 鎷夊畬鏁村璇?鍙戠幇 MCP server 绔湪 95s 澶勮秴鏃?
3. Foundry MCP server 100s 涓婇檺瑙﹀彂,`agent_update` 鎶?BillingAgent 鍒囧洖 v2(涓婄増鏈湭寮曞叆璇?MCP),鍏堟琛€
4. 璺?MCP server owner 鏀规垚寮傛浠诲姟妯″紡

---

## 5. Evaluators

### 5.1 Built-in 璇勪及鍣ㄦ竻鍗?

| Evaluator | 缁村害 | 閫傜敤 | 鐢ㄦ硶 |
|-----------|------|------|------|
| `relevance` | Quality | 绛斾笌闂浉鍏?| 閫氱敤 |
| `task_adherence` | Quality | 瀹屾垚浜嗙敤鎴峰疄闄呬换鍔?| 澶氭 agent |
| `intent_resolution` | Quality | 鐞嗚В浜嗙敤鎴锋剰鍥?| 璺敱 / triage |
| `coherence` | Quality | 琛ㄨ揪杩炶疮 | 闀胯緭鍑?|
| `fluency` | Quality | 璇█鑷劧 | 澶氳瑷€ |
| `groundedness` | Quality | 鏈変笂涓嬫枃/寮曠敤鏀拺 | RAG |
| `builtin.tool_call_accuracy` | Tool use | tool 閫夊銆佸弬鏁板銆侀『搴忓 | 鐢?tool 鐨?agent 鈽?|
| `indirect_attack` | Safety | 鎶?prompt injection | 蹇呭惈 |
| `violence` / `self_harm` / `sexual` / `hate_unfairness` | Safety | RAI 鍐呭瀹℃煡 | 鎵€鏈夐潰鍚?C 绔?|

> 鈿狅笍 **LLM judge 鐭ヨ瘑鎴闄烽槺**:`groundedness` 杩欑鍩轰簬浜嬪疄鐨勮瘎浼板櫒,瀵逛簬瀹炴椂鏁版嵁(Bing / Web Search)浼氬亣闃虫€?鎶婄湡瀹炰簨瀹炲垽瀹氫负"瓒呭嚭鐭ヨ瘑");鑷畾涔夎瘎浼板櫒 prompt 瑕佸啓"鎺ュ彈鏉ユ簮鏍囨敞浣嗕綘鏃犳硶楠岃瘉鐨勪簨瀹?銆?

### 5.2 Two-Phase 绛栫暐

| 闃舵 | 浣曟椂 | 璇勪及鍣?| 鏁版嵁闆嗗瓧娈?|
|------|------|-------|----------|
| **Phase 1** 鍩虹嚎 | 棣栨閮ㄧ讲鍚庣珛鍒?| 鈮? 涓?built-in:`relevance`, `task_adherence`, `intent_resolution`, `indirect_attack`,**鏈?tool 鏃跺姞** `builtin.tool_call_accuracy` | `query` + `expected_behavior`(鍚庤€呯粰 Phase 2 鐣欏彛) |
| **Phase 2** 瀹氬悜 | 鍒嗘瀽 Phase 1 澶辫触鍚?| 鍏?`evaluator_catalog_get` 鏌ョ幇鏈?custom;鏃犺鐩栨椂鍐?`evaluator_catalog_create` | 澶嶇敤 `expected_behavior` 浣滄瘡琛岀殑琛屼负鏍囧噯 |

**鍏抽敭**:姣忚 `query` 閮借閰?`expected_behavior`(鑷劧璇█鍐?鐞嗘兂鍝嶅簲搴旇鍋氫粈涔?),Phase 1 built-in 鐢ㄤ笉涓婁絾 Phase 2 鐩存帴澶嶇敤,**涓嶇敤閲嶇敓鎴愭暟鎹泦**銆?

### 5.3 Phase 2 鑷畾涔?evaluator YAML 渚嬪瓙

#### 5.3.1 `behavioral_adherence` 鈥?鍩轰簬 `expected_behavior` 鐨勮涓虹鍚堝害

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
  verify the underlying fact, accept the claim 鈥?do NOT score down for
  facts beyond your knowledge.
```

#### 5.3.2 `citation_quality` 鈥?寮曠敤璐ㄩ噺(鐢ㄤ簬 KBAgent)

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

#### 5.3.3 `refund_policy_adherence` 鈥?涓氬姟瑙勫垯璇勪及鍣?BillingAgent 涓撶敤)

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

> 馃挕 **鍒ゅ畼妯″瀷閫夊瀷**:`deploymentName` 鐢?`gpt-4o` 鎴?`gpt-4.1`(寮轰竴浜涚殑鍒ゅ畼);**涓嶈鐢ㄥ悓涓€涓璇勪及妯″瀷**(闃叉绯荤粺鎬у亸宸?銆?

### 5.4 闃堝€煎缓璁?

| 缁村害 | P0(蹇呰繃) | P1(鍥炲綊鐩戞帶) | P2(鍙傝€? |
|------|----------|--------------|-----------|
| `relevance`(1-5) | 鈮?4 | 鈮?4 | 鈮?3 |
| `task_adherence` | 鈮?4 | 鈮?4 | 鈮?3 |
| `intent_resolution`(triage) | 鈮?4 | 鈥?| 鈥?|
| `behavioral_adherence` | 鈮?4 | 鈮?4 | 鈮?3 |
| `citation_quality`(0-1) | 鈮?0.9 | 鈮?0.85 | 鈮?0.7 |
| `refund_policy_adherence` | == 1 | == 1 | == 1 |
| `indirect_attack` | == 0(0=瀹夊叏) | == 0 | == 0 |
| `violence` / `self_harm` / 绛?| 鈮?1(Foundry RAI 0-7) | 鈮?1 | 鈮?1 |

> **鍏抽敭涓嶅彉閲?*:**瀹夊叏绫婚槇鍊间笉鑳藉洜涓哄垎鏁板帇鍔涜€屾斁瀹?*;**涓氬姟瑙勫垯璇勪及鍣?refund 杩欑被)P0 蹇呴』 100%**銆?

### 5.5 璐┛绀轰緥

BillingAgent 涓?`behavioral_adherence` + `refund_policy_adherence` + `citation_quality`;TechSupportAgent 涓?`behavioral_adherence` + `tool_call_accuracy`;TriageAgent 涓?`intent_resolution`(鍒嗙被鏄惁姝ｇ‘)+ `behavioral_adherence`銆?

---

## 6. Datasets

### 6.1 鍥涚被鏁版嵁闆?

| 绫诲瀷 | Foundry 鏁版嵁闆嗗悕 | Version | 鏈湴鏂囦欢 | 鏉ユ簮 |
|------|----------------|---------|---------|------|
| seed | `<agent>-eval-seed` | `v1` | `.foundry/datasets/<agent>-eval-seed-v1.jsonl` | LLM 鍚堟垚 |
| traces | `<agent>-traces` | `v<N>` | `.foundry/datasets/<agent>-traces-v<N>.jsonl` | 鐢熶骇 trace 鎶藉彇 |
| curated | `<agent>-curated` | `v<N>` | `...-curated-v<N>.jsonl` | traces 浜哄杩?|
| prod | `<agent>-prod` | `v<N>` | `...-prod-v<N>.jsonl` | 涓婄嚎闂ㄧ鍩哄噯 |

> 鏂囦欢鍚嶅墠缂€ = `agentName`(Phase 2 搂8.2 鍛藉悕绾﹀畾);濡傛灉 agentName 宸插惈鐜(`billing-agent-dev`),**涓嶈閲嶅**杩藉姞 env銆?

### 6.2 JSONL 琛岀粨鏋?姣忚涓€涓祴璇曠敤渚?

```json
{
  "id": "billing-001",
  "query": "鎴戞槸 Acme 浼佷笟鐗堝鎴?涓婃湀鐢ㄩ噺鍙湁 10% 杩樿兘閫€澶氬皯?",
  "expected_behavior": "搴旀寜 Enterprise tier 璁＄畻 pro-rata 閫€娆?鎻愬強 30 澶╃獥鍙ｄ笌 50% 涓婇檺,寮曠敤鍚堝悓鏉℃銆備笉搴旂洿鎺ユ壙璇哄叿浣撻噾棰濄€?,
  "context": "Customer tier: Enterprise; usage: 10%; days since contract start: 15",
  "ground_truth": null,
  "tags": ["billing", "refund", "enterprise"]
}
```

瀛楁蹇呭:`query` + `expected_behavior`(鍏跺畠鍙€?銆?

### 6.3 Trace-to-Dataset 娴佹按绾?

```
[1] 鐢?KQL 浠?App Insights 鎶?24h 鍐呯殑瀵硅瘽鏍锋湰
[2] 鎺掗櫎 PII / 鍐呴儴娴嬭瘯甯愬彿
[3] 鐢?expected_behavior 鑷姩鐢熸垚(LLM)鍒濈
[4] 鈽?浜哄伐瀹?/ 鏀?expected_behavior(寮哄埗)
[5] 鍐欏叆 .foundry/datasets/<agent>-traces-v<N>.jsonl
[6] evaluation_dataset_create 娉ㄥ唽鍒?Foundry
[7] 鍦?agent-metadata.yaml 鐨?testCases[] 鍔犲紩鐢?
```

KQL 鎶藉彇渚?

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

> 鈿狅笍 **浜哄寮哄埗**:涓嶈鐩存帴 commit 鑷姩鎶藉彇缁撴灉銆傚睍绀哄€欓€夌粰涓氬姟鏂?瀹″畬鎵嶈繘 dataset銆?

### 6.4 鐗堟湰鍖?+ lineage

`.foundry/datasets/manifest.json` 璁版瘡涓暟鎹泦 鈫?涓婃鍚屾銆佺浉閭?eval 杩愯銆佸搴?agent 鐗堟湰:

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

### 6.5 鍏抽敭瀹堝垯

- 鍚屼竴鏁版嵁闆嗗悕璺ㄧ増鏈?*鍙姞涓嶅垹**(`billing-agent-traces` 姘歌繙鏄畠);鐗堟湰杩?`datasetVersion` 瀛楁
- 鍒嗘暟鎺変簡**涓嶈鍒犺/璋冭瘎浼板櫒**鍥炶ˉ,鍏堜紭鍖?agent
- 鍚屼竴浠?dataset 缁欐墍鏈夌増鏈姣?杩欐牱 v3 vs v4 鎵嶅叕骞?

### 6.6 璐┛绀轰緥

BillingAgent 姣忓懆 nightly 璺?trace harvest,浜哄閫氳繃鐨?30 琛岃繘 `billing-agent-prod-traces-v4`;`agent-metadata.yaml` 鍔?`testCases[2]` 鐢ㄨ繖浠芥暟鎹泦 + `refund_policy_adherence` + 闃堝€?1銆?

---

## 7. Batch Evaluation

### 7.1 MCP 璋冪敤

```python
# 姒傚康鎬т吉浠ｇ爜
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
    deploymentName="gpt-4o",                  # judge 妯″瀷
    evaluationId="<existing-group-id-or-new>",# 鍚岀粍鎵嶈兘瀵规瘮
    evaluationName="billing-prod-v3-smoke-2026-04-22",
)
```

### 7.2 `testCases[]` 缁勭粐

鍦?`agent-metadata.yaml`:

```yaml
environments:
  prod:
    testCases:
      - id: smoke-core                       # 鈽?P0 鈥?PR 闂ㄧ
        priority: P0
        dataset: billing-agent-prod-eval-seed
        datasetVersion: v1
        datasetFile: .foundry/datasets/billing-agent-prod-eval-seed-v1.jsonl
        datasetUri: azureml://.../datasets/billing-agent-prod-eval-seed/versions/v1
        evaluators:
          - { name: relevance, threshold: 4 }
          - { name: indirect_attack, threshold: 0 }
          - { name: refund_policy_adherence, threshold: 1, definitionFile: .foundry/evaluators/refund-policy-adherence.yaml }

      - id: trace-regressions                # 鈽?P1 鈥?nightly
        priority: P1
        dataset: billing-agent-prod-traces
        datasetVersion: v4
        datasetFile: .foundry/datasets/billing-agent-prod-traces-v4.jsonl
        datasetUri: azureml://.../datasets/billing-agent-prod-traces/versions/v4
        evaluators:
          - { name: task_adherence, threshold: 4 }
          - { name: behavioral_adherence, threshold: 4, definitionFile: .foundry/evaluators/behavioral-adherence.yaml }
          - { name: citation_quality, threshold: 0.9, definitionFile: .foundry/evaluators/citation-quality.yaml }

      - id: broad-quality                    # 鈽?P2 鈥?weekly
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

### 7.3 涓夋。闂ㄧ

| 浼樺厛绾?| 璺戠殑鏃舵満 | 璇勪及鍣ㄧ粍 | Gate 琛屼负 |
|--------|---------|----------|----------|
| **P0** | 姣忔 PR + 姣忔 deploy | 瀹夊叏(`indirect_attack`銆丷AI)+ 涓氬姟纭鍒?`refund_policy_adherence`)+ `relevance` | **浠讳綍涓€椤逛笉杩?鈫?闃绘 merge / 闃绘 deploy** |
| **P1** | nightly | trace-harvested 鏁版嵁闆?+ `task_adherence` / `behavioral_adherence` | 浠讳綍鍥炲綊 鈫?鑷姩寮€ issue,鏍囪 P1 |
| **P2** | weekly | 鍏ㄩ噺 curated + 鎵€鏈夎瘎浼板櫒 | 鐢ㄤ簬 trending,涓嶉樆濉?|

### 7.4 鍏抽敭鍙傛暟鍛藉悕闄烽槺

| 宸ュ叿 | 鐢?`evaluationId` | 鐢?`evalId` |
|------|------------------|-------------|
| `evaluation_agent_batch_eval_create` | 鉁?澹版槑缁? | 鉂?|
| `evaluation_get` | 鉂?| 鉁?`isRequestForRuns=true` 鍒楃粍鍐呮墍鏈?run) |
| `evaluation_comparison_create` | 鉂?| 鉁?鍦?`insightRequest.request.evalId`) |

> **鍚岀粍(evaluationId)涓嶅彲鍙?*:璇勪及鍣ㄥ垪琛ㄦ垨闃堝€煎彉浜?**蹇呴』寮€鏂扮粍**,涓嶈兘寰€鑰佺粍閲屽銆?

### 7.5 璐┛绀轰緥

PR #128 鏀?BillingAgent 鐨?persona;CI 瑙﹀彂 P0:`smoke-core` 鏁版嵁闆?+ 涓婇潰 3 涓瘎浼板櫒璺戣繃 鈫?閮ㄧ讲鍒?prod;nightly 鎷垮悓涓€ `evaluationId` 璺?`trace-regressions`,鎶?v3 涓?v2 鐨?run 閮藉湪涓€缁?Manager 浠〃鏉跨湅 task_adherence 4.2 鈫?4.4 娑ㄤ簡 5%銆?

---

## 8. Trace 脳 Eval 鍏宠仈(鏈枃鏍稿績)

### 8.1 涓婚敭:`response_id`

Foundry batch eval 璺戝畬鍚?**姣忔潯璇勪及缁撴灉閮戒細浠?`customEvents` 鐨勫舰寮忓洖鍐欏埌 App Insights**,瀛楁 `gen_ai.response.id` 涓?agent 鍝嶅簲褰撴椂鐨?trace 鍏变韩,浠庤€?

| 璧风偣 | 缁堢偣 | 鎬庝箞璺?|
|------|------|--------|
| 鎴戠湅鍒颁竴鏉?trace 澶辫触 鈫?鎯崇煡閬撹繖鏉¤璇勪及涓哄灏戝垎 | 璇勪及鍒?| KQL `customEvents` where `gen_ai.response.id == <id>` |
| 鎴戠湅鍒颁竴鏉?eval 澶辫触妗堜緥 鈫?鎯崇煡閬撳綋鏃朵笂涓嬫枃/宸ュ叿璋冪敤閾?| 瀹屾暣 trace | KQL `dependencies` where `gen_ai.response.id == <id>` |
| 鎴戞兂缁熻鏌愭 eval run 閲屾墍鏈?P0 澶辫触琛岀殑 trace | 鎵€鏈?trace | 鍏堟妸澶辫触琛岀殑 responseId 鎷夊嚭,鍐嶆壒閲?join |

### 8.2 鎷夊崟鏉″搷搴旂殑鎵€鏈夎瘎浼板垎

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

杈撳嚭绀轰緥:

| evaluator | score | label | explanation |
|-----------|-------|-------|-------------|
| relevance | 4.0 | pass | Addresses the refund question... |
| refund_policy_adherence | 0 | fail | Promised 60% refund, exceeds 50% cap for Enterprise tier |
| behavioral_adherence | 2.0 | fail | Did not cite policy section |

### 8.3 鎷夊崟鏉″搷搴旂殑鎵€鏈?span(鍐嶉檮璇勪及鍒?

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

### 8.4 澶辫触妗堜緥鐨勫弽鍚戦摼璺?eval 鈫?trace 璇︽儏)

Dev 鍦?`.foundry/results/<run>/failures.jsonl` 閲岀湅鍒版煇琛?`refund_policy_adherence=0`:

1. 鍙栬鍐?`responseId`
2. 璺?搂8.3,鎷垮埌瀹屾暣 span tree
3. 鐪嬪埌 `execute_tool: pricing-rules-mcp` 杩斿洖浜嗛敊璇殑 tier 鏄犲皠 鈫?閿佸畾 root cause
4. 淇?MCP server,鎴栬€呮敼 BillingAgent 鐨?persona 瑕佹眰鍙岄噸纭 tier

### 8.5 瀹堝垯

> **`gen_ai.response.id` 鏄繖濂楁暟鎹郴缁熺殑"join key"**銆備笉鏀惧氨搴?
> - hosted agent runtime 鑷姩娉ㄥ叆 鉁?
> - MAF 瀹㈡埛绔煁鐐逛篃瑕佷繚鐣?鉁?鍦ㄨ嚜瀹氫箟 span 涓?`set_attribute("gen_ai.response.id", ...)`)
> - 鑷缓 MCP server 鍔″繀閫忎紶 鉁?

---

## 9. 浼樺寲寰幆

> 娉ㄦ剰:**鍏堝崌绾ф暟鎹泦鍐嶅崌绾фā鍨?*鈥斺€斾笉瑕佷负浜?鍒嗘暟濂界湅"鍒犺鎴栧急鍖栬瘎浼板櫒銆?

### 9.1 澶辫触鑱氱被(Dev 绗竴鎶撴墜)

```bash
# 姒傚康鎬ц剼鏈?鏀惧湪 scripts/cluster_failures.py)
python scripts/cluster_failures.py \
    --results .foundry/results/billing-agent-prod-v3-trace-regressions/ \
    --output .foundry/results/billing-agent-prod-v3-trace-regressions/clusters.json
```

鎸?`evalName + 澶辫触鍘熷洜鍏抽敭璇峘(LLM 鎻愬彇)鍋?k-means;杈撳嚭琛?

| Cluster | 璇勪及鍣?| 澶辫触鍘熷洜 | 鏍锋湰 query | 鍗犲け璐?% |
|---------|-------|---------|-----------|----------|
| C1 | refund_policy_adherence | 寮勯敊 tier | "鎴戞槸鍟嗕笟鐗?鑳介€€澶氬皯" | 38% |
| C2 | citation_quality | 鏈紩鐢ㄥ悎鍚屾潯娆?| "渚濇嵁鏄粈涔? | 24% |
| C3 | behavioral_adherence | 鐩存帴缁欏叿浣撻噾棰?| "閫€鎴?X 鍏冭涓嶈" | 18% |

Dev 閫変竴绫昏仛鐒︿紭鍖栥€?

### 9.2 `prompt_optimize`

```python
prompt_optimize(
    developerMessage=<current billing-agent persona>,
    deploymentName="gpt-5-mini",
    projectEndpoint="...",
    requestedChanges=(
        "1) Always re-confirm customer tier before quoting refund; "
        "2) Cite policy section by name; "
        "3) Never commit to a specific currency amount, only ranges."
    ),
)
```

杩斿洖浼樺寲鍚庣殑 prompt銆?*Dev 瀹℃牳 diff,纭鍚庡啀鐢?*;**涓嶈璁?prompt_optimize 鐩存帴瑕嗙洊 persona**鈥斺€旀妸瀹冪殑杈撳嚭璐村洖 `personas/billing-agent.md`,git commit,璧版甯?PR 璇勫銆?

### 9.3 redeploy(鐗堟湰绠＄悊)

```python
agent_update(
    projectEndpoint="...",
    agentName="billing-agent-prod",
    agentDefinition=<new definition with updated instructions>,
)
# Foundry 鑷姩鍒涘缓鏂扮増鏈?v4)
agent_container_control(agentName="billing-agent-prod", action="start")
# 杞鐩村埌 Running
```

> **淇濈暀鏃х増鏈嚦灏?1 鍛?*,澶辫触鍥炴粴鐩存帴 `agent_update --version v3 reactivate`銆?

### 9.4 鐗堟湰瀵规瘮

```python
evaluation_comparison_create(
    insightRequest={
        "displayName": "billing v3 vs v4 (trace-regressions)",
        "state": "NotStarted",
        "request": {
            "type": "EvaluationComparison",
            "evalId": "<eval-group-id>",     # 娉ㄦ剰:杩欓噷鏄?evalId,涓嶆槸 evaluationId
            "baselineRunId": "<v3-run-id>",
            "treatmentRunIds": ["<v4-run-id>"],
        }
    }
)
# 鐒跺悗 evaluation_comparison_get(insightId=...)
```

杈撳嚭:姣忎釜璇勪及鍣?baseline vs treatment 鐨勫潎鍊笺€乸95銆佹樉钁楁€ф彁绀恒€?

### 9.5 鍏抽敭鍐崇瓥鐐?

```
v4 璺戝畬姣?v3:
  鈹溾攢 鍏ㄩ儴缁村害 鈫?               鈫?鎺ュ彈,淇濈暀 v4
  鈹溾攢 涓昏鐩爣缁村害 鈫?鍏跺畠鎸佸钩 鈫?鎺ュ彈
  鈹溾攢 涓昏鐩爣缁村害 鈫?浣?safety 鈫?鈫?鎷掔粷,鍥炲埌 9.1 閲嶅仛
  鈹斺攢 涓昏鐩爣缁村害 鈫?浣?token 鐢ㄩ噺 鈫?50% 鈫?璇勪及鎴愭湰/鏁堢泭,鍙兘鎺ュ彈/鍙兘鍚?
```

### 9.6 璐┛绀轰緥

C1(tier 璇垽)鈫?`prompt_optimize` 杈撳嚭鍔?"always confirm tier first" 鈫?persona 鏀瑰畬 鈫?v4 deploy 鈫?eval comparison:`refund_policy_adherence` 0.62鈫?.97,浣?`task_adherence` 4.4鈫?.2(鍥犱负姣忔浼氬厛鍙嶉棶鎷栨參浠诲姟) 鈫?Dev 鍐冲畾鍔犱竴鏉?"if tier is in conversation history, skip confirmation" 鈫?v5銆?

---

## 10. 涓夎鑹插伐浣滄祦

### 10.1 Dev 鏈湴寰幆

```
1. 鏀?personas/billing-agent.md(鎴?skills/refund-quote/SKILL.md)
2. agentdev run src/billing_agent/main.py --port 8087
3. 鏈湴鎵嬪姩璺戝嚑涓?case,Agent Inspector 鐪?trace
4. evaluation_agent_batch_eval_create 璺?P0 smoke-core(鍙?10-20 琛?~1 鍒嗛挓)
5. P0 杩?鈫?git commit
6. P0 涓嶈繃 鈫?搂8.4 鍙嶅悜閾捐矾瀹氫綅 鈫?鏀瑰洖鍘?
7. PR push 鈫?CI 璺?P0(.github/workflows/agent-eval.yml)
```

**Dev IDE 浣撻獙**:VS Code AI Toolkit 瑁呭ソ,`.foundry/datasets/*.jsonl` 鐩存帴 Open in Data Viewer 鐪嬫祴璇曠敤渚?`.foundry/results/*` 鐪?score 鍒嗗竷銆?

### 10.2 Manager 瓒嬪娍 + 鍥炲綊

**浠〃鏉?Foundry portal)**:
- Evaluations 鈫?閫?evaluationId 鈫?鐪?run 鏃堕棿搴忓垪(score over time)
- Comparison 鈫?v(n-1) vs v(n) 鑷姩鐢熸垚
- Regression 鈫?浠讳綍璇勪及鍣ㄨ穼鐮撮槇鍊兼爣绾?

**鑷缓浠〃鏉?鍙€?KQL feeding Power BI / Grafana)**:

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

**鍛ㄤ細鏁版嵁瑙嗚**:
- 鍚勪笓绉?agent 鐨?task_adherence 鍛ㄧ幆姣?
- 瀹夊叏璇勪及鍣ㄦ槸鍚?100% 閫氳繃(鑻?< 100% 鎷夎)
- token 鎴愭湰瓒嬪娍(鐪?`gen_ai.usage.*`)
- 鐢ㄦ埛姹傚姪閲?invoke_agent 娆℃暟)

### 10.3 SRE 鐢熶骇鍛婅 + on-call

#### 鍛婅瑙勫垯(鍩轰簬 App Insights Alert Rules)

| 鍛婅 | KQL | 闃堝€?| Action |
|------|-----|------|--------|
| 澶辫触鐜囩獊澧?| `requests \| where success == false \| summarize fr=count()/toscalar(toscalar(requests \| count)) by bin(timestamp,5m)` | > 5% 鎸佺画 2 涓獥鍙?| PageDuty P1 |
| p95 寤惰繜绐佸 | `requests \| summarize p95=percentile(duration,95) by bin(timestamp,5m)` | > 2脳 鍘嗗彶涓綅 | Slack 閫氱煡 |
| 瀹瑰櫒 Failed | Foundry MCP `agent_container_status_get` + scheduled job | status == "Failed" | PageDuty P0 |
| 璇勪及鍣ㄥ垎鏁版帀 | 鍦?nightly run 涔嬪悗璺?KQL | 鏌愯瘎浼板櫒鍧囧€肩幆姣旀帀 鈮?10% | 鑷姩寮€ GitHub Issue |
| token 鎴愭湰寮傚父 | `dependencies \| summarize sumTokens=sum(toint(customDimensions["gen_ai.usage.input_tokens"])) by bin(timestamp,1h)` | > 2脳 鍘嗗彶涓綅 | Slack 閫氱煡 |

#### on-call runbook(绮剧畝鐗?

```
Step 0: 鐪嬪憡璀︾被鍨?鈫?閫?搂10.3 琛ㄤ腑鐨?KQL 妯℃澘
Step 1: 搂4.2 澶辫触鑱氱被 鈫?鎷垮埌 top 閿欒绫?
Step 2: 鍙?sample operation_Id 鈫?搂4.1 鎷夊畬鏁?trace
Step 3: 搂8.3 鍔?eval 鍒?鑻?eval 宸茶窇杩?
Step 4: 鍒ゆ柇:
  - L2 妯″瀷闂(rate_limit / content_filter) 鈫?鑱旂郴 model team
  - L3 搴旂敤闂(tool / persona) 鈫?鍒囦笂鐗堟湰(agent_update),寮€ ticket 缁?dev
  - L2b MCP / 澶栭儴渚濊禆 鈫?鍒囨柇璇?tool(env var 鍏? + 閫氱煡渚濊禆鏂?
Step 5: 鏁呴殰澶嶇洏:traces 鈫?鍔犲叆 trace-harvest 鈫?涓嬬増鏈瘎浼拌鐩?
```

#### 瀹瑰櫒鍋ュ悍鐩戞帶

```bash
# 瀹氭椂浠诲姟(SRE 鐨勫畾鏃?job)
agent_container_status_get(projectEndpoint=..., agentName="billing-agent-prod")
# 鑻?status != "Running",瑙﹀彂鍛婅 + 鑷姩 agent_container_control(action="start")
```

---

## 11. CI/CD 闆嗘垚鍘熷垯

### 11.1 PR 闂ㄧ(P0)

```yaml
# .github/workflows/agent-eval.yml(鍘熷垯绀烘剰)
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
      # 1. 閮ㄧ讲 PR 鐗堟湰鍒?dev 鐜鐨勪复鏃?agent
      - run: azd deploy <agent>
      # 2. 璺?P0 testCase
      - run: python scripts/run_eval.py --testCase smoke-core --env dev
      # 3. 浠绘剰璇勪及鍣ㄨ穼鐮撮槇鍊?鈫?exit 1
```

瑕佺偣:
- **姣忎釜 PR 閮ㄧ讲鍒?dev**(鐭?TTL,璺戝畬閿€姣?,涓嶈鐩存帴璇勪及 prod 鐗堟湰
- **P0 鐢?seed dataset**(蹇?10-20 琛?1 鍒嗛挓鍐呭嚭缁撴灉)
- **澶辫触鏃舵妸 .foundry/results/ 涓婁紶鎴?artifact**,PR comment 缁欒鎯呴摼鎺?

### 11.2 Nightly 鍥炲綊(P1)

```yaml
# .github/workflows/agent-eval-scheduled.yml
on:
  schedule: [{cron: "0 2 * * *"}]   # 02:00 UTC
jobs:
  regression:
    steps:
      - run: python scripts/run_eval.py --testCase trace-regressions --env prod
      # 鑻ヤ换浣曡瘎浼板櫒鐜瘮鎺?> 10%,鑷姩寮€ issue
      - if: failure()
        run: python scripts/open_regression_issue.py
```

璺戝湪 **prod agent 涓?*,鏁版嵁闆嗘槸 trace-harvested銆?

### 11.3 Weekly trace harvest + curate

```yaml
on:
  schedule: [{cron: "0 8 * * MON"}]   # 鍛ㄤ竴 08:00 UTC
jobs:
  harvest:
    steps:
      - run: python scripts/harvest_traces.py --agent billing-agent-prod --days 7
      # 杈撳嚭 .foundry/datasets/billing-agent-prod-traces-v<N+1>.draft.jsonl
      - run: gh pr create --title "[harvest] billing v<N+1>" --body "闇€浜哄伐瀹?expected_behavior"
```

浜哄伐瀹″畬鍚堝苟鍚?鑷姩娉ㄥ唽鍒?Foundry(`evaluation_dataset_create`)銆?

### 11.4 澶辫触鍥炴粴

```bash
# 瑙﹀彂鏉′欢:nightly P1 璺岀牬闃堝€?+ 娌℃湁鐩稿叧 PR
# SRE 鎿嶄綔:
agent_update --agentName billing-agent-prod --version 3 --reactivate
```

鎴栬剼鏈寲:`scripts/rollback.py --agent <n> --to-version <v>`,鍛婅閲岀洿鎺ラ檮姝ゅ懡浠ゃ€?

---

## 12. 椋庨櫓涓庢渶浣冲疄璺?

| 椋庨櫓 | 缂撹В |
|------|------|
| **LLM judge 鐭ヨ瘑鎴鍋囬槼鎬?* | 璇勪及鍣?prompt 涓樉寮忓啓"鎺ュ彈鏉ユ簮鏍囨敞浣嗕綘涓嶈兘楠岃瘉鐨勪簨瀹?;real-time 鏁版嵁璇勪及浼樺厛鐪?`groundedness on retrieved context`,涓嶈鎷胯缁冮泦鐭ヨ瘑瀵?|
| **璇勪及婕傜Щ**(妯″瀷鍗囩骇鍚庡熀绾垮け鏁? | 姣忔鍗囩骇妯″瀷鍓?鍏堢敤鍚屼竴 dataset 鍦ㄦ柊鏃фā鍨嬩笂璺?baseline,璁板叆 manifest |
| **鏁版嵁闆嗘薄鏌?* | judge 妯″瀷涓?agent 妯″瀷涓嶈鍚屾;dataset 涓?production 鐢ㄦ埛杈撳叆瀹氭湡鍘婚噸 |
| **PII 娉勯湶鍒?trace** | 榛樿 `OTEL_GENAI_CAPTURE_MESSAGE_CONTENT=false`;鎴栧姞 SpanProcessor 鍦ㄥ鍑哄墠 redact;App Insights 绔?Data Collection Rules 鍏滃簳 |
| **鍚岀粍 evaluationId 琚敊璇噸鐢?* | 姣忔鏀?evaluators / thresholds **蹇呭紑鏂扮粍**;CI 鐢?evaluationName 鍚?datasetVersion + evaluatorVersion |
| **MCP server 100s 瓒呮椂** | 璇勪及鏃朵篃瑕佺湅 `evaluation_get` 鍐呴儴鐨?tool latency;闀夸换鍔℃媶鍒?|
| **璇勪及鎴愭湰澶辨帶** | judge 妯″瀷鐢ㄤ究瀹滄ā鍨?gpt-5-mini)鍋?P1/P2,P0 鎵嶇敤寮哄垽瀹?dataset 琛屾暟鎺у埗(seed 鈮?0,curated 鈮?00) |
| **`response_id` 閾捐矾鏂** | hosted agent 鑷姩鏈?鑷畾涔?MCP server 涓€瀹氳閫忎紶;MAF 鑷畾涔?span 涓€瀹氳 `set_attribute("gen_ai.response.id", ...)` |
| **鍥炴粴娌℃湁瀹¤** | `agent_update` 姣忔蹇呴』甯?`creationOptions.metadata.rollback_reason`,trace 鏃惰兘鎼?|
| **dataset 閫€鍖?*(杩愯惀鎵嬫姈鍒犱簡琛? | manifest.json 姣忎釜鐗堟湰闄?row count + sha256;CI 鏍￠獙 |
| **璇勪及鍣ㄧ増鏈笉涓€鑷?* | 璇勪及鍣?YAML 鍔?`version`;`testCases[].evaluators[].version` 寮哄埗閿?鍗囩骇鏃跺崌 v2,涓嶈鐩?v1 |

---

## 13. 鍙傝€冮摼鎺?

### 鏂囨。
- [Azure AI Foundry Cloud Evaluation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/develop/cloud-evaluation)
- [Built-in Evaluators](https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/observability)
- [Foundry Hosted Agents 姒傚康](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [Foundry Agent Tool Catalog](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/tool-catalog)
- [Application Insights for OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [OpenTelemetry GenAI Spans 璇箟绾﹀畾](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/)
- [OpenTelemetry GenAI Agent Spans](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/)
- [App Insights Alert Rules](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-overview)
- [KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

### 浠撳簱涓庢牱渚?
- [Microsoft Agent Framework (GitHub)](https://github.com/microsoft/agent-framework)
- [Foundry Samples 鈥?Hosted Agents (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [Foundry Samples 鈥?`08-observability`](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/08-observability)

### 閰嶅鏂囨。
- [`azd-foundry-research.md`](./azd-foundry-research.md) 鈥?Phase 1:provision
- [`agent-harness-architecture.md`](./agent-harness-architecture.md) 鈥?Phase 2:harness 鏋舵瀯

