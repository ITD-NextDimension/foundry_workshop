# GitHub Copilot + Microsoft Foundry Hosted Agent · 3h Hands-on Workshop

> 跟着 4 个 Lab,3 小时内从零搭一个**可部署、可观测**的 Foundry hosted agent,全程用 **GitHub Copilot** vibe coding。
> 学员不创建任何 Azure 资源;共享 Foundry account / project / 模型 / ACR 由讲师在配套仓库中预部署。
> 每位学员只把自己的 hosted agent(名字带 `STUDENT_SUFFIX`)推到这个共享 project,配额一锅端。

## 🧰 开课前讲师会给你

| 字段 | 来源 | 例 |
|------|------|----|
| `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | 讲师 | 36 位 GUID |
| 学员 SP:`AZURE_CLIENT_ID` + `AZURE_CLIENT_SECRET` | 讲师 | 36 位 GUID + 字符串 |
| `AZURE_AI_PROJECT_ENDPOINT` | 讲师 | `https://<account>.services.ai.azure.com/api/projects/<project>` |
| `AZURE_AI_MODEL_DEPLOYMENT_NAME` | 讲师 | `gpt-5-mini`(或讲师选的) |
| `AZURE_CONTAINER_REGISTRY_NAME` / `_ENDPOINT` | 讲师 | `cr<token>` / `cr<token>.azurecr.io` |
| `STUDENT_SUFFIX` | 讲师 | `stu07` |
| GitHub Copilot 订阅 / 试用激活 | 讲师 | trial code 或公司 SSO |

> 如果讲师还没给你这些,先去讲师那领取再开始。环境与凭据的准备脚本在另一个仓库(讲师专用),本仓库不包含。

## 🎯 学完你能做到

1. 用 `azd deploy` 把一个 Foundry hosted agent 部署到共享 project(占位 → 自己业务两阶段)
2. 用 GitHub Copilot(VS Code Chat 或 Copilot CLI 二选一)+ 仓库自带的 skill 套件写出 **Soul + Skills + Tools** 三件套,本地 `agentdev run` 跑通
3. 把本地业务 agent 增量推回 hosted slot,hosted endpoint 200 OK
4. **不登 Azure Portal**:本地 HTML + Foundry agents 数据平面 API 看 trace / 失败聚类 / conversation 时间线

## 🛠️ Copilot 双环境兼容

仓库已经为两种 Copilot 都做好准备,Lab 文档里 "VS Code 走法 / Copilot CLI 走法" 二选一即可。

| 环境 | 配置 | 入口 |
|------|------|------|
| VS Code Copilot Chat | Lab 0 跑 `install-maf-copilot-skills.ps1` 启用 `track-A/.github/{chatmodes,instructions,prompts}/` | `Ctrl+Alt+I` 选 `maf-agent` chatmode + 斜杠命令 `/persona` `/skill` `/tool` `/deploy` |
| GitHub Copilot CLI | `gh extension install github/gh-copilot` | `gh copilot suggest "<prompt>"` / `gh copilot explain "<command>"` |

两种环境都能用仓库根 `.agents/skills/` 下的 4 个微软官方 skill 作为知识库:

- `microsoft-foundry` — Foundry hosted agent 部署 / 评估 / observability / RBAC / 配额
- `agent-framework-azure-ai-py` — Agent Framework Python SDK
- `azure-ai-projects-py` — Azure AI Projects Python SDK(高层 Foundry SDK)
- `skill-creator` — 创建 / 修订自定义 skill

VS Code Copilot 会按关键词**自动激活**对应 skill;Copilot CLI 学员把 SKILL.md 内容拼到 prompt 即可。详见 [`docs/cheatsheet-copilot.md`](docs/cheatsheet-copilot.md)。

## 🗺️ 时长结构(180 min)

