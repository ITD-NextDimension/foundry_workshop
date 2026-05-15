# Lab 1 · azd 一键创建 Foundry / Model / Hosted Agent(30 min)

## 1.1 学习目标

- 理解 `azd-ai-starter-basic` 模板的目录产物与 `azure.yaml` 字段
- 用 `azd ai agent init` 注入一个占位 agent
- 一次 `azd up` 把 Foundry + ACR + 模型 + 容器 + agent + App Insights + SWA(workshop 自带)全部上线
- 拿到 4 个关键输出变量

## 1.2 一次性命令(15 min)

```powershell
# 进入你的 Track 目录(假设 Track A)
cd workshop/track-A

# 1. 拉模板(此目录已包含 azure.yaml / infra,跳过 azd init;若你想干净从头,见 1.5)
azd init -e dev --no-prompt

# 2. 声明 hosted agents + 模型 + workshop 观测 SWA
azd env set ENABLE_HOSTED_AGENTS true
azd env set ENABLE_MONITORING true
azd env set AI_PROJECT_DEPLOYMENTS '[{"name":"gpt-4o-mini","model":{"format":"OpenAI","name":"gpt-4o-mini","version":"2024-07-18"},"sku":{"name":"GlobalStandard","capacity":10}}]'

# 3. 注入一个 Foundry 官方占位 agent(Lab 3 会替换成你写的业务 agent)
azd ai agent init -m https://github.com/microsoft-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.yaml

# 4. 把 workshop 观测 SWA 模块 patch 进 starter 的 bicep(一次性,幂等)
..\workshop-scripts\install-swa-patch.ps1

# 5. 一键开火 🚀
azd up --no-prompt
```

`azd up` 跑 5~10 分钟,期间讲师在前面**讲解 6 个 hook 阶段**:

| 阶段 | 干了什么 |
|------|---------|
| pre-provision | 聚合 `services.*.config.deployments` + `AI_PROJECT_DEPLOYMENTS` → 翻成 bicep 参数 |
| provision | bicep 创建 RG / Foundry account / project / ACR / MI / 模型 / App Insights / SWA |
| package | ACR Tasks 远程构建容器镜像(`docker.remoteBuild: true`,本地不用 Docker) |
| publish (ACR push) | 推镜像到 ACR |
| agent publish | 调 Foundry control plane 创建 Agent Application |
| post hook | 输出 Playground 链接(本 workshop 我们用 SWA 代替) |

## 1.3 看一眼你创建了什么

```powershell
azd env get-values
```

关注这些输出:

```
AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>
AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-4o-mini
AZURE_CONTAINER_REGISTRY_NAME=acr...
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...
SWA_URL=https://<gen>.azurestaticapps.net          # ← Lab 4 用
```

> 把这一份输出**截图**保存,Lab 3 和 Lab 4 都会用。

## 1.4 健康检查(5 min)

跑 workshop 提供的 sanity check:

```powershell
..\workshop-scripts\sanity-check.ps1
```

应该看到:

```
✅ azd env values present
✅ AI_PROJECT_ENDPOINT reachable
✅ Hosted agent 'BasicAgent' status = Running
✅ APPLICATIONINSIGHTS reachable
✅ SWA endpoint reachable
```

如果有 ❌,把整段输出贴到助教 Slack 频道。

## 1.5 故障速查

| 现象 | 根因 | 处理 |
|------|------|------|
| `Authorization failed ... 'Microsoft.Authorization/roleAssignments/write'` | SP 缺 **User Access Administrator** | 喊助教加角色后 `azd up` 重跑 |
| `RegionNotSupportedForHostedAgents` | 选了非预览支持区域 | `azd config set defaults.location northcentralus` |
| `image platform does not match host platform` | 本地构建未加 `--platform linux/amd64` | 确认 `azure.yaml` 里 `docker.remoteBuild: true` |
| `azd up` 卡在 package 很久 | 第一次推 base image | 等待;后续构建 layer 缓存 |
| 跑成功但看不到 agent | 看错了 Foundry account | `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 才是当前部署 |

## 1.6 等待期的"动脑"任务

在 `azd up` 跑的时候,打开两个 markdown 浏览:

- `track-A/personas/shared/guardrails.md` — Lab 2 你会改它
- `track-A/skills/refund-quote/SKILL.md` — Lab 2 你会改它

读 2 分钟,带着问题进 Lab 2。

## 1.7 出口检查点

✅ `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 输出 https URL
✅ `..\workshop-scripts\sanity-check.ps1` 全 ✅
✅ Foundry 占位 agent(`BasicAgent`)可被调用

→ [Lab 2 · vibe coding agent harness](lab-2-vibe-coding.md)
