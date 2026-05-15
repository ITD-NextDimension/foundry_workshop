# GitHub Copilot + Microsoft Foundry Hosted Agent · 3h Hands-on Workshop

> 跟着 4 个 Lab,3 小时内从零搭一个**可部署、可观测**的 Foundry hosted agent harness,全程用 **GitHub Copilot** vibe coding。

## 🎯 学完你能做到

1. 用 `azd` 一键创建 Foundry account / project / Model deployment / Hosted Agent
2. 用 GitHub Copilot 写出业务 agent 的三件套(**Soul + Skills + Tools**),本地 `agentdev run` 跑通
3. 把本地 agent harness 部署成 Foundry hosted agent
4. 不登 Azure Portal,在自建 SWA 仪表板上看 trace / 失败聚类 / 延迟趋势

## 🗺️ 时长结构(180 min)

| # | 段落 | 时长 | 出口产物 |
|---|------|------|---------|
| 0 | [开场 · 架构总览](docs/00-intro.md) | 10 min | 选定 Track A / B |
| 1 | [Lab 0 · 环境补齐 + azd 登录](docs/lab-0-setup.md) | 20 min | `azd auth login --check-status` 退出 0 |
| 2 | [Lab 1 · azd 创建 Foundry 资源](docs/lab-1-create-resources.md) | 30 min | `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 输出 https URL |
| 3 | ☕ Buffer | 5 min | — |
| 4 | [Lab 2 · GitHub Copilot vibe coding agent harness](docs/lab-2-vibe-coding.md) | 55 min | 本地 agent 返回业务 JSON |
| 5 | [Lab 3 · 部署到 Foundry Hosted Agent](docs/lab-3-deploy.md) | 25 min | hosted endpoint 200 OK |
| 6 | [Lab 4 · 开箱即用可观测性](docs/lab-4-observability.md) | 25 min | SWA 上看到自己的 trace |
| 7 | [Wrap-up](docs/99-wrap-up.md) | 10 min | 下一步资料 |

## 🛤️ 选轨

| Track | 适合 | 入口 |
|-------|------|------|
| **A · 跟随参考场景** | 想先把流程跑通,业务用 workshop 自带的"企业客户支持"案例(Triage → TechSupport / Billing / KB) | [`track-A/`](./track-A) |
| **B · 自带业务** | 想把自己的业务跑一遍;5 套备选模板兜底(IT 工单 / 法务 / 销售 / 招聘 / 知识库) | [`track-B-templates/`](./track-B-templates) |

## 🆘 卡住了怎么办

- 每个 Lab 都有一份 `lab-N-ready` 标签(git tag),`git checkout lab-N-ready` 直接接管
- 助教巡场,白板上贴 `#help-lab-N` 即可
- 极端兜底:`observability/offline/index.html` 离线 HTML 在没网时也能演示观测

## 📁 仓库地图

```
workshop/
├── docs/                          # ★ 你主要看的:开场 + 5 个 Lab + 3 张速查卡 + Wrap-up
├── track-A/                       # ★ 跟随轨:完整可跑的企业客户支持 harness
│   ├── personas/                  # Soul:角色 + guardrails(markdown)
│   ├── skills/                    # MAF SkillsProvider 加载的"任务说明书"
│   ├── tools/                     # @ai_function 客户端工具(Python)
│   ├── src/<agent>/               # 一个 agent 一个子目录(main.py + agent.yaml + Dockerfile)
│   ├── workflows/                 # 多 agent 路由(workflow.yaml)
│   ├── .foundry/                  # agent-metadata + 评估占位
│   ├── azure.yaml                 # azd 入口
│   └── infra/                     # bicep(由 azd-ai-starter-basic 衍生)
├── track-B-templates/             # 5 套备选业务的脚手架(persona + skill + tool 骨架)
├── workshop-scripts/              # sanity-check / invoke-hosted / export-traces / lint-persona
├── observability/
│   ├── swa/                       # 主路径:Static Web App(React + echarts + Functions API)
│   └── offline/                   # 备胎:单文件 HTML + 内置 echarts
└── infra/                         # 顶层 bicep:RG + Foundry + ACR + capability host + SWA
```

## 🔗 相关文档(workshop 知识来源)

- [`azd-foundry-research.md`](../azd-foundry-research.md) — Phase 1:azd SP 登录 + 创建资源
- [`agent-harness-architecture.md`](../agent-harness-architecture.md) — Phase 2:harness 四层架构
- [`agent-observability-evaluation.md`](../agent-observability-evaluation.md) — Phase 3:可观测性 + 评估

## 📋 速查卡

- [PowerShell 转义速查](docs/cheatsheet-powershell.md)
- [GitHub Copilot Chat 提示语速查](docs/cheatsheet-copilot.md)
- [KQL & SWA URL 速查](docs/cheatsheet-kql-swa.md)
