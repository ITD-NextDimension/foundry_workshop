# 使用 azd 服务主体登录创建 Foundry / Model / Hosted Agent 调研

> 场景:在 CI/CD 或自动化环境中,通过 Azure Developer CLI(`azd`)以服务主体(Service Principal)非交互登录,然后端到端完成 **Microsoft Foundry 资源 → 模型部署 → Hosted Agent 发布**。
>
> 本调研聚焦官方推荐的一体化路径:`Azure-Samples/azd-ai-starter-basic` 模板 + `azd ai agent` 扩展 + `azd up`。所有命令均为示例,**未在 Azure 上实际执行**。

---

## 0. TL;DR — 一图流命令清单

```bash
# 0. 一次性准备
azd extension install azure.ai.agents
az login --service-principal -u <appId> -p "<secret>" --tenant <tid>
az account set --subscription <subId>

# 1. azd 服务主体登录
azd auth login --client-id <appId> --client-secret "<secret>" --tenant-id <tid>
azd config set defaults.subscription <subId>
azd config set defaults.location northcentralus

# 2. 创建项目目录 + 拉取 Foundry starter 模板
mkdir my-foundry-app && cd my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt

# 3. (可选) 仅声明 Foundry 基础设施
azd env set ENABLE_HOSTED_AGENTS true

# 4. 注入一个 Hosted Agent 定义(自动会写入模型部署 + ENABLE_HOSTED_AGENTS)
azd ai agent init -m https://github.com/microsoft-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.yaml

# 5. 一键 provision + 模型部署 + 容器构建推送 + 发布 Agent
azd up --no-prompt

# 6. 查看部署产物
azd env get-values
```

完整说明见后文各节。

---

## 1. 背景与目标

- **服务主体登录**是 CI/CD 与自动化场景下 `azd` 的标准认证方式;用户给出的命令格式与官方一致:
  ```bash
  azd auth login --client-id <appId> --client-secret "<secret>" --tenant-id <tid>
  ```
- 目标:在该认证态下,**不交互**地完成:
  1. Microsoft Foundry 账号 + 项目的资源创建
  2. 一个或多个模型部署(例如 `gpt-4o-mini`)
  3. 一个 Hosted Agent(容器镜像 → ACR → Foundry Agent Application)
- 范围外:`az cognitiveservices account create` 等更细粒度的非 azd 路径;Foundry MCP `agent_update` 直接调用。

---

## 2. 前置条件

### 2.1 工具版本

| 工具 | 最低版本 | 安装命令(Windows / Linux / macOS) |
|------|----------|-----------------------------------|
| Azure Developer CLI(`azd`) | **1.21.3+**(`azd ai agent` 扩展要求) | `winget install microsoft.azd` / `curl -fsSL https://aka.ms/install-azd.sh \| bash` / `brew tap azure/azd && brew install azd` |
| Azure CLI(`az`) | 2.55+ | 参考 https://aka.ms/installazurecli |
| `azd ai agent` 扩展 | latest | `azd extension install azure.ai.agents`(`azd ai agent init` 首次运行也会自动安装) |
| Docker(可选) | 任意 | 仅在 `docker.remoteBuild: false` 时需要;推荐启用云构建以省略本地 Docker |

### 2.2 服务主体 RBAC(最小角色矩阵)

`azd up` 在 starter 上会创建多个资源 **并给新建的 managed identity 分配 RBAC 角色**,所以服务主体本身必须拥有给别人分角色的权限。最小集合:

| 角色 | 作用域 | 必需 | 说明 |
|------|--------|------|------|
| **Contributor** | 订阅 或 目标 RG | ✅ | 创建 Foundry account / project / ACR / App Insights / Log Analytics 等所有数据面外资源 |
| **User Access Administrator**(或 `Role Based Access Control Administrator`) | 订阅 或 目标 RG | ✅ | 给 Foundry 项目的 managed identity 分配 `AcrPull` / `Cognitive Services OpenAI User` 等角色;否则 bicep 会在 role assignment 步骤红着脸退出 |
| **Cognitive Services Contributor** | RG | 推荐 | 部分订阅策略限制下,模型 `accounts/deployments` 创建需要此角色 |
| **Azure AI Account Owner**(可选) | RG | 可选 | 给到 SP 后可直接管理 Foundry account 内的项目/Agent |

