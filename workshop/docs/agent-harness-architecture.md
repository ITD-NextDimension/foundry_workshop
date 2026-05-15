# Cloud-based Agent Harness 架构:Foundry + MAF + Hosted Agent + MCP

> **场景**:把 Microsoft Foundry(模型 + 服务端工具)、Hosted Agent(容器运行时)与 Microsoft Agent Framework(MAF,Python SDK)组装成一套面向**具体业务**的 cloud-based agent harness。
> **贯穿示例**:**企业客户支持 agent harness**(TriageAgent 路由 → TechSupportAgent / BillingAgent / KBAgent)。
> **配套文档**:基础设施部分见 [`azd-foundry-research.md`](./azd-foundry-research.md)(azd 服务主体登录 + 创建 Foundry/Model/Hosted Agent)。本文不重复 provision 细节,聚焦**应用架构层**。

---

## 0. TL;DR

**一句话**:harness 是把"**人格(personas)+ 技能(skills)+ 工具(tools, 两层)+ 编排(workflow / connected agents)+ 模型(Foundry model)+ 运行时(Hosted Agent 容器)**"按约定目录组织、按生命周期由 `azd` + `agentdev` + Foundry MCP 三套 CLI 串起来的应用工程模板。

**分层架构**:

```
┌───────────────────────────────────────────────────────────────┐
│  L4 编排层    workflow.yaml / WorkflowBuilder / Connected     │
│              Agents(谁调谁、什么条件、HITL)                  │
├───────────────────────────────────────────────────────────────┤
│  L3 应用层    Hosted Agent 容器 = MAF Agent                   │
│              ├── instructions ← personas/*.md (★ soul)        │
│              ├── context_providers=[SkillsProvider] ← skills/ │
│              ├── tools=[client-side @ai_function …] ← tools/  │
│              └── client = FoundryChatClient                   │
├───────────────────────────────────────────────────────────────┤
│  L2 模型与工具层  Foundry server-side tools                   │
│                  (File Search / Code Interpreter /            │
│                   AI Search / Bing / Memory / 远程 MCP)        │
│                  + Foundry Model Deployments                  │
├───────────────────────────────────────────────────────────────┤
│  L1 基础设施层    Foundry account/project + ACR + MI + RBAC   │
│                  (由 azd-ai-starter-basic + azd up 创建)       │
└───────────────────────────────────────────────────────────────┘
```

**一图速查**:

| 概念 | 是什么 | 存哪里 | 谁加载 |
|------|--------|--------|--------|
| **persona / soul** | 角色定义、行为边界、口吻 | `personas/<agent>.md` | `main.py` 读成字符串塞给 `Agent(instructions=...)` |
| **skill** | 完成某类任务的指令书 + 可选脚本 | `skills/<skill>/SKILL.md` + `skills/<skill>/scripts/` | MAF `SkillsProvider.from_paths` 自动发现 |
| **client-side tool** | 业务系统集成函数 | `tools/*.py`(`@ai_function`) | 显式作为 `tools=[...]` 传给 `Agent` |
| **server-side tool** | Foundry 提供的托管工具 | `agent.manifest.yaml` 或 `agent_update` | Foundry 后端;模型自动可见 |
| **MCP** | 跨进程标准工具协议 | 远程 endpoint / `mcp_servers/<name>/` | `MCPTool`(消费)或独立部署(暴露) |
| **subagent** | 被父 agent 调用的专科 agent | `src/<sub>/main.py` + `src/<sub>/agent.yaml` | `workflow.yaml` 或 `WorkflowBuilder` 或 connected_agents |

---

## 1. 调研目标与贯穿示例

### 1.1 目标

回答这些问题:

1. agent 的"**soul**"(人格/系统提示)在哪里、怎么存、怎么版本化、怎么在多 agent 间复用 guardrails?
2. **skill** 是什么?MAF 已经有原生机制,跟"自己写一坨 prompt"有什么区别?
3. **tool** 到底有几种?Foundry 提供的服务端 tool 和我自己 Python 写的函数 tool 怎么选?
4. **MCP** 在 harness 里能扮演几个角色?
5. 多个 agent(主 + 专科 sub-agents)怎么编排?声明式 vs 代码式 vs Foundry 原生?
6. 一个项目里所有这些**文件怎么组织**才不会乱?
7. 一套 **CLI 工具栈** 在 dev / deploy / ops 三个阶段分别用哪个命令?

### 1.2 贯穿示例:企业客户支持 agent harness

```
用户问题
   │
   ▼
[TriageAgent] ── 分类 ──┬─→ [TechSupportAgent]  + KB 检索 + 工单创建
                       ├─→ [BillingAgent]      + 退款额度计算 + CRM 更新
                       ├─→ [KBAgent]           + 文档检索 + 引用
                       └─→ 直接答 / 兜底
```

