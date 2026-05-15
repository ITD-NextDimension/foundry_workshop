# Dry Run · 讲师 e2e 演练(T-2 天)

> 主讲师本人在真实订阅 / 真实 SP / 真实 Foundry 资源上**完整跑一遍** Lab 0 ~ Lab 4。目的是:
> 1. 拿到真实耗时,修正 lab 文档里的"30 min"等估计
> 2. 触发任何配置 / 网络 / 权限的 bug,提前修
> 3. 录屏作为应急素材

## 准备

```powershell
# 用一个"测试学员" SP(讲师事前自己留一份,跟学员的同源)
git clone https://github.com/<org>/foundry-copilot-workshop.git
cd foundry-copilot-workshop/workshop

# 计时器开启
$start = Get-Date
```

## 跑 Lab 0(目标 ≤ 20 min)

按 `docs/lab-0-setup.md` 走。记录:

- 双登录耗时:_____ s
- `azd extension install` 耗时:_____ s
- VS Code Copilot 登入是否首次需要重启:[ ] 是 [ ] 否

## 跑 Lab 1(目标 ≤ 30 min,大头是 `azd up`)

记录:

- `azd init` 耗时:_____ s
- `azd ai agent init` 耗时:_____ s
- `install-swa-patch.ps1` 耗时:_____ s
- `azd up` 总耗时:_____ min(讲师讲解期需要填这段空)
    - 子段:provision(bicep): _____ min
    - 子段:package(ACR Tasks 第一次构建):_____ min
    - 子段:agent publish:_____ min
- `sanity-check.ps1` 全 ✅?[ ] 是 [ ] 否(若否:故障 + 修复)

## 跑 Lab 2(目标 ≤ 55 min)

按 `docs/lab-2-vibe-coding.md` 5 个 mini-milestone 走。每个记录:

- M1 Persona:_____ min(Copilot Chat 一次成功?[ ]Y [ ]N,需重试 _____ 次)
- M2 Skill:_____ min
- M3 Tool:_____ min
- M4 装配 + agentdev run:_____ min(`agentdev run` 第一次启动慢?_____ s)
- M5 Inspector + 故意失败:_____ min

最常用的"修补提示语"出现?把它收进 `docs/cheatsheet-copilot.md`。

## 跑 Lab 3(目标 ≤ 25 min)

- `azd ai agent init -m src/billing_agent/agent.yaml`:_____ s
- `azd deploy billing-agent`:_____ min(主要是 ACR push + agent publish)
- `invoke-hosted.ps1` 首次响应是否 ≤ 5s?[ ]Y [ ]N(冷启动可能 30s+,记录最长)

## 跑 Lab 4(目标 ≤ 25 min)

- SWA `azd env get-value SWA_URL` 输出?[ ]Y [ ]N
- 浏览器打开 SWA Overview,5 min 后是否能看到数据?[ ]Y [ ]N
    - 没数据 → 检查:① App Insights 摄入延迟 ② SWA MI 是否拿到 Monitoring Reader ③ `APPINSIGHTS_APPLICATION_ID` 是否注入 SWA appsettings
- `export-traces.ps1` 导出 JSON 大小:_____ KB
- 离线 HTML 渲染:[ ]Y [ ]N

## 总耗时

```
end = Get-Date
($end - $start).TotalMinutes
```

把这个数与 180 min 比,若 > 180:

| 超 5 min | 简短开场;Lab 1 缩等待期讲解 |
| 超 15 min | 砍 Lab 2 的 M5 故意失败 |
| 超 30 min | 砍 Lab 4 的"加分挑战"段;或下移到课后 |

## 录屏

整段录屏(OBS / Camtasia),按 lab 切成 5 段:

1. `lab-0-setup.mp4`(≤ 5 min,加速)
2. `lab-1-create-resources.mp4`(≤ 6 min)
3. `lab-2-vibe-coding.mp4`(≤ 8 min,挑 1-2 个 milestone)
4. `lab-3-deploy.mp4`(≤ 5 min)
5. `lab-4-observability.mp4`(≤ 5 min)

如果当天某段炸了,直接播这一段救场。

## Dry-run 结束后

把发现的 bug 直接改 workshop 仓库;重要的"耗时纠偏"反映到 `docs/lab-N-*.md` 的时长标注。

## 检查点

- [ ] 总耗时 ≤ 180 min
- [ ] 所有 lab 出口检查点全 ✅
- [ ] 5 段录屏拍齐
- [ ] 发现的 ≥ 3 个 bug 已修(记录到 `instructor-prep/bug-log.md`,可空)
