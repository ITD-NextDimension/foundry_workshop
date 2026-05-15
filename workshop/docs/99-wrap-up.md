# Wrap-up · 总结 + 下一步(10 min)

## 5.1 总结口诀

- **Soul / Skills / Tools** 是 agent harness 的 DNA(`personas/` / `skills/` / `tools/`)
- **`azd up` + `azd deploy`** 是部署的双手柄(一键创建 vs 增量发布)
- **`gen_ai.response.id`** 是 trace 与 eval 的 join key,埋点务必透传
- **GitHub Copilot** 是把概念变代码的力放大器:**Copilot 是手,你是脑**

## 5.2 你今天搭出来的东西

```
你
 ↓
[本地 agentdev 调试环境]
 ↓ azd deploy
[Foundry Hosted Agent: billing-agent v1]
 ↓ OTel 自动埋点
[Application Insights]
 ↓ KQL
[Static Web App 仪表板]   ← 你的运维入口
```

加上 workshop 自带的 **Track A 客户支持骨架**,你已经走完了从 0 到 1 的完整闭环。

## 5.3 下一步学习路径

### Phase 3 评估闭环(还没在 workshop 里跑)

把 trace 转成评估数据集 → 跑 batch eval → 比较版本 → `prompt_optimize` → redeploy:

- 参考 [`agent-observability-evaluation.md`](../../agent-observability-evaluation.md):
  - §5 Evaluators 选型
  - §6 Datasets 四类(seed / traces / curated / prod)
  - §7 Batch Evaluation
  - §9 优化循环

### 多 agent 编排

把今天的 4 个 agent 真正串起来:

- `workflow.yaml`(声明式,推荐做主路由)
- `WorkflowBuilder`(代码式,复杂控制流)
- `connected_agents`(只做极简 demo)

参考 [`agent-harness-architecture.md`](../../agent-harness-architecture.md) §7。workshop 仓库 `track-A/workflows/triage.workflow.yaml` 已经给了一个起点。

### 自建 MCP server

把内部能力 MCP 化,在 agent.manifest.yaml 里 `type: mcp` 引用:

- Azure Container Apps 模板:[`Azure-Samples/mcp-container-ts`](https://github.com/Azure-Samples/mcp-container-ts)
- Azure Functions 模板:[`Azure-Samples/mcp-sdk-functions-hosting-python`](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python)

参考 [`agent-harness-architecture.md`](../../agent-harness-architecture.md) §6。

### CI/CD 接入

`.github/workflows/agent-eval.yml`:PR 门禁跑 P0 smoke
`.github/workflows/agent-eval-scheduled.yml`:nightly trace harvest + 回归

参考 [`agent-observability-evaluation.md`](../../agent-observability-evaluation.md) §11。

## 5.4 资源清理

> 资源 RG 会保留 7 天供你继续探索。彻底删:

```powershell
azd down --purge --force --no-prompt
```

- 删整个 RG(Foundry + 模型 + ACR + App Insights + SWA 全没)
- `--purge` 触发 Foundry account 软删除清理,**避免** 48h 内同名重建失败

## 5.5 反馈

请扫码 / 点链接填反馈表(讲师现场提供 URL),3 分钟完成。
你的吐槽与建议会直接进下一期 workshop 改进列表。

## 5.6 相关链接

- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Hosted Agents](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [`azd ai agent` 扩展](https://aka.ms/azdaiagent/docs)
- [Foundry Samples (Python)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [GitHub Copilot in VS Code](https://code.visualstudio.com/docs/copilot/overview)

## 5.7 致谢

本 workshop 的素材来自三份内部调研:

- `azd-foundry-research.md`
- `agent-harness-architecture.md`
- `agent-observability-evaluation.md`

感谢调研作者们的整理工作。下一期再见 👋
