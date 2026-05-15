# Workshop Infra Add-on

> 这一层不替换 `azd-ai-starter-basic` 的 bicep,而是**追加**一个 Static Web App + 必要的 RBAC,让 Lab 4 的观测面板可用。

## 怎么挂上去

Lab 1 学员跑 `azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt` 时,starter 会拉一份默认的 `infra/`。本仓库的 `azure.yaml` 引用了**两个** bicep 入口:

1. `azd-ai-starter-basic` 默认的 `infra/main.bicep`(创建 Foundry / 模型 / ACR / App Insights / Log Analytics)
2. **本目录的 `swa.bicep` 作为 module 被 main.bicep 引用**(本仓库 README 给出 patch 指南)

## Patch 指南(讲师准备物的一部分)

在 starter 拉下来的 `infra/main.bicep` 末尾追加:

```bicep
module workshopSwa './../../infra/swa.bicep' = {
  name: 'workshop-swa'
  params: {
    resourceToken: resourceToken
    applicationInsightsName: applicationInsights.outputs.name
    tags: tags
  }
}

output SWA_URL string = workshopSwa.outputs.swaUrl
```

讲师把这段 patch 放进 `workshop-scripts/install-swa-patch.ps1` 让学员一键执行(可选,Lab 1 之前在仓库 README 里也有截图说明)。

## 为什么不直接 fork starter

starter 自带更新,fork 一次就脱节;追加 module 让学员每次 workshop 都拿到最新 starter,只追加 workshop 需要的资源。

## 资源清单

| 资源 | 用途 |
|------|------|
| `Microsoft.Web/staticSites` | Lab 4 仪表板(Free tier 免费 100GB/月) |
| `staticSites/config` | 注入 APPINSIGHTS_APPLICATION_ID 给 Functions |
| Role assignment | SWA 的系统分配 MI 拿 `Monitoring Reader` 权限读 App Insights |

## 注意

- SWA Free tier 限制:无自定义域(用 `<gen>.azurestaticapps.net`)、API 总执行 ≤ 100 万次/月、staging slots 限 3 个。Workshop 量级完全够。
- Free tier 不支持 Private Link / VNet,如果学员的订阅有 "禁公网" 策略,改用 `Standard` tier(需加 SKU 参数)。
