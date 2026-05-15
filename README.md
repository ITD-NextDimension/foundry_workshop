# GitHub Copilot + Microsoft Foundry Hosted Agent · 3h Hands-on Workshop

> 跟着 4 个 Lab，3 小时内从零搭一个**可部署、可观测**的 Foundry hosted agent，全程用 **GitHub Copilot** vibe coding。
> 学员不创建任何 Azure 资源；共享 Foundry account / project / 模型 / ACR 由讲师事前在另一个仓库中预部署好。
> 每位学员只把自己的 hosted agent（名字带 `STUDENT_SUFFIX`）推到这个共享 project，配额一锅端。

## 🧰 开课前讲师会给你

| 字段 | 来源 | 例 |
|------|------|----|
| `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | 讲师 | 36 位 GUID |
| 学员 SP：`AZURE_CLIENT_ID` + `AZURE_CLIENT_SECRET` | 讲师 | 36 位 GUID + 字符串 |
| `AZURE_AI_PROJECT_ENDPOINT` | 讲师 | `https://<account>.services.ai.azure.com/api/projects/<project>` |
| `AZURE_AI_MODEL_DEPLOYMENT_NAME` | 讲师 | `gpt-5-mini`（或讲师选的） |
| `AZURE_CONTAINER_REGISTRY_NAME` / `_ENDPOINT` | 讲师 | `cr<token>` / `cr<token>.azurecr.io` |
| `STUDENT_SUFFIX` | 讲师 | `stu07` |
| GitHub Copilot 订阅 / 试用激活 | 讲师 | trial code 或公司 SSO |

> 如果讲师还没给你这些，先去讲师那领取再开始。环境与凭据的准备脚本在**另一个仓库**（讲师专用），本仓库不包含。

## 🎯 学完你能做到

1. 用 `azd deploy` 把一个 Foundry hosted agent 部署到共享 project（占位 → 自己业务两阶段）
2. 用 GitHub Copilot + MAF skills（chatmodes / instructions / prompts）写出 **Soul + Skills + Tools** 三件套，本地 `agentdev run` 跑通
3. 把本地业务 agent 增量推回 hosted slot，hosted endpoint 200 OK
4. **不登 Azure Portal**：本地 HTML + Foundry agents 数据平面 API 看 trace / 失败聚类 / conversation 时间线

## 🗺️ 时长结构（180 min）

| # | 段落 | 时长 | 出口产物 |
|---|------|------|---------|
| 0 | [开场 · 架构总览](docs/00-intro.md) | 10 min | 选默认场景 / 自带业务 |
| 1 | [Lab 0 · 环境补齐 + 凭据登录 + Copilot skills](docs/lab-0-setup.md) | 20 min | `azd auth login --check-status` 退出 0；Chat 顶部出现 `maf-agent` |
| 2 | [Lab 1 · 部署你的第一个 GPT-5 云端 agent](docs/lab-1-deploy-hosted-agent.md) | 30 min | hosted endpoint 200 OK，拿到预览 URL |
| 3 | ☕ Buffer | 5 min | — |
| 4 | [Lab 2 · GitHub Copilot vibe coding 业务 agent](docs/lab-2-vibe-coding.md) | 55 min | 本地 agent 返回业务 JSON |
| 5 | [Lab 3 · 把本地 agent 推到 hosted](docs/lab-3-update-hosted-agent.md) | 25 min | hosted endpoint 返回业务 JSON |
| 6 | [Lab 4 · 本地 HTML 看 Foundry tracing](docs/lab-4-observability.md) | 25 min | 本地 HTML 看到自己的 conversation 时间线 |
| 7 | [Wrap-up](docs/99-wrap-up.md) | 10 min | 下一步资料 |

## 🛤️ 选路径

| 路径 | 适合 | 入口 |
|------|------|------|
| **A · 默认调研场景** | 想先把流程跑通，业务用 workshop 自带的"市场/竞品研究助手"（web search + fetch + report builder） | [`track-A/`](./track-A) |
| **B · 自带业务** | 用 `/persona` `/skill` `/tool` 斜杠让 Copilot 复制 Track A 骨架，换上你自己的领域 | [`track-A/`](./track-A) + Copilot |

## 🆘 卡住了怎么办

- 每个 Lab 都有出口检查脚本：`workshop-scripts/sanity-check.ps1` 全 ✅ 才继续
- 助教巡场，白板上贴 `#help-lab-N` 即可
- 极端兜底：`observability/local/data/traces.sample.json` 是讲师 demo，HTML 默认就显示它

## 📁 仓库地图

```
workshop/
├── docs/                          # ★ 学员主要看的：开场 + 5 个 Lab + 速查卡 + Wrap-up
├── track-A/                       # ★ 默认场景：市场/竞品研究助手
│   ├── personas/                  # Soul（research-agent + shared guardrails）
│   ├── skills/                    # market-research / citation-format
│   ├── tools/                     # web_search / web_fetch / report_builder
│   ├── src/research_agent/        # main.py + agent.yaml + agent.manifest.yaml + Dockerfile
│   ├── tests/unit/                # tool 单测
│   ├── .github/                   # Copilot chatmodes / instructions / prompts
│   ├── azure.yaml                 # 只声明 research-agent（无 infra 块）
│   └── README.md
├── workshop-scripts/              # sanity-check / invoke-hosted / install-maf-copilot-skills / lint-persona
└── observability/
    └── local/                     # 单文件 HTML + fetch-traces.ps1（Foundry 数据平面）
```

> 共享 Foundry 的预部署、学员凭据分发等讲师专用工具不在本仓库；它们在另一个仓库由讲师维护。

## 🔗 相关文档（workshop 知识来源）

- [`docs/azd-foundry-research.md`](docs/azd-foundry-research.md) — Phase 1：azd 创建 Foundry 资源（讲师在另一仓库中处理这部分）
- [`docs/agent-harness-architecture.md`](docs/agent-harness-architecture.md) — Phase 2：harness 四层架构
- [`docs/agent-observability-evaluation.md`](docs/agent-observability-evaluation.md) — Phase 3：可观测性 + 评估

## 📋 速查卡

- [PowerShell 转义速查](docs/cheatsheet-powershell.md)
- [GitHub Copilot Chat 提示语速查](docs/cheatsheet-copilot.md)
- [Foundry agents 数据平面 API 速查](docs/cheatsheet-foundry-api.md)

## ⚠️ 共享 Foundry 的约定

- 所有 hosted agent **共用一个 model deployment**（讲师指定，默认 `gpt-5-mini`）。配额是大家共享的 ≈ 50K TPM，请不要做 stress test。
- 每位学员 hosted agent 后缀 `STUDENT_SUFFIX`（讲师分配，如 `stu07`）。**只动自己后缀的资源**：不删别人 agent、不改 shared ACR 配置。
- 共享 ACR 学员只有 `AcrPush` 角色；hosted agent 拉镜像走 project MI 的 `AcrPull`，不影响别人。
- 观测：不需要 Azure Portal / App Insights / SWA；本地 HTML + Foundry tracing API 即可。