后文每章末尾给一段"**贯穿示例怎么落地**"。

---

## 2. 四层架构

### 2.1 L1 基础设施层

由 [Phase 1 文档](./azd-foundry-research.md) 已覆盖:`azd up` 一键创建 Foundry account + project + ACR + Managed Identity + RBAC + 模型部署。

harness 本层只关心**从** L1 取两个出参:

```bash
azd env get-value AZURE_AI_PROJECT_ENDPOINT      # L3 用
azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME # L3 用
```

### 2.2 L2 模型与工具层

L2 = **可用的模型部署** + **Foundry 提供的服务端 tool 与对应 connection**。这一层是 Foundry 控制面资源,不在容器里跑。

- 模型部署:`AI_PROJECT_DEPLOYMENTS` 数组(见 Phase 1 §5)
- 服务端 tool 清单(后续 §5.1 详述):File Search / Code Interpreter / Azure AI Search / Bing Grounding / Memory / Remote MCP / Function Calling(声明)
- 这些 tool 的 **connection**(API Key / Search resource / Bing resource)由 Foundry MCP `project_connection_*` 管理

> ⚠️ **关键概念**:L2 的 tool 是"**模型直接可调用**"的;在 hosted agent 里只需在 `agent.manifest.yaml` / `agent_update` 时声明,你的容器代码**完全看不到调用过程**,Foundry 后端代理执行后把结果塞进上下文。

### 2.3 L3 应用层

