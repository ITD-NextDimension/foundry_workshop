# Lab 1 · 用 Copilot + azd 部署你的第一个 GPT-5 云端 agent（30 min）

> 参考 Foundry 官方 quickstart：
> https://learn.microsoft.com/en-us/azure/foundry/agents/quickstarts/quickstart-hosted-agent?pivots=azd
>
> 不同之处：**学员不再 provision 任何 Foundry/模型/ACR** —— 这些已由讲师在另一仓库中预部署好。
> 学员只把 quickstart 的 placeholder agent 包装成"自己的 hosted agent"，部署到共享 project。

## 1.1 目标

- 理解 `azd ai agent init -m <manifest>` 注入一个 Foundry-提供的 placeholder agent 的工作方式
- 用一条 `azd deploy` 把它部署到讲师指定的共享 project，名字带 `STUDENT_SUFFIX` 区分
- 拿到自己 agent 的 **预览 URL** 并跑通一次 invoke

## 1.2 进入 track-A 并把讲师凭据灌进 azd env

```powershell
cd workshop\track-A
azd init -e dev --no-prompt        # 不会创建任何资源；只是建本地 azd env

# 讲师下发的字段（也可直接 sourcing .env）
azd env set AZURE_SUBSCRIPTION_ID         <subId>
azd env set AZURE_LOCATION                eastus2

# 共享 Foundry 资源（讲师提供，所有人相同）
azd env set AZURE_AI_PROJECT_ENDPOINT     "<讲师给的 project endpoint>"
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME <讲师给的模型 deployment 名，如 gpt-5-mini>

# 学员后缀 + agent 名（讲师分配）
azd env set STUDENT_SUFFIX                stuNN
azd env set AGENT_NAME                    research-agent-stuNN

# 共享 ACR（讲师提供，所有人相同）
azd env set AZURE_CONTAINER_REGISTRY_NAME     <讲师给的 ACR 名>
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT <讲师给的 ACR 登录端点>
```

> 💡 不要执行 `azd up`：本工作坊**没有任何 infra bicep** 给学员，`azd up` 一定失败。我们只用 `azd deploy <agent>`。

## 1.3 用 Copilot 看一下 azure.yaml

打开 `azure.yaml`，问 Copilot Chat（`maf-agent` chatmode）：

```
@workspace 解释 #file:azure.yaml 的 services.research-agent 字段；
为什么没有 deployments 数组 / 为什么没有 infra 块。
```

期望 Copilot 回答：

- `deployments: []` 表示不让 azd 创建模型 deployment —— 共享 deployment 是讲师建好的。
- 没有 `infra:` 是因为学员 SP 没有 RG provision 权限；只能调 `azd deploy`。

## 1.4 注入 Foundry quickstart placeholder agent

```powershell
# 用 Foundry 官方 sample 的 manifest 作为基础（agent.manifest.yaml）。
# 注意：必须用 agent.manifest.yaml（AgentManifest schema），不是 agent.yaml。
azd ai agent init -m https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml
```

执行后 `azure.yaml` 的 `services` 会被 azd ai agent ext 修改 / 追加；
src/ 下会多出一个 `agent-framework-agent-basic-responses/` 目录。

### ⚠️ 已知坑：sample manifest 默认 `gpt-4.1-mini` 不存在

Sample 的 `agent.manifest.yaml` 里 `model:` 写死了 `gpt-4.1-mini`。我们的共享 project 没部署这个模型。先 patch：

```powershell
$mf = "src\agent-framework-agent-basic-responses\agent.manifest.yaml"
(Get-Content $mf -Raw) -replace 'gpt-4\.1-mini', '${AZURE_AI_MODEL_DEPLOYMENT_NAME}' | Set-Content $mf -NoNewline
```

或者用 `/deploy` 斜杠让 Copilot 帮你重写：

```
/deploy agentDir=agent-framework-agent-basic-responses agentDeployName=research-agent-${STUDENT_SUFFIX}
```

### 让 placeholder 用学员后缀命名

在 quickstart agent 的 yaml 里，把 `name:` 改成 `research-agent-<STUDENT_SUFFIX>`（azd env 会替换变量）。
最简单的办法：删掉它，直接用 `track-A/src/research_agent` 作为 Lab 3 部署目标。
不过本 Lab 主要目的就是先跑一次 placeholder——保留改名即可。

## 1.5 部署

```powershell
azd deploy
```

`azd deploy` 会：

1. 通过 ACR remote build 打镜像（标签自动带学员后缀）→ push 到共享 `cr<token>.azurecr.io`。
2. 调 Foundry control plane 在共享 project 上 create/update **你这个** hosted agent。
3. 把 hosted endpoint 与 responses URL 写回 azd env：
   - `AGENT_<UPPER_SNAKE_NAME>_ENDPOINT`
   - `AGENT_<UPPER_SNAKE_NAME>_RESPONSES_ENDPOINT`

等待期间讲师讲解 6 个 azd hook 阶段（pre-package / package / publish ACR / agent publish / post hook）。

## 1.6 拿预览 URL 跑一次

```powershell
azd env get-value AGENT_RESEARCH_AGENT_${env:STUDENT_SUFFIX}_RESPONSES_ENDPOINT
# 或用脚本一把
..\workshop-scripts\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"
```

返回 JSON 含 `output_text` 即 OK。

## 1.7 自检

```powershell
..\workshop-scripts\sanity-check.ps1
```

应输出：

```
✅ AZURE_AI_PROJECT_ENDPOINT 已设置
✅ AZURE_AI_MODEL_DEPLOYMENT_NAME 已设置
✅ STUDENT_SUFFIX 已设置
✅ AZURE_CONTAINER_REGISTRY_NAME 已设置
✅ az 已登录
✅ ai.azure.com access token
✅ 模型 deployment 'gpt-5-mini' 在共享 project 中
✅ Hosted agent 'research-agent-stuNN' 可达
✅ ACR 'cr...' 可推送
```

## 1.8 出口检查点

✅ `azd deploy` 完成
✅ `invoke-hosted.ps1` 返回 200
✅ `sanity-check.ps1` 全 ✅

## 1.9 故障速查

| 现象 | 处理 |
|------|------|
| `azd deploy` ACR push 卡住 | 等；第一次推 base image 慢，后续 layer 会复用 |
| `image platform does not match host platform` | 确认 `docker.remoteBuild: true`；本地不要本地构建 |
| 调 hosted agent 报 `PermissionDenied … AIServices/agents/read` | 学员 SP 没在共享 project 上拿到 `Azure AI User` —— 联系讲师 |
| Hosted agent 名冲突（已存在） | 别人占了你的后缀；确认讲师分配的 `STUDENT_SUFFIX` 是不是和你 SP 实际匹配 |
| `azd ai agent init` 报 "Loading the model catalog" 卡死 | sample 引用了未部署的模型；按 1.4 节 patch |
| `azd up` 报 `AuthorizationFailed` | 你跑成 `azd up` 了——本工作坊只用 `azd deploy`。 |

## 1.10 等待期"动脑"任务

`azd deploy` 等的时候，提前读：

- `track-A/personas/research-agent.md` —— Lab 2 你会改它
- `track-A/skills/market-research/SKILL.md` —— Lab 2 的流程主线

→ [Lab 2 · vibe coding 业务 agent](lab-2-vibe-coding.md)
