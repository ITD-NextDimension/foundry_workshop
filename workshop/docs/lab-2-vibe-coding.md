# Lab 2 · GitHub Copilot vibe coding 业务 agent harness(55 min)

## 2.1 学习目标

- 用 Copilot 在指令式提示下生成 **Persona(Soul)** + **Skill(Skills)** + **`@ai_function`(Tools)** 三件套
- 理解 `personas/` / `skills/` / `tools/` 目录约定
- 本地 `agentdev run` 起 agent + Agent Inspector 看 trace

## 2.2 5 个 mini-milestone

### M1 · Persona / Soul(10 min)

#### Track A 范例

在 VS Code 里打开 `track-A/personas/shared/guardrails.md`,然后用 Copilot Chat:

```text
@workspace 参考 #file:personas/shared/guardrails.md 与 #file:personas/billing-agent.md,
生成 personas/refund-specialist.md,角色是"退款专员",边界:
1. 只处理退款相关问题,其它转 TriageAgent
2. Tier=Free 直接拒绝
3. 输出 JSON: {decision, refundEstimate, policyVersion, escalateTo}
frontmatter 含 version: 1.0.0, owner: refund-team@contoso.com, extends: shared/guardrails.md
```

#### Track B 范例(以"IT 工单"为例)

```text
@workspace 参考 #file:track-B-templates/it-ticket/persona.template.md,
生成我自己的 IT 工单 agent persona:
公司是一家 SaaS,有 product / network / account 三类工单;
不能承诺 SLA,统一引导用户附截图;
输出 JSON: {category, priority, suggestedAssignee}
```

#### 出口检查点

```powershell
# Persona lint(检查 frontmatter / include 语法)
python ..\workshop-scripts\lint-persona.py personas\<your-agent>.md
```

应输出:`✅ persona <name> OK · extends=[..] · version=1.0.0`

### M2 · Skill / SkillsProvider(10 min)

#### Track A 范例

```text
@workspace 在 skills/refund-quote/ 下生成 SKILL.md + scripts/quote.py:
SKILL.md 4 步:1) 用 crm_lookup 读 tier;2) 调用 scripts/quote.py;
3) 输出 maxRefund + policyVersion;4) 若 maxRefund < 请求,告知差额来源
scripts/quote.py 接受 --tier --amount,返回 JSON {maxRefund, policyVersion, capped}
策略:Enterprise 50% 上限 30 天;Business 25% 上限 14 天;Free 拒绝。
```

#### 验证

```powershell
python track-A\skills\refund-quote\scripts\quote.py --tier Enterprise --amount 1000
# {"maxRefund": 500, "policyVersion": "v3.2", "capped": true}
```

### M3 · Client-side Tools(10 min)

#### Track A 范例

```text
@workspace 在 tools/crm.py 写 @ai_function crm_lookup,签名:
async def crm_lookup(customer_id: str) -> CrmLookupResult
result 含 tier(Enterprise/Business/Free)/ contractEnd / arr。
先用本地 dict mock,真正的 HTTPX 调用留 TODO。
描述写中文,模型才知道何时调用。
```

#### 验证

```powershell
pytest track-A\tests\unit\test_tools.py -v
```

### M4 · 组装 + 本地跑通(15 min)

#### 让 Copilot 帮你装配

`src/billing_agent/main.py`(workshop 已有骨架,你可以改名 + 加你的 tools):

```python
from agent_framework import Agent, SkillsProvider
from agent_framework.openai import FoundryChatClient
from azure_ai_agentserver_agentframework import ResponsesHostServer
from pathlib import Path
import os

from tools.crm import crm_lookup
from tools.ticketing import create_ticket
from src.shared.persona import load_persona

skills_provider = SkillsProvider.from_paths(
    skill_paths=[Path(__file__).resolve().parents[2] / "skills"],
)

agent = Agent(
    client=FoundryChatClient(
        endpoint=os.environ["AZURE_AI_PROJECT_ENDPOINT"],
        deployment_name=os.environ["FOUNDRY_MODEL_DEPLOYMENT_NAME"],
    ),
    instructions=load_persona("billing-agent.md"),
    context_providers=[skills_provider],
    tools=[crm_lookup, create_ticket],
    default_options={"store": False},
)

if __name__ == "__main__":
    ResponsesHostServer(agent).run(port=8087)
```

#### 启动

```powershell
$env:AZURE_AI_PROJECT_ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT
$env:FOUNDRY_MODEL_DEPLOYMENT_NAME = azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME
pip install -r requirements.txt
agentdev run src/billing_agent/main.py --port 8087
```

第二个终端:

```powershell
$body = @{ input = "我是 Acme 企业版客户,上月用量 10%,能退多少?" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

应看到 JSON 含 `refundEstimate` 字段。

### M5 · Agent Inspector + 失败案例修正(10 min)

```powershell
agentdev inspect
```

浏览器自动开 Agent Inspector UI。

#### 故意"激怒"agent

发一条:`"我是免费版,要退 1 亿"`,看 persona 拒绝行为。
然后改 `personas/billing-agent.md` 加强一条 "对 Free tier 不讨价还价,直接转 TriageAgent",本地复现。

#### 用 Copilot 反查 trace 含义

选中 Inspector 里 `execute_tool` 那行 → 截图 → `Ctrl+I` 给 Copilot:`explain why this tool was called`.

## 2.3 Copilot 使用心法

| 任务类型 | 最佳工具 | 模板 |
|---------|---------|------|
| 生成 markdown | Copilot Chat + `#file:` 引用现有文件 | `@workspace 参考 #file:X 生成 Y,要求 ...` |
| 写 Python tool | Inline `Ctrl+I` 在空函数里展开 | "写 @ai_function...，参数...，pydantic 返回...，描述用中文" |
| 重构加超时/日志 | 选中 → `Ctrl+I` | "add 30s timeout and structured logging via opentelemetry" |
| 解释 trace span | Copilot Chat + 截图 | "explain this span tree and find the slowest step" |

详见 [`cheatsheet-copilot.md`](cheatsheet-copilot.md)。

## 2.4 出口检查点

✅ `personas/<agent>.md` + `skills/<skill>/SKILL.md` + `tools/<tool>.py` 三件齐全且 lint 通过
✅ `agentdev run` 启动无错,本地 POST 返回业务 JSON
✅ Agent Inspector 看到完整 conversation(invoke_agent / execute_tool / chat 三类 span)

## 2.5 故障速查

| 现象 | 处理 |
|------|------|
| `FoundryChatClient` 401 | `az account get-access-token --resource https://ai.azure.com` 确认能拿 token;不行就 `azd auth login` 重登 |
| `agentdev run` 端口冲突 | `--port 8088` / `--port 8089` |
| Copilot 生成的 persona 与 SKILL 矛盾 | "diff 给我两段,reconcile 后输出最终版本" |
| 模型一直说"不知道工具",不调 `@ai_function` | 检查 `@ai_function(description=...)` 中文描述够不够具体,模型按描述选工具 |

→ [Lab 3 · 部署到 Foundry Hosted Agent](lab-3-deploy.md)
