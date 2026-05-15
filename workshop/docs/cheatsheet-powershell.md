# 速查卡 · PowerShell 转义与常用命令

## 字符串引用规则

| 场景 | 写法 | 说明 |
|------|------|------|
| 普通字符串 | `"hello"` 或 `'hello'` | 单引号 = 字面;双引号 = 插值 |
| 含 `$` `!` 等特殊字符的 secret | **必用双引号** `"P@ss!w0rd$xyz"` | 单引号下 `$` 不会被解析,但 azd CLI 仍按字面字符串接收 |
| secret 含双引号 | `"abc`"def"` | 用 backtick `` ` `` 转义 |
| 单引号字符串里含单引号 | `'it''s'` | 重复单引号转义 |
| 多行字符串 | `@" ... "@`(here-string) | 含 `$` 会被插值;改 `@' ... '@` 不插值 |

## azd / az 服务主体登录

```powershell
$AppId    = "<appId>"
$Secret   = "<secret>"
$TenantId = "<tid>"
$SubId    = "<subId>"

# azd
azd auth login --client-id $AppId --client-secret $Secret --tenant-id $TenantId
azd auth login --check-status

# az
az login --service-principal --username $AppId --password $Secret --tenant $TenantId
az account set --subscription $SubId
az account show
```

## 常用 azd 命令

```powershell
azd env get-values                    # 看所有环境变量
azd env get-value AZURE_AI_PROJECT_ENDPOINT
azd env set <KEY> <VALUE>             # 写环境变量
azd env refresh                       # 拉远端 RG 状态到本地
azd up --no-prompt                    # 全量 provision + deploy
azd provision                         # 只跑 bicep
azd deploy <service>                  # 单独发布某 service
azd down --purge --force --no-prompt  # 彻底删 RG(谨慎)
```

## 常用 az 命令

```powershell
az group list -o table
az deployment group list -g rg-dev -o table
az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
az cognitiveservices account list-models -n <foundry> -g <rg> -o table
```

## 调 hosted agent

```powershell
$ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT
$TOKEN    = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv

$body = @{ input = "Hello, who are you?" } | ConvertTo-Json
Invoke-RestMethod -Method POST `
  -Uri "$ENDPOINT/agents/<AgentName>/responses" `
  -Headers @{ Authorization = "Bearer $TOKEN" } `
  -ContentType "application/json" `
  -Body $body
```

## 调 SWA API(Lab 4 用)

```powershell
$SWA = azd env get-value SWA_URL
Invoke-RestMethod "$SWA/api/traces?agentName=billing-agent&minutes=60"
Invoke-RestMethod "$SWA/api/eval-scores?responseId=caresp_xxx"
```

## 跨 shell 的环境变量

```powershell
# 当前 PowerShell 会话
$env:KEY = "value"

# 持久(用户级)
[Environment]::SetEnvironmentVariable("KEY", "value", "User")

# 从 azd 注入
$env:AZURE_AI_PROJECT_ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT
```

## 文件 / 目录

```powershell
# Get-ChildItem(等同 ls / dir)
Get-ChildItem -Recurse -Filter "*.py" -Path .\track-A\

# Test-Path
if (Test-Path .\track-A\.azure\dev\.env) { Write-Host "yes" }

# 读写 JSON
$env_data = Get-Content .azure\dev\.env -Raw
$obj = "{}" | ConvertFrom-Json
$obj | ConvertTo-Json | Set-Content out.json
```

## 常见坑

| 现象 | 原因 | 处理 |
|------|------|------|
| `az login -p $Secret` 返回 `Get Token request returned http error: 401` | secret 被 shell 转义 | 双引号包裹;或写 `"$Secret"` |
| `azd env set FOO '{"a":1}'` 设进去变成空 | 单引号 + JSON 嵌套引号 | 改用 here-string 或用 `--no-prompt` + stdin |
| `Invoke-RestMethod` 报 SSL | 自签证书 | `-SkipCertificateCheck`(PS 7+) |
| `pwsh` 与 `powershell` 行为不同 | PS 5 vs PS 7 | 本 workshop 推荐 `pwsh`(PowerShell 7) |
