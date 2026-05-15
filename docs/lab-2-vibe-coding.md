# Lab 2 · GitHub Copilot + MAF vibe coding 业务 agent（55 min）

> Lab 1 部署的是 Foundry 给的 placeholder。本 Lab 用 `maf-agent` chatmode 在 track-A 工作目录里**本地**写一个真正的业务 agent（默认：市场/竞品研究助手），Lab 3 再把它推回 Lab 1 的 hosted slot。

## 2.1 目标

- 熟悉 **Soul（Persona） · Skills · Tools** 三件套约定
- 用 Copilot 的 `/persona`、`/skill`、`/tool` 斜杠命令快速生成骨架
- `agentdev run` 本地跑通 → POST 返回业务 JSON
- 可选：把默认场景换成你自己的业务

## 2.2 默认场景：市场/竞品研究助手

讲师默认场景，Lab 2 直接用。看 [`../track-A/personas/research-agent.md`](../track-A/personas/research-agent.md) 与 [`../track-A/skills/market-research/SKILL.md`](../track-A/skills/market-research/SKILL.md)。

它的能力：

```
输入：一个产品 / 品类 / 公司
   │
   ▼
[ResearchAgent]
   ├─ 拆解 3-7 个子问题（不调任何工具）
   ├─ web_search   多关键词、多源
   ├─ web_fetch    抓正文 + 去 HTML
   ├─ report_builder  校验引用 + 输出结构化 JSON
   ▼
输出：带可点击脚注的 markdown 报告 + sources 数组 + confidence 评级
```

## 2.3 三件套 mini-milestones

### M1 · Persona / Soul（10 min）

切到 `maf-agent` chatmode。两条路：

**A. 默认场景** —— 已经写好，不用改。可以直接 lint：

```powershell
python ..\workshop-scripts\lint-persona.py personas\research-agent.md
# ✅ persona research-agent OK · extends=[shared/guardrails.md] · version=1.0.0
```

**B. 自带业务** —— 用斜杠命令：

```
/persona agentName=invoice-explainer role="发票解读助手" boundaries="不查实时汇率；不给税务建议；必须从用户提供的发票文本里抽事实" tools="ocr_extract, classify_charges, currency_normalize" contract="{lineItems, totalsByCategory, suspiciousFlags}"
```

Copilot 会按 `.github/instructions/maf-personas.instructions.md` 的约定生成 `personas/invoice-explainer.md`。

### M2 · Skill（10 min）

```
/skill skillName=invoice-explain purpose="一步步解读上传的发票"
triggers="用户上传图片或文本发票；用户问'每笔花在哪'"
tools="ocr_extract, classify_charges, currency_normalize"
relatedSkills="citation-format"
```

或者直接读 `skills/market-research/SKILL.md` 找灵感。

### M3 · Client-side Tools（15 min）

```
/tool toolName=ocr_extract purpose="从图片或 PDF 抽文本"
inputs="image_url: HttpUrl, lang: str='auto'"
outputs="text: str, blocks: list[dict], pages: int"
liveBackend="Azure Computer Vision Read API (env: AZURE_VISION_KEY/AZURE_VISION_ENDPOINT)"
envKey="AZURE_VISION_KEY"
```

`maf-tools.instructions.md` 会强制 pydantic + OTel + mock fallback。

### M4 · 组装 + 本地跑通（15 min）

默认场景：`src/research_agent/main.py` 已写好。

自带业务：

```python
# src/my_agent/main.py
from agent_framework import Agent, SkillsProvider
from src.shared.client_factory import build_chat_client
from src.shared.persona import load_persona
from src.shared.skill_runner import run_local_skill_script
from pathlib import Path
import sys, os

_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from tools.ocr_extract import ocr_extract
# ... 其它你新写的 tools

skills_provider = SkillsProvider.from_paths(
    skill_paths=[_REPO / "skills"],
    script_runner=run_local_skill_script,
)

agent = Agent(
    name=os.environ.get("AGENT_NAME", "invoice-explainer"),
    client=build_chat_client(),
    instructions=load_persona("invoice-explainer.md"),
    context_providers=[skills_provider],
    tools=[ocr_extract, classify_charges, currency_normalize],
    default_options={"store": False},
)
```

启动：

```powershell
# 装依赖（只需一次）
pip install -r requirements.txt

# 加载 .env（讲师下发的凭据已经填进去）
Get-Content .env | Where-Object { $_ -match '^\w' } | ForEach-Object {
  $k, $v = $_ -split '=', 2; [Environment]::SetEnvironmentVariable($k, $v, 'Process')
}

# 启动（默认 8087）
agentdev run src\research_agent\main.py --port 8087
```

第二个终端：

```powershell
$body = @{ input = "帮我研究'消费级 AI 笔记应用'品类，2025 重点对比 5 家" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

应返回符合 `research-agent.md` 输出契约的 JSON（含 `report` + `sources` + `confidence`）。

### M5 · Agent Inspector + 用 Copilot 反思 trace（5 min）

```powershell
agentdev inspect
```

浏览器自动开。发一条**违反 guardrail 的 prompt**：

```
"X 公司值不值得投资？买入还是卖出？"
```

预期：persona 拒答（参考 `personas/shared/guardrails.md` 的"不做投资建议"规则）。Inspector 看到 chat span，返回 `{refused: true, ...}`。

选中 Inspector 里 `execute_tool: web_search` 那行，截图给 Copilot Chat：

```
explain this span tree and why no web_fetch followed the search
```

## 2.4 Copilot 使用心法

| 任务 | 最佳方式 |
|------|---------|
| 生成新 persona | `/persona` 斜杠（自动按 instructions 约束 frontmatter） |
| 生成新 SKILL.md | `/skill` 斜杠 |
| 生成新 @ai_function | `/tool` 斜杠（pydantic + OTel + mock 已模板化） |
| 解释 trace span | 截图 → Copilot Chat → `explain this span tree` |
| 重构加超时/日志 | 选中代码 → Ctrl+I → `add 30s timeout and OTel span` |

详见 [`cheatsheet-copilot.md`](cheatsheet-copilot.md)。

## 2.5 出口检查点

✅ 三件套齐全：`personas/<agent>.md` + `skills/<skill>/SKILL.md` + `tools/<tool>.py`
✅ `lint-persona.py` 通过
✅ `agentdev run` 启动无错，本地 POST 返回业务 JSON
✅ Agent Inspector 看到 invoke_agent → execute_tool* → chat 序列

## 2.6 故障速查

| 现象 | 处理 |
|------|------|
| `FoundryChatClient` 401 | `az account get-access-token --resource https://ai.azure.com` 不行就 `azd auth login` 重登 |
| `agentdev run` 端口冲突 | `--port 8088` / `--port 8089` |
| Copilot 没按 instructions 走（例如生成 dict 而不是 pydantic） | 在 Chat 开头加上 `Use #file:.github/instructions/maf-tools.instructions.md` |
| 模型一直说"不知道工具"，不调 `@ai_function` | 检查 `@ai_function(description=...)` 中文描述够不够具体 |
| Skill 文件没被加载 | 检查 `SkillsProvider.from_paths(skill_paths=[...])` 路径；SKILL.md 必须在子目录中 |

→ [Lab 3 · 把本地 agent 推到 hosted](lab-3-update-hosted-agent.md)

