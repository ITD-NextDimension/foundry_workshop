# 配额与 RBAC 准备(T-7 ~ T-2 天)

## 1. 配额申请

每位学员 / 每个独立 RG 需要的最小配额:

| 模型 / SKU | 区域 | 容量 |
|-----------|------|------|
| `gpt-4o-mini` GlobalStandard | northcentralus | 10K TPM |

> 30 位学员 = 300K TPM。如果订阅默认 < 300K,提前在 Foundry 门户 → Management center → Quotas 提交申请,Microsoft 团队批准通常 1-3 个工作日。
> 应急区域:`westus3`(已验证有 hosted agent 支持,但模型可用性略有差异)。

## 2. SP 创建脚本

用一个**讲师管理 SP**(Owner-级别),从它批量创建 N 个学员 SP:

```powershell
# scripts/create-student-sps.ps1(讲师私有)
param(
    [int]$Count = 30,
    [string]$SubId,
    [string]$RgPrefix = "rg-workshop-",
    [string]$Location = "northcentralus"
)

az login   # 用讲师管理身份

# 1. 创建 RG(每位学员一个)
for ($i = 1; $i -le $Count; $i++) {
    $rg = ($RgPrefix + $i.ToString("00"))
    az group create --name $rg --location $Location --subscription $SubId | Out-Null
    Write-Host "✅ RG created: $rg" -ForegroundColor Green
}

# 2. 创建 SP + 分角色
$envelopes = @()
for ($i = 1; $i -le $Count; $i++) {
    $rg = ($RgPrefix + $i.ToString("00"))
    $spName = "sp-workshop-$($i.ToString('00'))"
    $sp = az ad sp create-for-rbac --name $spName --years 1 --query "{appId:appId, password:password, tenant:tenant}" -o json | ConvertFrom-Json

    $scope = "/subscriptions/$SubId/resourceGroups/$rg"

    foreach ($role in @("Contributor", "User Access Administrator", "Cognitive Services Contributor")) {
        az role assignment create --assignee $sp.appId --role $role --scope $scope | Out-Null
    }

    $envelopes += [PSCustomObject]@{
        Student = $i
        RG      = $rg
        AppId   = $sp.appId
        Secret  = $sp.password
        Tenant  = $sp.tenant
        SubId   = $SubId
    }
    Write-Host "✅ SP & roles for student $i ($rg)" -ForegroundColor Green
}

$envelopes | Export-Csv -Path student-envelope.csv -NoTypeInformation -Encoding UTF8
Write-Host "🔒 student-envelope.csv generated — keep this file SECURE." -ForegroundColor Yellow
```

## 3. 最小 RBAC 角色矩阵(每位学员的 SP 需要的)

| 角色 | 作用域 | 必需 | 说明 |
|------|--------|------|------|
| **Contributor** | RG | ✅ | 创建 Foundry / ACR / App Insights / SWA / Log Analytics |
| **User Access Administrator** | RG | ✅ | 给新建 MI 分 `AcrPull` / `Cognitive Services OpenAI User` 等 |
| **Cognitive Services Contributor** | RG | 推荐 | 部分订阅策略下,模型 `accounts/deployments` 创建需要 |

> **不要**用 `Owner`,通常被组织策略禁用。

## 4. 撤销脚本(T-day 结束 24h 内)

```powershell
# scripts/revoke-student-sps.ps1
Import-Csv student-envelope.csv | ForEach-Object {
    az ad sp credential reset --id $_.AppId --years 0 --display-name revoked | Out-Null
    Write-Host "🔒 Revoked secret for $($_.AppId)"
}
```

可选:更狠的做法 `az ad sp delete --id <appId>` 直接删 SP(注意会带走分给该 SP 的角色)。

## 5. RG 清理

学员被告知 7 天后 RG 会清理。讲师在 T+7 跑:

```powershell
Import-Csv student-envelope.csv | ForEach-Object {
    az group delete --name $_.RG --yes --no-wait
    Write-Host "🗑️  $($_.RG) delete queued"
}
```

## 6. 检查点

- [ ] 配额回执邮件已收到,数字 ≥ 30 × 10K = 300K TPM
- [ ] 30 个 RG 已创建,`az group list -o table` 检查
- [ ] 30 个 SP 已创建并分角色,`student-envelope.csv` 生成
- [ ] 抽 2-3 个 SP 手工跑 `azd auth login` 自检,确保凭据可用