| # | 段落 | 时长 | 出口产物 |
|---|------|------|---------|
| 0 | [开场 · 架构总览](docs/00-intro.md) | 10 min | 选默认场景 / 自带业务 |
| 1 | [Lab 0 · 环境补齐 + 凭据登录 + Copilot skills](docs/lab-0-setup.md) | 20 min | `azd auth login --check-status` 退出 0;Copilot(VS Code 或 CLI)可用 |
| 2 | [Lab 1 · 部署你的第一个 hosted agent](docs/lab-1-deploy-hosted-agent.md) | 30 min | hosted endpoint 200 OK,拿到预览 URL |
| 3 | ☕ Buffer | 5 min | — |
| 4 | [Lab 2 · GitHub Copilot vibe coding 业务 agent](docs/lab-2-vibe-coding.md) | 55 min | 本地 agent 返回业务 JSON |
| 5 | [Lab 3 · 把本地 agent 推到 hosted](docs/lab-3-update-hosted-agent.md) | 25 min | hosted endpoint 返回业务 JSON |
| 6 | [Lab 4 · 本地 HTML 看 Foundry tracing](docs/lab-4-observability.md) | 25 min | 本地 HTML 看到自己的 conversation 时间线 |
| 7 | [Wrap-up](docs/99-wrap-up.md) | 10 min | 下一步资料 |

## 🛤️ 选路径

| 路径 | 适合 | 入口 |
|------|------|------|
| **A · 默认调研场景** | 想先把流程跑通,业务用工作坊自带的"市场/竞品研究助手"(web search + fetch + report builder) | [`track-A/`](./track-A) |
| **B · 自带业务** | 用 `/persona` `/skill` `/tool` 斜杠命令(或对应 CLI prompt 模板)让 Copilot 复制 Track A 骨架,换上你自己的领域 | [`track-A/`](./track-A) + Copilot |

## 🆘 卡住了怎么办

- 每个 Lab 都有出口检查脚本:`workshop-scripts/sanity-check.ps1` 全 ✅ 才继续
- 助教巡场,白板上贴 `#help-lab-N` 即可
- 极端兜底:`observability/local/data/traces.sample.json` 是讲师 demo,HTML 默认就显示它

## 📁 仓库地图

```
foundry_workshop/                            # 仓库根
├── README.md                                # 本文件
├── skills-lock.json                         # npx skills 安装锁(.agents/skills 来源记录)
│
├── docs/                                    # ★ 学员主要看的
│   ├── 00-intro.md                          # 开场 + 选轨
│   ├── lab-0-setup.md  …  lab-4-…           # 4 个 Lab(0 / 1 / 2 / 3 / 4)
│   ├── 99-wrap-up.md
│   └── cheatsheet-{copilot,foundry-api,powershell}.md
│
├── .agents/                                 # 微软官方 skill(VS Code Copilot 自动加载;CLI 手动拼接)
│   └── skills/
│       ├── microsoft-foundry/               # Foundry agent 部署 / 评估 / observability / RBAC / 配额
│       │   ├── SKILL.md
│       │   └── {foundry-agent, models, project, quota, rbac, resource, references}/
│       ├── agent-framework-azure-ai-py/     # Agent Framework Python SDK
│       │   ├── SKILL.md
│       │   └── references/
│       ├── azure-ai-projects-py/            # Azure AI Projects Python SDK(高层 Foundry SDK)
│       │   ├── SKILL.md
│       │   ├── references/
│       │   └── scripts/
│       └── skill-creator/                   # 创建 / 修订自定义 skill
│           ├── SKILL.md
│           ├── references/
│           └── scripts/
│
├── track-A/                                 # ★ 默认场景:市场/竞品研究助手
│   ├── README.md
│   ├── azure.yaml                           # 只声明 research-agent(无 infra 块)
│   ├── .env.example                         # 从讲师下发的凭据填写
│   ├── pyproject.toml / requirements.txt
│   ├── .foundry/                            # agent 评估元数据占位
│   ├── .github/                             # 工作坊私有 Copilot customization(VS Code 专用)
│   │   ├── chatmodes/maf-agent.chatmode.md
│   │   ├── instructions/maf-{tools,personas,skills}.instructions.md
│   │   └── prompts/{persona,skill,tool,deploy}.prompt.md      # ← 斜杠命令
│   ├── personas/                            # Soul
│   │   ├── research-agent.md
│   │   └── shared/guardrails.md
│   ├── skills/                              # SKILL.md(工作坊业务流程,与 .agents/skills 区分)
│   │   ├── market-research/SKILL.md
│   │   └── citation-format/SKILL.md
│   ├── tools/                               # @tool (Python)
│   │   ├── web_search.py / web_fetch.py / report_builder.py
│   │   └── _shared/auth.py                  # DefaultAzureCredential 工厂
│   ├── src/
│   │   ├── research_agent/                  # main.py + agent.yaml + agent.manifest.yaml + Dockerfile
│   │   └── shared/                          # persona_loader / client_factory / skill_runner
│   └── tests/unit/                          # tool 单测
│
├── workshop-scripts/                        # 学员工具脚本
│   ├── install-maf-copilot-skills.ps1       # Lab 0:启用 VS Code Copilot customization
│   ├── sanity-check.ps1                     # Lab 1/3:azd env / hosted agent / ACR 推送权限自检
│   ├── invoke-hosted.ps1                    # Lab 1/3/4:命令行调 hosted agent /responses 端点 (单次)
│   ├── chat-hosted.ps1                      # Lab 1/3:启动浏览器图形化多轮聊天 (不需要 Azure Portal)
│   ├── chat-hosted/index.html               #   ↑ 单文件 chat UI (深色, 调 /responses, 多轮上下文)
│   └── lint-persona.py                      # Lab 2:校验 persona frontmatter / include 引用
│
├── observability/
│   └── local/                               # 单文件 HTML + fetch-traces.ps1
│       ├── index.html / README.md
│       ├── fetch-traces.ps1                 # Foundry agents 数据平面 API 拉 trace
│       └── data/traces.sample.json          # 讲师 demo 兜底(HTML 默认显示)
│
└── backup/                                  # 设计文档存档(可选阅读)
    ├── azd-foundry-research.md
    ├── agent-harness-architecture.md
    └── agent-observability-evaluation.md
```