L3 = **一个或多个 Hosted Agent 容器**,每个容器跑一个 MAF `Agent` 实例,通过 [`azure-ai-agentserver-agentframework`](https://pypi.org/project/azure-ai-agentserver-agentframework/) 适配器暴露 Responses API。

容器内一个 agent 的"五件套":

```python
agent = Agent(
    client=FoundryChatClient(...),                # 模型来自 L2
    instructions=load_persona("triage-agent.md"), # ★ soul
    context_providers=[skills_provider],          # ★ skills
    tools=[crm_lookup, create_ticket],            # ★ client-side tools
    default_options={"store": False},
)
ResponsesHostServer(agent).run()                  # 启 8088 HTTP
```

server-side tool **不在这里**写,而是在 `agent.manifest.yaml` 里声明给 Foundry。

### 2.4 L4 编排层

L4 = **多个 L3 容器之间怎么协作**。三种方式可选(§7 详述):

| 方式 | 谁执行 |
|------|--------|
| `workflow.yaml`(declarative) | Foundry Workflow runtime |
| `WorkflowBuilder`(MAF Python API) | 父 agent 的容器 |
| `connected_agents` 字段 | Foundry 后端 |

**贯穿例落地**:Phase 1 创建了 Foundry + `gpt-4o-mini` + `text-embedding-3-small`;L2 上挂一个 Azure AI Search connection(KB 索引)+ 一个 Memory store;L3 部署 4 个容器(`triage`、`tech-support`、`billing`、`kb`);L4 用 `workflow.yaml` 让 triage 路由到三个专科 agent。

---

## 3. Agent / Subagent Soul

### 3.1 为什么单独抽出 persona

"soul" = **角色边界 + 任务范围 + 口吻 + 拒绝策略 + 引用格式**。它既不是"如何完成具体任务"(那是 SKILL),也不是"我有哪些工具"(那是 tools)。把它独立成 markdown 有这些好处:

- 多 agent 共享 guardrails(`personas/shared/guardrails.md` 在主 persona 里 `{{include}}`)
- 非工程同事(legal / PM)可以直接审阅
- 版本化清晰(git diff 一眼看出语气变化)
- 评估时 persona 可作为变量,A/B 测两个 persona 看哪个 task_adherence 高

### 3.2 文件约定

```text
personas/
  triage-agent.md
  tech-support-agent.md
  billing-agent.md
  kb-agent.md
  shared/
    guardrails.md          # 安全/合规边界(跨 agent)
    citation-format.md     # 引用约定(跨 KB 类 agent)
    handoff-protocol.md    # 子 agent 之间的交接术语
```

`triage-agent.md` 模板:

```markdown
---
agent: triage-agent
version: 1.0.0
owner: support-team@contoso.com
extends:
  - shared/guardrails.md
  - shared/handoff-protocol.md
---

# Role

你是 Contoso 企业客户支持的总台 agent。你的唯一职责是把用户问题**分类并路由**给最合适的专科 agent,不要尝试自己回答技术或账单问题。

# Categories

1. `Technical` — 产品 bug / 配置 / API
2. `Billing` — 发票 / 退款 / 用量
3. `KB` — 通用知识库可答
4. `Clarification` — 需追问

# Output

每次返回严格 JSON: `{"category": "...", "reply": "...", "needsClarification": bool}`

# Tone

简短、专业、不带情绪。

{{include: shared/guardrails.md}}
{{include: shared/handoff-protocol.md}}
```

### 3.3 加载到 `Agent(instructions=...)`

```python
# src/shared/persona.py
import re
from pathlib import Path

PERSONAS_ROOT = Path(__file__).resolve().parents[2] / "personas"

def load_persona(name: str) -> str:
    text = (PERSONAS_ROOT / name).read_text(encoding="utf-8")
    # 简易 include 替换;生产可用 jinja2
    def _sub(m):
        return load_persona(m.group(1))
    return re.sub(r"\{\{include:\s*([^\}]+?)\s*\}\}", _sub, text)
```

```python
# src/triage_agent/main.py
agent = Agent(
    client=FoundryChatClient(...),
    instructions=load_persona("triage-agent.md"),
    ...
)
```

### 3.4 persona vs SKILL.md vs agent.yaml

| 文件 | 回答的问题 | 谁读 |
|------|-----------|------|
| `personas/<name>.md` | **我是谁?** 边界、口吻、拒绝策略 | MAF Agent 的 `instructions` 参数 |
| `skills/<skill>/SKILL.md` | **怎么完成 X 任务?** 调用什么脚本 / 步骤 | MAF `SkillsProvider` 在需要时载入 |
| `src/<agent>/agent.yaml` | **Foundry 要怎么部署我?** kind/资源/协议/环境变量 | Foundry control plane(部署时) |
| `src/<agent>/agent.manifest.yaml` | **我要哪些 server-side tool 和模型?** | `azd ai agent` 扩展生成 |

### 3.5 贯穿示例

`personas/shared/guardrails.md` 列出"绝不泄露其他客户数据 / 涉及法律咨询直接转人工 / 不承诺退款额度上限"。三个专科 agent 都通过 `extends` 复用,避免重复维护。

---

## 4. Skills(MAF SkillsProvider)

### 4.1 工作机制

MAF `agent_framework` Python 包内置 [`SkillsProvider`](https://github.com/microsoft/agent-framework),它是一个 `ContextProvider`:

1. 启动时扫描 `skill_paths` 下的子目录,每个目录里有一个 `SKILL.md`
2. 把每个 skill 的**名字 + 一行描述 + 可触发场景**注入模型的可调用工具/上下文清单
3. 模型决定调用某个 skill 时,SkillsProvider 加载 `SKILL.md` 全文进上下文;如果 skill 声明了 `scripts/`,通过 `script_runner` 沙箱执行

### 4.2 目录约定

```text
skills/
  refund-quote/
    SKILL.md
    scripts/
      quote.py                # 输入 amount/tier,输出可退金额
  kb-search/
    SKILL.md                  # 纯 prompt,无脚本
  ticket-template/
    SKILL.md
    templates/
      tech-bug.md
      billing-dispute.md
```

`SKILL.md` 头部建议加 frontmatter,便于评估时筛选:

```markdown
---
name: refund-quote
description: 根据客户 tier + 用量历史计算可退金额上限
triggers:
  - 用户问"我能退多少"
  - 账单争议且涉及金额
scripts:
  - quote.py
---

# 步骤

1. 用 CRM 工具读出用户 tier
2. 调用 `scripts/quote.py --tier <T> --amount <A>`
3. 把脚本输出 JSON 中的 `maxRefund` 给用户,并附 `policyVersion`
4. 如果 `maxRefund < A`,**必须**先告知差额来源
```

### 4.3 关键代码片段(直接来自 `foundry-samples` 07-skills)

```python
from agent_framework import Agent, SkillsProvider
from pathlib import Path

def run_local_skill_script(skill, script, args=None):
    # 校验 script.path 不越出 skill 目录,subprocess.run 限时 60s
    ...

skills_provider = SkillsProvider.from_paths(
    skill_paths=Path(__file__).parent.parent.parent / "skills",
    script_runner=run_local_skill_script,
)

agent = Agent(
    client=FoundryChatClient(...),
    instructions=load_persona("billing-agent.md"),
    context_providers=[skills_provider],
)
```

> 沙箱要点:`script_runner` 必须**绝对路径解析 + 越界检查 + 超时**;Foundry hosted agent 容器是临时文件系统,脚本输出文件按 `$HOME/<subdir>/` 约定。

### 4.4 Skill 与 Tool / Persona 的取舍

| 选 Skill | 选 Tool | 选 Persona |
|---------|--------|-----------|
| 任务**步骤多 + 可文档化**,模型按文档执行 | 单次原子操作(查 CRM、发邮件) | 角色身份 / 拒绝策略 / 口吻 |
| 内容可能频繁更新,运营也能改 | API 调用签名固定 | 一次定义,跨 agent 复用 |
| 可能附带模板 / 表单 / 脚本 | 需要返回结构化数据给模型 | 不需要"调用" |

### 4.5 贯穿示例

`refund-quote/SKILL.md` 给 BillingAgent 用;`ticket-template/SKILL.md` 给 TechSupportAgent 用;`kb-search/SKILL.md` 给 KBAgent 用。每个 skill 独立 git history,运营改文档不需要发版容器。

---

## 5. Tools 双层模型

### 5.1 Foundry server-side tool(L2)

模型直接调,**容器代码看不到**,在 `agent.manifest.yaml` 或 `agent_update` API 声明。

| Tool | 用途 | 是否需要 Connection |
|------|------|--------------------|
| `code_interpreter` | 沙箱 Python(数据分析 / 出图 / 文件) | 否 |
| `file_search` | 基于 vector store 的文件检索 | 否(但需要先建 vector store) |
| `web_search_preview` | 实时公网检索 | 否 |
| `bing_grounding` | Bing 搜索 + 引用 | 是(Bing connection) |
| `azure_ai_search` | 私有索引向量/混合检索 | 是(AI Search connection) |
| `memory_search` | 长期记忆(用户偏好) | 否(但需要 embedding 模型 + memory store) |
| `mcp` | 远程 MCP 服务 | 视服务而定 |
| `function`(声明式) | 客户端函数调用(返回 schema,模型决定调用) | 否 |

在 `agent.manifest.yaml` 中声明示例:

```yaml
# src/billing_agent/agent.manifest.yaml
agent:
  name: billing-agent
  instructions: ${BILLING_INSTRUCTIONS}   # 也可放 persona 文件路径,部署时注入
  model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}
  tools:
    - type: file_search
      file_search:
        vector_store_ids:
          - ${BILLING_DOCS_VECTOR_STORE_ID}
    - type: code_interpreter
    - type: memory_search
      memory_search:
        store_id: ${SUPPORT_MEMORY_STORE_ID}
        scope: "{{$userId}}"
```

> ⚠️ **现实中的混合**:hosted agent 容器跑 MAF 时,**也可以**主动调用 Foundry 服务端 tool,但只是为了在容器侧拿到原始结果再做后处理——大多数场景应该把 server-side tool 配在 agent definition 上,让 Foundry 自动透传到模型。

### 5.2 MAF client-side function tool(L3,在你的容器里执行)

```python
# tools/crm.py
from agent_framework import ai_function
from pydantic import BaseModel

class CrmLookupResult(BaseModel):
    tier: str
    contractEnd: str
    arr: float

@ai_function(
    name="crm_lookup",
    description="根据 customerId 查询 CRM 中的合同等级、ARR、到期时间。"
)
async def crm_lookup(customer_id: str) -> CrmLookupResult:
    # 真实实现:httpx 调内部 API,带 MI token
    return await _internal_crm.get(customer_id)
```

```python
# src/billing_agent/main.py
from tools.crm import crm_lookup
from tools.ticketing import create_ticket
from tools.handoff import handoff_to_tech

agent = Agent(
    client=FoundryChatClient(...),
    instructions=load_persona("billing-agent.md"),
    context_providers=[skills_provider],
    tools=[crm_lookup, create_ticket, handoff_to_tech],
)
```

### 5.3 选型决策矩阵

| 场景 | 选 Foundry server-side | 选 MAF client-side |
|------|----------------------|-------------------|
| 文件 / 文档检索 | ✅ `file_search` / `azure_ai_search` | ❌ |
| 公网搜索 | ✅ `web_search_preview` / `bing_grounding` | ❌ |
| 沙箱跑数据分析 | ✅ `code_interpreter` | ❌ |
| 跨会话记忆 | ✅ `memory_search` | ❌(自己存) |
| 调内部 API(CRM / 工单) | ❌ | ✅ `@ai_function` |
| 修改业务状态(创建工单 / 发邮件) | ❌ | ✅(便于审计 + IAM) |
| 调用 subagent | ❌ | ✅(`handoff_to_<name>` 客户端函数) |
| 已是公开标准 MCP server | ✅(`mcp` server-side) | ✅(也能客户端) |

口诀:**读 / 检索 / 沙箱 → server-side;写 / 改状态 / 业务集成 → client-side**。

### 5.4 贯穿示例

- BillingAgent:`file_search`(账单条款 KB,server-side) + `crm_lookup`(client-side) + `create_refund`(client-side)
- TechSupportAgent:`azure_ai_search`(产品文档,server-side) + `create_ticket`(client-side)
- KBAgent:`file_search` + `web_search_preview`(都 server-side)

---

## 6. MCP 全面接入

### 6.1 消费远程 MCP(把外部 MCP server 接进 agent)

server-side 写法:

```yaml
tools:
  - type: mcp
    mcp:
      server_label: github
      server_url: https://api.githubcopilot.com/mcp
      require_approval: always       # 强制每次审批 ★
      allowed_tools: [search_issues, list_prs]
      project_connection_id: ${GITHUB_PAT_CONNECTION_ID}
```

审批回路:

1. Agent 触发 MCP tool → Foundry 返回 `mcp_approval_request` 项
2. 你的客户端(或专门的审批 UI)审 tool name + args
3. 提交 `McpApprovalResponse(approve=True/False)` + `previous_response_id`
4. Agent 继续完成

> 100s 超时;Teams 发布的 agent 不支持身份穿透;网络隔离 Foundry 不能用同 VNET 的私有 MCP。

### 6.2 暴露自己的 MCP server(把内部能力 MCP 化)

Foundry **只接受远程** MCP endpoint,所以本地 stdio MCP 必须先部署成公网/VNET 服务。两条主流路径:

| 平台 | 模板 | 适用 |
|------|------|------|
| **Azure Container Apps** | [`Azure-Samples/mcp-container-ts`](https://github.com/Azure-Samples/mcp-container-ts) | 任意语言;持续运行;天然适合复杂状态 |
| **Azure Functions** | [`Azure-Samples/mcp-sdk-functions-hosting-python`](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python) | Python/Node/.NET/Java;key 认证;按调用计费 |

harness 目录里的位置:

```
mcp_servers/
  internal-kb/                # 把内部 wiki 暴露成 MCP
    src/                      # FastMCP / TypeScript MCP
    Dockerfile                # 推 ACR(可以和 hosted agent 复用)
    azure.yaml                # 也由 azd 编排部署
  pricing-rules/              # 把定价规则引擎 MCP 化
    function_app/
    host.json
```

> 命名建议:`mcp_servers/<domain>-<role>/`,部署后给 agent 用一个 `api_key` connection 引用。

### 6.3 本地 MCP 调试

```bash
# 方式 A:agentdev(AI Toolkit)
pip install agent-dev-cli --pre
agentdev run src/billing_agent/main.py --port 8087   # 起 agent
agentdev inspect                                      # Agent Inspector UI

# 方式 B:本地把自己的 MCP server 跑成 stdio,让 Claude Desktop / VS Code Copilot 直连验证
python mcp_servers/internal-kb/src/server.py
```

调试时把环境变量切换成 `FOUNDRY_MODEL_DEPLOYMENT_NAME=...`(指向同一个 Foundry 项目);MAF 的 `FoundryChatClient` 用 `DefaultAzureCredential` 走 `az login`/`azd auth` 的开发者凭据。

### 6.4 贯穿示例

- 消费:把 `https://api.githubcopilot.com/mcp` 接进 TechSupportAgent,模型能查内部 issue
- 暴露:把"产品订阅规则引擎"放在 `mcp_servers/pricing-rules/`,部署到 Functions,BillingAgent 通过 MCP 调用
- 调试:本地 `agentdev run` 同时跑 BillingAgent + Pricing MCP server,Agent Inspector 看 trace

---

## 7. Sub-agent 编排

### 7.1 Declarative `workflow.yaml`(推荐做主路由)

`foundry-samples` 的 `09-declarative-customer-support` 给出完整骨架:

```yaml
kind: Workflow
trigger:
  kind: OnConversationStart
  id: customer_support_triage
  actions:
    - kind: InvokeAzureAgent
      id: triage
      agent: { name: TriageAgent }
      output: { autoSend: false, responseObject: Local.Triage }

    - kind: ConditionGroup
      conditions:
        - condition: =Local.Triage.NeedsClarification
          actions:
            - kind: SendActivity
              activity: { text: =Local.Triage.ClarificationQuestion }
        - condition: =Local.Triage.Category = "Technical"
          actions:
            - kind: InvokeAzureAgent
              agent: { name: TechSupportAgent }
              output: { autoSend: true }
        - condition: =Local.Triage.Category = "Billing"
          actions:
            - kind: InvokeAzureAgent
              agent: { name: BillingAgent }
              output: { autoSend: true }
      elseActions:
        - kind: SendActivity
          activity: { text: =Local.Triage.Reply }
    - kind: EndWorkflow
```

优点:

- 业务团队可读可改,没有 Python
- Foundry runtime 原生支持 trace + 审批 + HITL
- 整个 workflow 可以**和 agent 一样**被 deploy 和 invoke

### 7.2 MAF `WorkflowBuilder`(代码式,复杂控制流首选)

```python
from agent_framework import WorkflowBuilder

w = (WorkflowBuilder()
  .add_agent("triage", triage_agent)
  .add_agent("tech", tech_agent)
  .add_agent("billing", billing_agent)
  .route("triage", lambda s: s["category"], {
      "Technical": "tech",
      "Billing": "billing",
  })
  .build())

response = await w.run(input="...")
```

支持的进阶模式:reflection、switch-case、fan-out / fan-in、loop、human-in-the-loop。

### 7.3 Connected Agents(Foundry 原生字段)

在父 agent 定义里直接挂子 agent 引用:

```json
{
  "kind": "prompt",
  "model": "gpt-4o-mini",
  "instructions": "...",
  "connected_agents": [
    {"agent_reference": "TechSupportAgent"},
    {"agent_reference": "BillingAgent"}
  ]
}
```

最省事,但路由逻辑藏在父 agent 的 prompt 里,可观察性最差。

### 7.4 三者怎么选

| 选项 | 路由可观察 | 业务可改 | 控制流复杂度 | trace 友好 |
|------|----------|----------|------------|-----------|
| `workflow.yaml` | ✅ | ✅ | 中等(条件 + 顺序) | ✅(Foundry 原生) |
| `WorkflowBuilder` | 部分 | ❌(代码) | ✅ 任意 | 需要 OpenTelemetry 埋点 |
| `connected_agents` | ❌(藏在 prompt) | ❌ | 低 | 部分 |

**推荐组合**:**主路由用 `workflow.yaml`**,内部专科 agent 如果还需要 reflection / 自我修正,**内部再用 `WorkflowBuilder`**。Connected Agents 只用于**极简 demo**。

### 7.5 贯穿示例

- `workflows/triage.workflow.yaml`:Triage 路由
- TechSupportAgent **内部**用 `WorkflowBuilder` 做"先 RAG → 检查置信度 → 不够则追问"的 reflection loop
- 整个项目里没有 `connected_agents`(避免 prompt 黑盒)

---

## 8. 目录与文件约定

```text
support-agent-harness/
├── azure.yaml                            # azd 入口
├── infra/                                 # bicep(starter 模板)
├── .azure/<env>/.env                      # azd 环境变量
├── .foundry/
│   ├── agent-metadata.yaml                # project endpoint / agent 名 / testCases
│   ├── datasets/                          # 评估数据集本地缓存
│   ├── evaluators/                        # 评估器定义
│   └── results/                           # 评估结果
├── personas/                              # ★ L3: soul
│   ├── triage-agent.md
│   ├── tech-support-agent.md
│   ├── billing-agent.md
│   ├── kb-agent.md
│   └── shared/
│       ├── guardrails.md
│       ├── citation-format.md
│       └── handoff-protocol.md
├── skills/                                # ★ L3: MAF SkillsProvider
│   ├── refund-quote/
│   │   ├── SKILL.md
│   │   └── scripts/quote.py
│   ├── ticket-template/
│   │   ├── SKILL.md
│   │   └── templates/{tech-bug,billing-dispute}.md
│   └── kb-search/SKILL.md
├── tools/                                 # ★ L3: MAF client-side tools
│   ├── crm.py                             # @ai_function: 查 CRM
│   ├── ticketing.py                       # @ai_function: 创建/更新工单
│   ├── handoff.py                         # @ai_function: 调用 subagent
│   └── _shared/auth.py                    # MI / DefaultAzureCredential 工厂
├── mcp_servers/                           # ★ L2 扩展: 自暴露 MCP
│   ├── pricing-rules/                     # Azure Functions 部署
│   │   ├── function_app.py
│   │   ├── host.json
│   │   └── requirements.txt
│   └── internal-kb/                       # Azure Container Apps 部署
│       ├── src/server.py                  # FastMCP
│       ├── Dockerfile
│       └── azure.yaml
├── workflows/                             # ★ L4: declarative
│   └── triage.workflow.yaml
├── src/                                   # ★ L3: 一个 agent 一个子目录
│   ├── triage_agent/
│   │   ├── main.py                        # 装配 SkillsProvider + tools + persona
│   │   ├── agent.yaml                     # Foundry hosted agent 定义
│   │   ├── agent.manifest.yaml            # 模型 + server-side tools
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── .env.example
│   ├── tech_support_agent/
│   ├── billing_agent/
│   ├── kb_agent/
│   └── shared/                            # 跨 agent 复用
│       ├── persona.py                     # load_persona() with include
│       ├── client_factory.py              # FoundryChatClient + 凭据
│       └── skill_runner.py                # 沙箱 script_runner
├── tests/
│   ├── unit/                              # tools / skill_runner 单测
│   └── eval/                              # Foundry 评估场景
└── README.md
```

### 8.1 每个文件类型的"唯一职责"

| 文件 | 唯一职责 | 谁负责 |
|------|---------|--------|
| `personas/*.md` | 角色 + 边界 + 口吻 | PM + Legal |
| `skills/*/SKILL.md` | 具体任务的步骤说明 | 业务运营 + 研发 |
| `skills/*/scripts/*.py` | 确定性算法 / 模板生成 | 研发 |
| `tools/*.py` | 业务系统 API 集成 | 研发 |
| `workflows/*.workflow.yaml` | 多 agent 路由 | PM + 研发 |
| `src/<agent>/main.py` | 组装 Agent + 启动 HTTP server | 研发 |
| `src/<agent>/agent.yaml` | Foundry 部署元数据(kind/资源/协议) | 研发 |
| `src/<agent>/agent.manifest.yaml` | 模型 + server-side tools 声明 | 研发 |
| `mcp_servers/*/` | 自暴露 MCP 服务实现 | 平台研发 |
| `.foundry/agent-metadata.yaml` | 环境 + agent 名 + 评估配置 | 研发 |
| `azure.yaml` / `infra/` | 基础设施(Phase 1 文档) | DevOps |

### 8.2 命名规约

- agent 名 / 镜像名:小写连字符,例 `tech-support-agent`(MAF agent 名要求 alphanumeric + `-`,首尾 alphanumeric,≤63 字符)
- skill 目录名:动词-名词,例 `refund-quote`、`ticket-template`、`kb-search`
- persona 文件名 = agent 名 + `.md`
- workflow 文件名:`<scenario>.workflow.yaml`

### 8.3 共享代码放哪

- **跨 agent Python**:`src/shared/`(被 `src/<agent>/main.py` 通过 `..shared` 导入)
- **跨 agent prompt**:`personas/shared/`
- **跨 agent skill**:直接放在 `skills/<name>/`,由每个 agent 的 SkillsProvider 独立加载

---

## 9. CLI 工具栈与生命周期对照表

| 阶段 | CLI / Tool | 命令 | 干什么 |
|------|-----------|------|--------|
| **provision** | `az` | `az login --service-principal ...` | 控制面登录 |
| **provision** | `azd` | `azd auth login --client-id ...` | Developer CLI 登录 |
| **provision** | `azd` | `azd init -t Azure-Samples/azd-ai-starter-basic` | 拉模板 |
| **provision** | `azd` | `azd up` | 一键 provision + 部署 |
| **dev** | `agentdev` | `agentdev run src/<agent>/main.py --port 8087` | 本地起 agent HTTP |
| **dev** | `agentdev` | AI Toolkit 中 `ai-mlstudio.openTestTool` | 打开 Agent Inspector UI |
| **dev** | `debugpy` | `debugpy --listen 127.0.0.1:5679` | 断点调试 |
| **dev** | `pytest` | `pytest tests/unit` | client-side tool / skill_runner 单测 |
| **deploy** | `azd` | `azd ai agent init -m src/<agent>/agent.yaml` | 把 agent 注册进 azure.yaml |
| **deploy** | `azd` | `azd deploy <service-name>` | 单独重发某个 agent 容器 |
| **deploy** | Foundry MCP | `agent_definition_schema_get` | 取最新 schema 验证 |
| **deploy** | Foundry MCP | `agent_update` | 创建/更新 agent(支持 cloneRequest) |
| **deploy** | Foundry MCP | `agent_container_control` | 启停 hosted agent 容器 |
| **deploy** | Foundry MCP | `agent_container_status_get` | 轮询 Running/Failed |
| **deploy** | Foundry MCP | `project_connection_create` | 建 MCP / Search / Bing 连接 |
| **invoke** | curl / SDK | `POST <endpoint>/agents/<name>/responses` | 调 agent |
| **invoke** | Foundry MCP | `agent_invoke` | MCP 工具直发 |
| **observe** | Foundry MCP | `evaluation_run_create` + `evaluator_catalog_get` | 跑评估 |
| **observe** | Foundry MCP | `trace_search` | 查 App Insights customEvents |
| **observe** | Foundry MCP | `prompt_optimize` | 基于评估优化 instructions/persona |
| **ops** | `azd` | `azd down --purge --force` | 拆 RG(慎用) |

---

## 10. 端到端开发流程

### 10.1 First-Time Setup

```
1. (Phase 1) azd auth login + azd init -t azd-ai-starter-basic
2. 在 src/ 下 azd ai agent init -m <agent.yaml>(每个 agent 一次)
3. 把 personas/ skills/ tools/ workflows/ 目录建好
4. azd up → 全部 agent 部署上去 + 创建 Foundry 资源
5. agent-metadata.yaml 持久化 project endpoint / agent names
```

### 10.2 日常迭代

```
本地循环:
   修改 persona / skill / tool
   ↓
   agentdev run src/<agent>/main.py --port 8087
   ↓
   Agent Inspector 验证
   ↓
   pytest tests/unit

云上:
   azd deploy <agent-service-name>     # 只重发改动的容器
   ↓
   agent_container_status_get 等 Running
   ↓
   evaluation_run_create 跑 P0 smoke
   ↓
   trace_search 看新版本失败 case
```

### 10.3 增加一个新专科 sub-agent

```
1. 新增 personas/<new>-agent.md
2. 新增 src/<new>_agent/(main.py + agent.yaml + agent.manifest.yaml + Dockerfile)
3. 在 workflows/triage.workflow.yaml 加一条 ConditionGroup 分支
4. 如有专属 skill,新增 skills/<new>-skill/SKILL.md
5. azd deploy <new>-agent + azd deploy triage(workflow 更新)
6. 评估:eval-datasets 加该专科的测试用例
```

### 10.4 增加一个新工具

```
决策树:
  纯检索 / 公网 / 沙箱        → 加到 agent.manifest.yaml(server-side)
  调内部 API / 写状态          → tools/*.py 加 @ai_function,改 src/<agent>/main.py
  跨多个 agent / 想标准协议    → mcp_servers/<name>/ 实现 + 部署 + project_connection_create
```

---

## 11. 关键风险与最佳实践

| 风险 | 缓解 |
|------|------|
| **Persona 漂移**:多 agent 各自维护 guardrails 不一致 | `personas/shared/guardrails.md` 强制 include;评估里加 indirect_attack / safety 评估器 |
| **Skill 越权执行**:script_runner 被 prompt-injection 操控 | 绝对路径解析 + 目录边界检查 + 白名单 cmd + 超时(参考 07-skills 实现) |
| **Tool 滥用**:client-side tool 修改业务状态没有审计 | 每个 `@ai_function` 内部记 OpenTelemetry span;敏感操作走 MCP `require_approval=always` |
| **MCP 100s 超时** | 服务端做异步 + 状态码 + 短轮询;或拆分 tool |
| **Sub-agent 路由不可见** | 用 `workflow.yaml` 替代 `connected_agents`;主路由 trace 必须包含 categoryDecision |
| **环境耦合**:dev 写死 endpoint | 全走 `.azure/<env>/.env` + `agent-metadata.yaml` 的 `environments.<env>.*` |
| **Persona / Skill 没有版本** | frontmatter 加 `version`;每次发布在 `agent-metadata.yaml` 记 personaVersion |
| **冷启动慢** | `agent.yaml` 设 `minReplicas: 1`(成本可控前提) |
| **Hosted agent 镜像必须 linux/amd64** | Dockerfile 设 `--platform linux/amd64`,或 `docker.remoteBuild: true` 走 ACR Tasks |
| **服务主体缺 User Access Administrator** | 参考 Phase 1 文档 §2.2 RBAC 矩阵 |

---

## 12. 参考链接

### 文档
- [Microsoft Agent Framework 概述](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Agent Framework Quick Start](https://learn.microsoft.com/agent-framework/tutorials/quick-start)
- [Microsoft Agent Framework User Guide](https://learn.microsoft.com/agent-framework/user-guide/overview)
- [Foundry Hosted Agents 概念](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [Foundry Agent Runtime Components](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/runtime-components)
- [Foundry Agent Tool Catalog](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/tool-catalog)
- [Foundry MCP Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/model-context-protocol)
- [Foundry File Search Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/file-search)
- [Foundry Azure AI Search Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/azure-ai-search)
- [Foundry Code Interpreter Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/code-interpreter)
- [Foundry Function Calling](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/function-calling)
- [Foundry Memory](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/what-is-memory)
- [`azd ai agent` extension](https://aka.ms/azdaiagent/docs)

### 仓库与样例
- [Microsoft Agent Framework (GitHub)](https://github.com/microsoft/agent-framework)
- [Foundry Samples — Hosted Agents (Python)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [Foundry Samples — `07-skills`(SkillsProvider 示例)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/07-skills)
- [Foundry Samples — `09-declarative-customer-support`(workflow.yaml 示例)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/09-declarative-customer-support)
- [Foundry Samples — `05-workflows`(WorkflowBuilder 示例)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/05-workflows)
- [MCP server on Azure Container Apps (TS 模板)](https://github.com/Azure-Samples/mcp-container-ts)
- [MCP server on Azure Functions (Python 模板)](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python)
- [`azd-ai-starter-basic` 模板](https://github.com/Azure-Samples/azd-ai-starter-basic)

### 配套文档
- [`azd-foundry-research.md`](./azd-foundry-research.md) — Phase 1:azd 服务主体登录 + 创建 Foundry/Model/Hosted Agent
