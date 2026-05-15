# 速查卡 · GitHub Copilot Chat 提示语

## 触发方式

| 入口 | 快捷键 | 适合 |
|------|--------|------|
| Copilot Chat 侧栏 | `Ctrl+Alt+I` | 跨文件提问、生成新文件 |
| Inline Chat | `Ctrl+I` | 在选中代码上做局部修改 |
| Quick Chat | `Ctrl+Shift+I` | 一次性短问 |
| `@workspace` 模式 | 在 Chat 中 `@workspace ...` | 让 Copilot 检索整个仓库 |
| `#file:` / `#selection` 引用 | 在 Chat 中 `#file:path/to.md` | 把指定文件作为上下文 |

## 黄金模板(Lab 2 用)

### 生成 Persona / Soul

```text
@workspace 参考 #file:personas/shared/guardrails.md 与 #file:personas/billing-agent.md,
生成 personas/<NEW>-agent.md。

角色: <一句话角色定义>
职责边界:
  1. <做什么>
  2. <不做什么 → 转 XxxAgent>
  3. <Free / Enterprise 等 tier 差异>
输出格式: JSON {field1, field2, field3}
口吻: 简短/专业/不带情绪

frontmatter 含 version: 1.0.0, owner: <team>@<domain>,
extends: shared/guardrails.md, shared/handoff-protocol.md
```

### 生成 Skill

```text
@workspace 在 skills/<skill-name>/ 下生成 SKILL.md + scripts/<name>.py

SKILL.md 步骤:
  1. <步骤 1>
  2. 调用 scripts/<name>.py --<flag1> <val> --<flag2> <val>
  3. <步骤 3>

frontmatter 含 name / description / triggers / scripts 字段。

scripts/<name>.py:
  - 命令行参数: <list>
  - 输出: JSON {<fields>}
  - 业务规则: <rules>
```

### 生成 Tool(@ai_function)

```text
@workspace 在 tools/<file>.py 写 @ai_function,签名:
  async def <name>(<args>) -> <ReturnType>

要求:
- pydantic BaseModel 返回类型
- description 写**中文**,模型按描述选工具
- 先用本地 dict mock,真实 HTTPX 调用留 TODO
- 加 try/except + structured logging
```

### 生成 Agent 装配代码

```text
@workspace 参考 #file:src/billing_agent/main.py,
为 <new-agent> 写 src/<new-agent>/main.py:

- 从 personas/<new-agent>.md 加载 instructions
- SkillsProvider 从 skills/ 加载
- tools: [list of @ai_function imports]
- FoundryChatClient 用 AZURE_AI_PROJECT_ENDPOINT + FOUNDRY_MODEL_DEPLOYMENT_NAME
- ResponsesHostServer 启 8087(可改)
- default_options.store = False
```

### 生成 agent.yaml / agent.manifest.yaml(Lab 3)

```text
@workspace 参考 #file:src/billing_agent/agent.yaml,
为 <new-agent> 生成两个 yaml:

agent.yaml:
- kind: HostedAgent
- host: azure.ai.agent
- language: docker
- docker.remoteBuild: true
- resources: cpu 1, memory 2Gi
- env: AZURE_AI_PROJECT_ENDPOINT, FOUNDRY_MODEL_DEPLOYMENT_NAME, APPLICATIONINSIGHTS_CONNECTION_STRING

agent.manifest.yaml:
- name: <new-agent>
- model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}
- tools: 先只开 code_interpreter,其它注释
```

## 不要做的事

| ❌ 错误用法 | ✅ 正确做法 |
|-----------|----------|
| "写一个 agent" | 给出具体场景 + 输出格式 + 业务规则 |
| 不引用现有文件 | `#file:` 引用 shared/guardrails.md、其他 persona |
| 生成完不审阅 | **diff 后审,有不一致让 Copilot reconcile** |
| 把 Copilot 当编译器 | Copilot 不知道 Foundry 最新 API → 自己对照官方 sample |
| 一次问太多 | 拆 mini-milestone,每步只让它做一件事 |

## 反查 trace 的提示语(Lab 4)

```text
This is a span tree from Agent Inspector / SWA Conversation page.
Identify:
1) the slowest span (and why)
2) any tool that failed (errorType / resultCode)
3) the conversation_id and response_id for cross-table join

<paste span list or screenshot>
```

## Inline 重构常用语

| 选中代码 → Ctrl+I,然后输入 |
|---------------------------|
| `add 30s timeout` |
| `add structured logging via opentelemetry, span name "<x>"` |
| `add pydantic validation for inputs` |
| `extract into a helper function` |
| `add docstring in Chinese, parameters & returns` |
| `add a unit test for this function` |

## Copilot 与 Copilot CLI 的区分

- VS Code 里 `Ctrl+Alt+I` = **Copilot Chat**(本 workshop 主用)
- 终端里 `gh copilot suggest "<task>"` / `gh copilot explain "<cmd>"` = **GitHub Copilot CLI**(命令辅助)
- 装:`gh extension install github/gh-copilot`
