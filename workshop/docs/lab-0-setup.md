# Lab 0 · 环境补齐 + azd 服务主体登录(20 min)

## 0.1 学习目标

- 把"已预装"的工具链对齐到统一最低版本
- 在 `azd` 与 `az` 上都完成服务主体登录
- 验证 GitHub Copilot 在 VS Code 中工作

## 0.2 工具版本基线

打开 PowerShell 跑一次自检:

```powershell
azd version              # ≥ 1.21.3
az version               # ≥ 2.55
python --version         # ≥ 3.11
docker version           # 可选(本 workshop 默认走 ACR remote build)
gh --version             # 任意
code --version           # 任意
```

任意一项不达标 → 举手喊 `#help-lab-0`,助教带装。

## 0.3 服务主体双登录

你的"信封"里有:`appId` / `clientSecret` / `tenantId` / `subscriptionId`。

```powershell
# 占位符替换成信封里的值
$AppId    = "<appId>"
$Secret   = "<secret>"
$TenantId = "<tid>"
$SubId    = "<subId>"

# 1. azd 登录
azd auth login --client-id $AppId --client-secret $Secret --tenant-id $TenantId

# 2. az 登录(azd 内部 hook 还会调 az)
az login --service-principal --username $AppId --password $Secret --tenant $TenantId | Out-Null
az account set --subscription $SubId

# 3. azd 默认订阅与区域
azd config set defaults.subscription $SubId
azd config set defaults.location northcentralus
```

> ⚠️ **PowerShell 转义**:secret 里有 `$`、`!`、空格等字符时,**用双引号包裹**;含双引号本身则用反引号 `` ` `` 转义。详见 [`cheatsheet-powershell.md`](cheatsheet-powershell.md)。

## 0.4 装 azd ai agent 扩展

```powershell
azd extension install azure.ai.agents
azd extension list
```

## 0.5 Clone workshop 仓库

```powershell
git clone https://github.com/<org>/foundry-copilot-workshop.git
cd foundry-copilot-workshop
git checkout lab-0-ready          # 把你拉到 Lab 0 的起点

# 进入你选的 Track 子目录
cd track-A                        # 或 cd ../track-B-templates/<your-template>
```

## 0.6 验证 Copilot

1. VS Code 打开当前文件夹
2. 状态栏右下角 GitHub Copilot 图标 → 常亮代表已登录
3. `Ctrl+Alt+I` 打开 Copilot Chat,输入:`give me a one-line summary of this repo`,看是否有响应

## 0.7 出口检查点

✅ `azd auth login --check-status` 退出码 0
✅ `az account show --query name -o tsv` 输出当前订阅名
✅ VS Code Copilot 图标常亮 + Chat 有响应

```powershell
# 一行自检
azd auth login --check-status; if ($?) { Write-Host "✅ azd OK" } else { Write-Host "❌ azd NOT logged in" }
```

## 0.8 故障速查

| 现象 | 处理 |
|------|------|
| `azd auth login` 报 `AADSTS7000215: Invalid client secret` | secret 失效或被特殊字符吃掉,改用 `--client-certificate` 或回到信封确认 |
| `az login` OK 但 `azd auth login` 失败 | azd 与 az **独立登录态**,两边都要登 |
| `azd extension install` 网络超时 | 切手机热点 / 用助教的本地 `--source <path>` 离线包 |
| Copilot 图标灰色 | `Ctrl+Shift+P` → `GitHub Copilot: Sign in` 重登 |

→ [Lab 1 · azd 创建 Foundry 资源](lab-1-create-resources.md)
