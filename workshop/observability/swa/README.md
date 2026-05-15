# Workshop Observability SWA

> 主路径观测前端 — React + Vite + echarts,通过 SWA Functions 调 Application Insights REST API。

## 本地开发

```powershell
# 前端
cd src
npm install
npm run dev      # http://localhost:4280

# API(另一个终端)
cd ../api
npm install
npm run start    # http://localhost:7071  (Vite 已配 /api 代理)
```

## 部署

通过 `track-A/azure.yaml` 的 `services.observability` 条目,与 hosted agents 一起 `azd up`。

```yaml
services:
  observability:
    project: ../observability/swa
    host: staticwebapp
    config:
      apiLocation: api
      outputLocation: dist
      appLocation: src
      appBuildCommand: npm run build
      apiBuildCommand: npm run build
```

部署后:

```powershell
azd env get-value SWA_URL
# https://<gen>.azurestaticapps.net
```

## 鉴权

SWA Functions 使用 Managed Identity 调 Application Insights REST API。Lab 1 创建资源时已经在 bicep 里给 SWA 的 system-assigned MI 分配了 `Monitoring Reader` 角色到对应的 App Insights 资源上。

学员**不需要**登录;SWA 默认 anonymous。 生产环境请加 SWA EasyAuth(Microsoft Entra)。
