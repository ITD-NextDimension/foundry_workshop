# Workshop Infra Add-on

> 这一层不替换 `azd-ai-starter-basic` 的 bicep,而是**追加**一个 Static Web App,让 Lab 4 的观测面板可用。

## 怎么挂上去

Lab 1 学员跑 `azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt` 时,starter 会拉一份默认的 `infra/`。本仓库的 patch 流程把:

1. 本目录的 `swa.bicep` **复制**到学员的 `./infra/swa.bicep`
2. 在学员的 `./infra/main.bicep` 末尾**追加**一个 `module workshopSwa './swa.bicep'` 引用块
3. 在 `./infra/main.parameters.json` 中加上 `workshopNameSuffix` 参数(从 azd env `WORKSHOP_NAME_SUFFIX` 读取)

整个流程由 `workshop-scripts/install-swa-patch.ps1` 一键完成,**幂等**(重跑不重复 patch)。

## Patch 后的关键片段

`./infra/main.bicep` 末尾:

```bicep
@description('Optional per-run salt to avoid global-namespace name collisions on retries.')
param workshopNameSuffix string = ''

var workshopResourceToken = uniqueString(subscription().id, resourceGroupName, location)
var workshopAppInsightsResourceId = useExistingAiProject ? existingAiProject.outputs.APPLICATIONINSIGHTS_RESOURCE_ID : aiProject.outputs.APPLICATIONINSIGHTS_RESOURCE_ID
var workshopAppInsightsName = last(split(workshopAppInsightsResourceId, '/'))

module workshopSwa './swa.bicep' = {
  scope: rg
  name: 'workshop-swa'
  params: {
    resourceToken: workshopResourceToken
    nameSuffix: workshopNameSuffix
    applicationInsightsName: workshopAppInsightsName
    tags: tags
  }
}

output SWA_URL string = workshopSwa.outputs.swaUrl
output SWA_NAME string = workshopSwa.outputs.swaName
```

## 为什么 Free SKU 不带 SystemAssigned MI

历史版本的 `swa.bicep` 给 SWA 加了:

```bicep
identity: { type: 'SystemAssigned' }
```

并配套一个 `Monitoring Reader` role assignment。**SWA Free tier 不允许托管身份**,这会导致部署失败,错误信息是误导性的 `SkuCode 'Free' is invalid.`(实际是 MI 不兼容)。

当前版本因此**移除了 MI 与 role assignment**。`offline/index.html` 不需要 App Insights 数据面访问;若你升级到完整 `swa/` (带 Functions API 的版本),改用 Standard SKU 或换用 *user-assigned* MI。

## 为什么不直接 fork starter

starter 自带更新,fork 一次就脱节;追加 module 让学员每次 workshop 都拿到最新 starter,只追加 workshop 需要的资源。

## 资源清单

| 资源 | 用途 |
|------|------|
| `Microsoft.Web/staticSites` | Lab 4 仪表板(Free tier 免费 100GB/月) |
| `staticSites/config` | 注入 APPINSIGHTS_APPLICATION_ID 给前端 |

## 共享订阅的命名冲突

`swa-workshop-${resourceToken}` 在 `*.azurestaticapps.net` 是**全局唯一**的;同一个学员重试(`azd down` → `azd up`)有概率撞到自己上一轮的残留。`workshop-scripts/preflight.ps1` 为每个学员生成一个 4 字符 `WORKSHOP_NAME_SUFFIX` salt,SWA 名变成 `swa-workshop-${resourceToken}-${nameSuffix}`,撞了之后跑 `preflight.ps1 -Force` 重摇即可。

不同学员之间不会撞,因为 `resourceToken` 包含 `resourceGroup().id`,每个学员的 RG 名不同。

## SKU / 区域注意

- SWA Free tier 限制:无自定义域(用 `<gen>.azurestaticapps.net`)、API 总执行 ≤ 100 万次/月、staging slots 限 3 个。Workshop 量级完全够。
- Free tier 仅在 `centralus / eastus2 / westus2 / westeurope / eastasia` 5 个区域开放;`swa.bicep` 默认 `westus2`。
- Free tier 不支持 Private Link / VNet,如果学员的订阅有 "禁公网" 策略,改用 `Standard` tier(需加 SKU 参数)。
