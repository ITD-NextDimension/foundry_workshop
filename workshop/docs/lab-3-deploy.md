# Lab 3 · 部署 agent harness 到 Foundry Hosted Agent(25 min)

## 3.1 学习目标

- 写 `agent.yaml`(部署元数据)+ `agent.manifest.yaml`(运行时配置)
- 用 `azd ai agent init` 注册 agent 进 `azure.yaml`(覆盖 Lab 1 的占位)
- `azd deploy <agent>` 增量发布(不需要全量 `azd up`)
- 用 hosted endpoint 真实验证

## 3.2 两个 yaml 文件的分工

| 文件 | 回答什么问题 | 谁读 |
|------|------------|------|
| `agent.yaml` | "Foundry 怎么部署我?" kind / host / 语言 / 资源限制 | `azd ai agent init` / Foundry control plane(部署时) |
| `agent.manifest.yaml` | "我运行时要什么模型 + server-side tools?" | Foundry control plane(运行时) |

## 3.3 让 Copilot 生成两个 yaml

```text
@workspace 参考 #file:src/billing_agent/main.py,
生成 src/billing_agent/agent.yaml 与 src/billing_agent/agent.manifest.yaml。

agent.yaml 要求:
- kind: HostedAgent
- host: azure.ai.agent
- language: docker
- docker: { remoteBuild: true }
- resources: cpu 1, memory 2Gi
- scale: minReplicas 1, maxReplicas 3
- env: AZURE_AI_PROJECT_ENDPOINT, FOUNDRY_MODEL_DEPLOYMENT_NAME, APPLICATIONINSIGHTS_CONNECTION_STRING

agent.manifest.yaml 要求:
- name: billing-agent
- instructions: 从 personas/billing-agent.md 读取(部署时注入)
- model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}
- tools: 暂时只开 code_interpreter,其它注释掉
```

## 3.4 注册进 azd

```powershell
azd ai agent init -m src/billing_agent/agent.yaml
```

执行后查看 `azure.yaml`,应该多出一段:

```yaml
services:
  billing-agent:
    project: src/billing_agent
    host: azure.ai.agent
    language: docker
    docker:
      remoteBuild: true
    config:
      container:
        resources: { cpu: "1", memory: 2Gi }
        scale:    { maxReplicas: 3, minReplicas: 1 }
      deployments:
        - name: gpt-4o-mini
          ...
```

## 3.5 部署

```powershell
azd deploy billing-agent
```

10 分钟内完成。等待时讲师讲解:

- **Dockerfile** 必须 `linux/amd64`(workshop 的 `src/<agent>/Dockerfile` 已用 `--platform=linux/amd64` 显式声明)
- **server-side tool 声明**:`agent.manifest.yaml.tools[].type = file_search / code_interpreter / mcp / ...`
- **环境变量自动注入**:`${AZURE_AI_PROJECT_ENDPOINT}` 由 azd env 在部署时替换

## 3.6 验证 hosted endpoint

```powershell
..\workshop-scripts\invoke-hosted.ps1 -AgentName billing-agent -Prompt "我是 Acme 企业版客户,上月用量 10%,能退多少?"
```

应看到 hosted 版本的响应(应与 Lab 2 本地版本一致,但 trace 会进 Application Insights → Lab 4)。

## 3.7 查看 agent 状态

```powershell
..\workshop-scripts\invoke-hosted.ps1 -StatusOnly -AgentName billing-agent
# 应输出:status=Running, version=1, replicas=1
```

## 3.8 出口检查点

✅ `azure.yaml` 含 `services.billing-agent`(或你的 agent 名)
✅ `azd deploy` 完成,无错
✅ `invoke-hosted.ps1` 返回业务 JSON
✅ status=Running

## 3.9 故障速查

| 现象 | 处理 |
|------|------|
| `azd deploy` ACR push 卡住 | 等;后续 layer 会复用 |
| hosted 调用 401 | `az account get-access-token --resource https://ai.azure.com` 重拿;脚本会自动重试一次 |
| 模型说找不到 instructions | `agent.manifest.yaml` 里 `instructions` 字段需要明确路径或文字,部署时被注入 |
| 旧版本占位 agent 还在 | 不影响;Lab 1 的 `BasicAgent` 是独立 agent name,本 Lab 起的是 `billing-agent` |

## 3.10 加分挑战(若提前完成)

1. 在 `agent.manifest.yaml` 里打开 `file_search`,挂一个 vector store(workshop 仓库的 `infra/` 已经准备好 placeholder)
2. 改 `scale.minReplicas: 0`,体验冷启动延迟(p95 跳到 5s+),再改回 1
3. 用 `agent_update` MCP 工具手动升级 instructions,看 Foundry 是否自动起新版本(`version: 2`)

→ [Lab 4 · 开箱即用观测](lab-4-observability.md)