两套 skill 体系的分工:

- `.agents/skills/` —— **微软官方 skill**,知识库性质(几十 KB SKILL.md + 子目录参考)。VS Code Copilot 按描述里的关键词自动激活;Copilot CLI 学员需要手动 `cat` 到 prompt。这是 `npx skills add microsoft/skills …` 装上的标准 skill,跨项目复用。
- `track-A/.github/` —— **工作坊私有 Copilot customization**,只在 `track-A/` 打开时生效。`prompts/` 提供斜杠命令(`/persona` `/skill` `/tool` `/deploy`);`instructions/` 按文件类型自动注入约束;`chatmodes/` 提供 `maf-agent` 全局上下文。CLI 学员把对应 `*.prompt.md` 当模板用。
- `track-A/skills/` —— **工作坊业务流程**(市场调研、引用格式)的 SKILL.md,由 `SkillsProvider.from_paths()` 在 `agent` 运行时加载,与 Copilot 无关,是 agent 自己的"skill"。

> 共享 Foundry 的预部署、学员凭据分发等讲师专用工具不在本仓库;它们在另一个仓库由讲师维护。

## 📋 速查卡

- [PowerShell 转义速查](docs/cheatsheet-powershell.md)
- [GitHub Copilot Chat / CLI 提示语速查](docs/cheatsheet-copilot.md)
- [Foundry agents 数据平面 API 速查](docs/cheatsheet-foundry-api.md)

## ⚠️ 共享 Foundry 的约定

- 所有 hosted agent **共用一个 model deployment**(讲师指定,默认 `gpt-5-mini`)。配额是大家共享的 ≈ 50K TPM,请不要做 stress test。
- 每位学员 hosted agent 后缀 `STUDENT_SUFFIX`(讲师分配,如 `stu07`)。**只动自己后缀的资源**:不删别人 agent、不改 shared ACR 配置。
- 共享 ACR 学员只有 `AcrPush` 角色;hosted agent 拉镜像走 project MI 的 `AcrPull`,不影响别人。
- 观测:不需要 Azure Portal / App Insights / SWA;本地 HTML + Foundry tracing API 即可。
