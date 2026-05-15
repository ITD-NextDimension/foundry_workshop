# 学员凭据信封(模板)

> 每位学员/小组一份。讲师在 workshop 开场前 24h 内打印或电子分发。

## 信封正面信息

```
学员姓名:_____________________
小组编号:_____________________
Track 选择:[ ] A  [ ] B(开场后填)
助教:_____________________
应急联系:_____________________
```

## 信封内容清单

- [ ] **Azure 凭据卡**(下方"凭据卡"小节复印)
- [ ] **GitHub 仓库 URL 卡**:`https://github.com/<org>/foundry-copilot-workshop`(印成二维码 + URL)
- [ ] **SWA fallback URL 卡**:`https://workshop-fallback.azurestaticapps.net`(讲师事前部署的公共示例 SWA)
- [ ] **USB-C / USB-A 优盘**:
    - `offline-full/index.html`(echarts 内嵌的离线观测页)
    - `azure.ai.agents-<version>.nupkg`(`azd ai agent` 扩展离线包)
    - `agent-dev-cli-<version>.whl`(MAF agentdev 离线包)
    - `python-3.11-windows-amd64.exe`(应急装 Python)
- [ ] **速查卡 ×3**(打印自 `docs/cheatsheet-*.md`,A4 双面彩印)

## 凭据卡(模板)

> **保密**:不要拍照分享。**会场结束** 24h 内,讲师统一吊销这批 SP。

```
+------------------------------------------+
|   WORKSHOP CREDENTIALS — 保密             |
+------------------------------------------+
| 学员编号: WS-2026-05-14-<NN>             |
|                                          |
| Azure Tenant ID:                         |
|   ____________________________________   |
|                                          |
| Subscription ID:                         |
|   ____________________________________   |
|                                          |
| Service Principal AppId:                 |
|   ____________________________________   |
|                                          |
| Service Principal Secret:                |
|   ____________________________________   |
|                                          |
| RG Name(预创建):                        |
|   rg-workshop-<NN>                       |
|                                          |
| Azure Region:                            |
|   northcentralus                         |
|                                          |
| GitHub Copilot trial 激活码(若需):     |
|   ____________________________________   |
+------------------------------------------+
```

## 分发流程(讲师 SOP)

1. **T-7 ~ T-2 天**:跑 `quota-rbac.md` 流程,拿到 N 份 SP 凭据,记录到 `student-envelope.xlsx`(讲师私有)
2. **T-1 天晚上**:打印 / 装订;USB 用 `prepare-usb.ps1`(讲师工具,本目录的 `tools/` 下,可选)
3. **T-day 开场前 15 min**:按桌发放,学员检查信封齐全才入座
4. **T-day 结束后 24h**:
    - 跑 `revoke-sp.ps1`(讲师工具)吊销所有 SP secret
    - 跑 `azd down --purge --force --no-prompt` 删 RG(或留 7 天供学员自学,届时再删)

## 信封缺失补救

如果学员开场前丢了信封 → 给"备用信封"(讲师手里多备 3 套 SP)。仍然识别学员编号便于后续吊销。
