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

# 2. 绑定你被分配到的资源组(共享订阅,务必绑定;不绑会让 azd 试图新建 RG 而你的 SP 没权限)
azd env set AZURE_SUBSCRIPTION_ID <你的 subId>
azd env set AZURE_RESOURCE_GROUP   <你的 rg,如 rg-workshop-a-student-001>
azd env set AZURE_LOCATION         eastus2     # 或 northcentralus / westus3

# 3. 声明 hosted agents + 模型 + workshop 观测 SWA
azd env set ENABLE_HOSTED_AGENTS true
azd env set ENABLE_MONITORING true
azd env set AI_PROJECT_DEPLOYMENTS '[{"name":"gpt-5-mini","model":{"format":"OpenAI","name":"gpt-5-mini","version":"2025-08-07"},"sku":{"name":"GlobalStandard","capacity":10}}]'

# 4. 注入一个 Foundry 官方占位 agent(Lab 3 会替换成你写的业务 agent)
#    注意:必须用 agent.manifest.yaml(AgentManifest schema),不是 agent.yaml。
azd ai agent init -m https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml

# 5. 跑 preflight:生成本人唯一命名 salt + 清理上一轮 soft-deleted 资源
#    (共享订阅必跑;Lab 1.4 详细解释了它防什么坑)
..\workshop-scripts\preflight.ps1

# 6. 把 workshop 观测 SWA 模块 patch 进 starter 的 bicep(一次性,幂等)
..\workshop-scripts\install-swa-patch.ps1

# 7. 一键开火 🚀
azd up --no-prompt
```

> **占位 sample 可能引用 `gpt-4.1-mini` 等未部署的模型。** `azd ai agent init` 会在
> "Loading the model catalog" 一步卡住。打开 `src/<agent>/agent.manifest.yaml`,把
> `model:` 字段改成 `${AZURE_AI_MODEL_DEPLOYMENT_NAME}`(或 `gpt-5-mini`)再继续。

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
AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-5-mini
AZURE_CONTAINER_REGISTRY_NAME=acr...
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...
SWA_URL=https://<gen>.azurestaticapps.net          # ← Lab 4 用
WORKSHOP_NAME_SUFFIX=<4 字符 salt>                  # ← preflight 生成,只影响 SWA 名
```

> 把这一份输出**截图**保存,Lab 3 和 Lab 4 都会用。

## 1.4 共享订阅下的资源命名冲突

30 位学员共用一个订阅会撞到这些坑,**preflight.ps1 把它们一并解决**:

| 现象 | 根因 | preflight 怎么处理 |
|------|------|--------------------|
| `azd up` 报 *"A resource with this name already exists or is in a conflicting state"* | 上一轮 `azd down --purge` 没真正 purge 掉,Foundry account 进了 60 天 soft-delete | 跑 `az cognitiveservices account list-deleted` 扫一遍,匹配的全部 `purge` |
| SWA 名 `swa-workshop-xxx.azurestaticapps.net` 已被全局占用 | SWA 在 `*.azurestaticapps.net` 全局命名空间;同一学员重试会撞自己上一轮 | 第一次跑写一个 4 字符 salt 到 `azd env WORKSHOP_NAME_SUFFIX`,SWA 名改成 `swa-workshop-<token>-<salt>` |
| Foundry account `ai-account-xxx` 与同事冲突 | 不会冲突 —— starter 用 `uniqueString(subId, rgId, location)`,每人 RG 不同 token 就不同 | **前提是每人有独立 RG**(讲师准备物里已分配,见 instructor-prep/quota-rbac.md) |

如果你已经撞了 SWA 名冲突,跑 `..\workshop-scripts\preflight.ps1 -Force` 重新摇 salt。

## 1.5 健康检查(5 min)

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

## 1.6 故障速查

| 现象 | 根因 | 处理 |
|------|------|------|
| `Authorization failed ... 'Microsoft.Authorization/roleAssignments/write'` | SP 缺 **User Access Administrator** | 喊助教加角色后 `azd up` 重跑 |
| `RegionNotSupportedForHostedAgents` | 选了非预览支持区域 | `azd env set AZURE_LOCATION eastus2`(或 northcentralus) |
| `image platform does not match host platform` | 本地构建未加 `--platform linux/amd64` | 确认 `azure.yaml` 里 `docker.remoteBuild: true` |
| `azd up` 卡在 package 很久 | 第一次推 base image | 等待;后续构建 layer 缓存 |
| 跑成功但看不到 agent | 看错了 Foundry account | `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 才是当前部署 |
| 调 hosted agent 报 `PermissionDenied … AIServices/agents/read` | 调用者 SP / agent 的 MI 缺 **Azure AI User**(=Foundry User) | 给两者都加该角色到 Foundry account 作用域;详见 lab-3 §3.6 |
| `SkuCode 'Free' is invalid` 出现在 SWA | 老版本 swa.bicep 给 Free SWA 加了 SystemAssigned MI(不兼容) | 用本仓库当前版本的 `infra/swa.bicep`(已移除 MI);跑 `..\workshop-scripts\install-swa-patch.ps1` 重 patch |
| `azd down --force --purge` 把你的 RG 也删了 | starter 的 bicep 把 RG 当作自己的 | T-day 结束后由讲师统一清;若你提前需要重建,联系讲师重发 RG |

## 1.7 等待期的"动脑"任务

在 `azd up` 跑的时候,打开两个 markdown 浏览:

- `track-A/personas/shared/guardrails.md` — Lab 2 你会改它
- `track-A/skills/refund-quote/SKILL.md` — Lab 2 你会改它

读 2 分钟,带着问题进 Lab 2。

## 1.8 出口检查点

✅ `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 输出 https URL
✅ `..\workshop-scripts\sanity-check.ps1` 全 ✅
✅ Foundry 占位 agent(`BasicAgent`)可被调用

→ [Lab 2 · vibe coding agent harness](lab-2-vibe-coding.md)