> **重要**:`Owner` 角色虽然能 cover 全部需求,但通常被组织策略禁用。优先使用 `Contributor + User Access Administrator` 两件套。

### 2.3 区域与配额

- **Hosted Agents 预览**强制 `northcentralus`(以 [Region support](https://learn.microsoft.com/en-us/azure/ai-foundry/reference/region-support) 与 [Agent model region support](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/model-region-support?tabs=global-standard) 为准)。
- 模型部署受配额限制,部署前确认目标模型(如 `gpt-4o-mini`)在目标区域有 TPM 余量(可用 Foundry 门户 → Management center → Quotas 查看)。

---

## 3. 第一步:服务主体登录

### 3.1 `azd auth login` 命令解析

官方支持的服务主体登录(参考 [azd auth login reference](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-auth-login)):

```bash
azd auth login \
  --client-id <appId> \
  --client-secret "<secret>" \
  --tenant-id <tid>
```

可替换的凭据形式(三选一):

| 参数 | 适用场景 |
|------|----------|
| `--client-secret "<secret>"` | 共享 secret;最常见,适合机器人账户 |
| `--client-certificate <path-to-pfx>` | 证书凭据;更安全,适合长期 SP |
| `--federated-credential-provider github\|azure-pipelines\|oidc` | OIDC 联合身份;GitHub Actions / Azure Pipelines / 通用 OIDC 都支持 |

> **PowerShell 提示**:secret 中含 `$`、`!`、空格 等特殊字符时务必用**双引号**包裹(用户给出的命令已正确加上引号)。

### 3.2 同步登录 `az`(为什么需要)

`azd` 和 `az` 维护**两套独立**的登录态。`azd-ai-starter-basic` 中的部分 pre/post-provision hook 与 `azd ai agent` 扩展内部都会调用 `az`,因此服务主体场景下建议两边都登录:

```bash
az login --service-principal \
  --username <appId> \
  --password "<secret>" \
  --tenant <tid>

az account set --subscription <subId>
```

### 3.3 设置默认订阅/区域

```bash
# 让 azd 后续命令默认走这个订阅与区域,避免每次提示
azd config set defaults.subscription <subId>
azd config set defaults.location northcentralus
```

这两个值会写入用户级 `~/.azd/config.json`。在多订阅 SP 上也可以改用 `azd env set AZURE_SUBSCRIPTION_ID <subId>` 写到环境级。

### 3.4 登录态校验

```bash
# azd
azd auth login --check-status      # 退出码 0 即已登录
azd auth status                     # 输出账号信息

# az
az account show --query "{Name:name, SubscriptionId:id, Tenant:tenantId}" -o table
```

---

## 4. 第二步:创建 Foundry(`azd-ai-starter-basic`)

> 这一步**不会立刻在 Azure 上创建任何资源**,只是把 IaC + 配置拉到本地。真正的 provision 在第 6 节 `azd up` 时执行。

### 4.1 拉取模板

```bash
mkdir my-foundry-app
cd my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt
```

- `-t Azure-Samples/azd-ai-starter-basic` — Microsoft Foundry 官方 azd bicep starter。
- `-e dev` — azd 环境名(也用作 RG 命名 `rg-dev`)。
- `--no-prompt` — 非交互模式,使用默认值;CI/CD 必须加。
- 必须在**空目录**执行。

执行后目录结构:

```
my-foundry-app/
├── .azure/dev/.env       # azd 环境变量(可用 azd env set 修改)
├── infra/                # bicep 文件(main.bicep + modules)
├── src/                  # Agent 代码(初始为空)
└── azure.yaml            # 项目配置入口
```

### 4.2 `azure.yaml` 结构说明

starter 的 `azure.yaml` 形如:

```yaml
requiredVersions:
  extensions:
    azure.ai.agents: latest
services: {}      # 第 6 节会被 azd ai agent init 填充
infra:
  provider: bicep
  path: ./infra
  module: main
```

关键点:
- `requiredVersions.extensions.azure.ai.agents` — 声明项目依赖 `azd ai agent` 扩展。
- `services` — 每个 hosted agent 一个条目(由 `azd ai agent init` 自动生成,见 §6.2)。
- `infra` — bicep 入口模块。模板的 bicep 会读取后述环境变量来决定要不要建 ACR、要不要建模型部署。

### 4.3 关键环境变量

starter 通过 `.azure/<env>/.env` 中的环境变量驱动 bicep 行为。可以用 `azd env set <KEY> <VALUE>` 写入:

| 变量 | 类型 | 默认 | 作用 |
|------|------|------|------|
| `ENABLE_HOSTED_AGENTS` | bool | `false` | 设为 `true` 时,bicep 额外创建 **Azure Container Registry** 与 **capability host(`capabilityHosts/agents`)**,这是 hosted agent 的必要前提 |
| `ENABLE_MONITORING` | bool | `true` | 创建 Application Insights + Log Analytics |
| `AI_PROJECT_DEPLOYMENTS` | JSON 数组 | `[]` | 要在 Foundry account 上创建的模型部署列表,见 §5.1 |
| `AI_PROJECT_CONNECTIONS` | JSON 数组 | `[]` | 要在 Foundry project 上创建的连接(Search / Bing / Storage 等) |
| `AI_PROJECT_DEPENDENT_RESOURCES` | JSON 数组 | `[]` | 同时创建的依赖资源,如 Azure AI Search、Bing Grounding |

> **小贴士**:这些变量在 `azd ai agent init` 时通常会被扩展**自动填充**;手工管理只在没有 agent 定义、单独跑 Foundry 时需要。

### 4.4 仅 provision Foundry(不部署 Agent)的写法

如果暂时不想部署任何 agent,只想把 Foundry 资源建出来:

```bash
azd env set ENABLE_HOSTED_AGENTS false   # 先不要 ACR/capability host(可选)
azd env set AI_PROJECT_DEPLOYMENTS '[{"name":"gpt-4o-mini","model":{"format":"OpenAI","name":"gpt-4o-mini","version":"2024-07-18"},"sku":{"name":"GlobalStandard","capacity":10}}]'

azd provision --no-prompt
```

`azd provision` 只跑 bicep,**不**做镜像构建/agent 发布;此时会得到一个有模型部署的空 Foundry 项目。

执行完后:

```bash
azd env get-values
# 关键输出:
#   AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>
#   AZURE_RESOURCE_GROUP=rg-dev
#   AZURE_CONTAINER_REGISTRY_NAME=...(若启用 hosted agents)
```

---

## 5. 第三步:创建 Model

模型部署是 Foundry account 上的 `Microsoft.CognitiveServices/accounts/deployments` 子资源,starter 的 bicep 会根据 `AI_PROJECT_DEPLOYMENTS` 数组自动 loop 创建。两种声明方式:

### 5.1 手工设置 `AI_PROJECT_DEPLOYMENTS`

```bash
azd env set AI_PROJECT_DEPLOYMENTS '[
  {
    "name": "gpt-4o-mini",
    "model": { "format": "OpenAI", "name": "gpt-4o-mini", "version": "2024-07-18" },
    "sku":   { "name": "GlobalStandard", "capacity": 10 }
  },
  {
    "name": "text-embedding-3-small",
    "model": { "format": "OpenAI", "name": "text-embedding-3-small", "version": "1" },
    "sku":   { "name": "Standard", "capacity": 30 }
  }
]'
```

字段语义:

| 字段 | 含义 |
|------|------|
| `name` | 部署名(后续 agent 引用这个名字,不是模型本身的 name) |
| `model.format` | 通常是 `OpenAI`;Anthropic / Meta / Mistral 等需对应值 |
| `model.name` / `model.version` | 模型家族名与版本号,可在 Foundry 模型目录或 `az cognitiveservices account list-models` 查 |
| `sku.name` | `Standard` / `GlobalStandard` / `ProvisionedManaged` 等 |
| `sku.capacity` | TPM 配额(千 token/分钟),受订阅配额限制 |

### 5.2 通过 `azd ai agent init` 自动注入

`azd ai agent init` 在解析 agent.yaml 时会**自动**把所需模型写到 `azure.yaml` 的 `services.<agentName>.config.deployments` 下,例如:

```yaml
services:
  CalculatorAgent:
    project: src/CalculatorAgent
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
          model:
            format: OpenAI
            name: gpt-4o-mini
            version: "2024-07-18"
          sku:
            name: GlobalStandard
            capacity: 10
```

`azd up` 的 **pre-provision hook** 会聚合 `services.*.config.deployments` 与 `AI_PROJECT_DEPLOYMENTS`,写成最终的部署列表传给 bicep。

> **推荐**:让 `azd ai agent init` 来管这一切,避免手工维护 JSON。

### 5.3 SKU / capacity / 区域可用性

- 部署前用 Azure CLI 查目标模型在当前 account 是否可达:
  ```bash
  az cognitiveservices account list-models \
    --name <foundry-account-name> \
    --resource-group <rg> \
    --query "[?name=='gpt-4o-mini'].{name:name, version:version, format:format}" -o table
  ```
- 配额查询见 [`microsoft-foundry:quota`](https://learn.microsoft.com/en-us/azure/ai-foundry/) 相关文档,或 Foundry 门户 Management center → Quotas。
- 不同区域 SKU 支持差异较大,`GlobalStandard` 一般在主要区域可用;`ProvisionedManaged` 需要预购 PTU。

---

## 6. 第四步:创建 Hosted Agent

### 6.1 安装 `azd ai agent` extension

```bash
azd extension install azure.ai.agents
# 验证
azd extension list
```

未安装时,首次 `azd ai agent init` 会提示并自动安装。

### 6.2 用 `azd ai agent init` 拉取 agent 定义

`agent.yaml` 描述了 agent 的 kind / 协议 / 环境变量 / 模型需求。可用官方示例,也可指向自己仓库里的 yaml。

```bash
# 例:Microsoft Agent Framework 的 basic responses 示例
azd ai agent init -m https://github.com/microsoft-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.yaml
```

> 也可以浏览其它示例:`agent-framework/responses/02-tools`、`03-mcp`、`05-workflows` 等,或 [`bring-your-own`](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents/bring-your-own) 目录里的自定义框架示例。

扩展会:

1. 把 agent 源代码下载到 `src/<AgentName>/`(包含 Dockerfile、agent 入口、`agent.yaml`)。
2. 在 `azure.yaml` 中新增一项 `services.<AgentName>`(见 §5.2 示例),`host: azure.ai.agent`,`language: docker`。
3. 设置 `ENABLE_HOSTED_AGENTS=true`(自动写入 `.azure/<env>/.env`)。
4. 把 agent 所需的环境变量映射进 azd env(`AZURE_AI_PROJECT_ENDPOINT`、`AZURE_AI_MODEL_DEPLOYMENT` 等)。

> 同一个 azd 环境里可以多次 `azd ai agent init`,得到多 agent 的项目。

### 6.3 `azd up` 执行流程拆解

```bash
azd up --no-prompt
```

会按顺序做这些事情:

| 阶段 | 内部动作 | 关键细节 |
|------|----------|----------|
| **pre-provision hook** | 解析 `services.*` + 环境变量,聚合 `AI_PROJECT_DEPLOYMENTS` / `AI_PROJECT_CONNECTIONS` / `AI_PROJECT_DEPENDENT_RESOURCES` / `ENABLE_HOSTED_AGENTS` | 把声明式配置翻译成 bicep 参数 |
| **provision (bicep)** | 创建 Resource Group、Foundry account、Foundry project、ACR、capability host、Managed Identity、模型部署、Role Assignments | 5–10 分钟;失败可直接重跑 |
| **package** | 对每个 `host: azure.ai.agent` 的 service 构建容器镜像 | `docker.remoteBuild: true` 时走 ACR Tasks 云构建(`az acr build`),无需本地 Docker;镜像 tag 用时间戳保证唯一 |
| **publish (ACR push)** | 推送镜像到上一步建好的 ACR | 用 capability host 的 managed identity `AcrPull` 鉴权 |
| **agent publish** | 调用 Foundry control plane,创建 Agent Application,绑定镜像 + 模型 + 环境变量 | 输出 agent name / version / endpoint |
| **post hook** | 输出 Playground 链接 | https://ai.azure.com/... |

> **重要**:必须用 `linux/amd64` 镜像;starter 的 Dockerfile 已设置好。如果自行替换 Dockerfile,记得 `--platform linux/amd64`。

### 6.4 验证 Agent

#### 方式 A:Foundry Portal

```bash
# 拿到 portal 链接
azd env get-values | grep AZURE_AI_PROJECT_ENDPOINT
```

打开 https://ai.azure.com → 选中对应项目 → **Agents** 节点 → 找到刚发布的 agent → 点 **Open in playground** 发测试消息。

#### 方式 B:Responses API 直接调用

Hosted agent 默认提供 OpenAI Responses 协议:

```bash
ENDPOINT=$(azd env get-value AZURE_AI_PROJECT_ENDPOINT)
TOKEN=$(az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv)

curl -X POST "$ENDPOINT/agents/<AgentName>/responses" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"input":"Hello, who are you?"}'
```

#### 方式 C:容器健康检查

如果只想确认容器在 Foundry 上跑起来了,Foundry MCP 工具 `agent_container_status_get` 会返回 `Running`/`Failed`(本调研未实际调用)。

---

## 7. 一体化端到端示例脚本

> 占位符:`<appId>` `<secret>` `<tid>` `<subId>` 在 CI 中通常从 Secret Store(GitHub Secrets / KeyVault / Pipelines Variable Group)读入。

### 7.1 Bash 版

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_ID="<appId>"
APP_SECRET="<secret>"
TENANT_ID="<tid>"
SUB_ID="<subId>"
ENV_NAME="dev"
LOCATION="northcentralus"
AGENT_YAML_URL="https://github.com/microsoft-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.yaml"

# 1. 双登录
az login --service-principal -u "$APP_ID" -p "$APP_SECRET" --tenant "$TENANT_ID" >/dev/null
az account set --subscription "$SUB_ID"
azd auth login --client-id "$APP_ID" --client-secret "$APP_SECRET" --tenant-id "$TENANT_ID"

# 2. 默认值
azd config set defaults.subscription "$SUB_ID"
azd config set defaults.location "$LOCATION"

# 3. 扩展
azd extension install azure.ai.agents

# 4. 初始化
mkdir -p my-foundry-app && cd my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e "$ENV_NAME" --no-prompt

# 5. 注入 agent(自动设置模型 + ENABLE_HOSTED_AGENTS=true)
azd ai agent init -m "$AGENT_YAML_URL"

# 6. 一键部署
azd up --no-prompt

# 7. 输出
azd env get-values
```

### 7.2 PowerShell 版

```powershell
$ErrorActionPreference = "Stop"

$AppId    = "<appId>"
$Secret   = "<secret>"
$TenantId = "<tid>"
$SubId    = "<subId>"
$EnvName  = "dev"
$Location = "northcentralus"
$AgentYaml = "https://github.com/microsoft-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.yaml"

# 1. 双登录
az login --service-principal -u $AppId -p $Secret --tenant $TenantId | Out-Null
az account set --subscription $SubId
azd auth login --client-id $AppId --client-secret $Secret --tenant-id $TenantId

# 2. 默认值
azd config set defaults.subscription $SubId
azd config set defaults.location $Location

# 3. 扩展
azd extension install azure.ai.agents

# 4. 初始化(必须在空目录)
New-Item -ItemType Directory -Force my-foundry-app | Out-Null
Set-Location my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e $EnvName --no-prompt

# 5. 注入 agent
azd ai agent init -m $AgentYaml

# 6. 一键部署
azd up --no-prompt

# 7. 输出
azd env get-values
```

> CI 场景下用 OIDC 联合凭据更安全,把第 1 步替换为:
> `azd auth login --client-id $AppId --federated-credential-provider github --tenant-id $TenantId`(GitHub Actions)。

---

## 8. 常见错误与排查

| 错误特征 | 根因 | 处理 |
|----------|------|------|
| `Authorization failed ... does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'` | SP 缺 **User Access Administrator** | 给 SP 在订阅/RG 上加该角色后 `azd provision` 重跑 |
| `AuthorizationFailed: ... Microsoft.CognitiveServices/accounts/write` | SP 缺 Contributor 或被策略禁止创建 Cognitive Services | 加 Contributor;若组织策略禁用 AIServices,联系订阅 owner |
| `RegionNotSupportedForHostedAgents` | 选了非预览支持区域 | `azd config set defaults.location northcentralus` 后重跑 |
| `Failed to authenticate` 或 `ChainedTokenCredential ... no credential available` | `azd` 没登录或 secret 过期 | `azd auth login --check-status` 排查;CI 中检查 secret 是否更新 |
| `docker: command not found` 或本地 Docker 不可用 | 默认 `docker.remoteBuild` 未启用 | 在 `azure.yaml` 中 `docker.remoteBuild: true`,或本机装 Docker Desktop |
| `image platform does not match host platform` | 本地 `docker build` 没加 `--platform linux/amd64` | 用云构建,或本地构建时显式加 `--platform linux/amd64` |
| `azd up` 卡在 `package` 很久 | 大体积依赖第一次推 ACR | 等待或拆 base image;后续构建会复用 layer |
| `azd ai agent init` 报扩展未注册 | 没装扩展 | `azd extension install azure.ai.agents` |
| `--client-secret` 含 `$`/`!`/`"` 等字符在 bash 下被替换 | shell 转义 | 用单引号(bash)或双引号(PowerShell);或用 `--client-certificate` 替代 |
| `azd up` 成功但 portal 看不到 agent | 用了错误的 Foundry account/project | `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 拿到的链接才是当前部署的项目 |

调试技巧:

```bash
azd up --debug 2>&1 | tee azd-up.log     # 详细 trace 含 bicep 错误
az deployment group list -g rg-dev --query "[].{Name:name, State:properties.provisioningState}" -o table
```

---

## 9. 清理:`azd down`

```bash
azd down --purge --force --no-prompt
```

- 删除当前 azd 环境对应的**整个 Resource Group**(Foundry account、所有模型部署、ACR、App Insights、Log Analytics 全部消失)。
- `--purge` 触发 Foundry account 的软删除清理,**避免** 48 小时内同名重建失败。
- CI/CD 中谨慎使用,不要误删生产 RG。

---

## 10. 参考链接

- [`azd auth login` 命令参考](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-auth-login)
- [Azure Developer CLI 安装](https://aka.ms/azure-dev/install)
- [`azd ai agent` extension 文档](https://aka.ms/azdaiagent/docs)
- [`Azure-Samples/azd-ai-starter-basic` 模板](https://github.com/Azure-Samples/azd-ai-starter-basic)
- [Foundry Hosted Agents 概念](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [Foundry Agent Runtime Components](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/runtime-components)
- [Foundry 区域支持](https://learn.microsoft.com/en-us/azure/ai-foundry/reference/region-support)
- [Foundry Agent Service 模型区域支持](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/model-region-support?tabs=global-standard)
- [Foundry Samples — Hosted Agents (Python)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [Foundry Samples — Hosted Agents (C#)](https://github.com/microsoft-foundry/foundry-samples/tree/main/samples/csharp/hosted-agents)
- [Azure Identity:服务主体最佳实践](https://learn.microsoft.com/azure/developer/intro/passwordless-overview)
