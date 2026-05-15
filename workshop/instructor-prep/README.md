# 讲师准备物索引

> 不给学员看;只给主讲师 + 助教看。Workshop 开场前 ≥ 1 周走完。

## 必做物

| 文件 | 何时用 | 检查点 |
|------|--------|--------|
| [`quota-rbac.md`](./quota-rbac.md) | T-7 ~ T-2 天 | 申请配额、SP RBAC 分配、回执 |
| [`student-envelope.md`](./student-envelope.md) | T-1 天 | 每位学员一份信封,内含凭据 + 链接 + USB |
| [`dry-run.md`](./dry-run.md) | T-2 天 | 讲师 1 人完整跑一遍 lab,记真实耗时 |
| [`onsite-checklist.md`](./onsite-checklist.md) | T-day | 当日现场清单:网络 / 屏幕 / 备用账号 |

## 风险预案

| 风险 | 预案 |
|------|------|
| 公司代理拦 `azd extension install` | 信封 USB 里有 `azure.ai.agents` 离线 nupkg |
| 学员 SP secret 过期 / 拼写错误 | 助教备 5 个"应急 SP",当场分配 |
| Foundry 区域 quota 不够 | 切到 `westus3`(讲师事前测过) |
| GitHub Copilot 拒接 | 助教备用 Copilot 账号 5 个,登入学员 VS Code |
| SWA 发布失败 | 离线 HTML 兜底(`observability/offline/index.html`) |
| 学员代码炸了 | `git checkout lab-N-ready` 接管 |
| 项目 LLM 配额耗尽 | 改 `AI_PROJECT_DEPLOYMENTS` capacity 5 → 10;若仍不够,讲师推荐每组共享 endpoint |

## 当日时间表(给主讲心里有数)

```
T-0:00  开场
T-0:10  Lab 0 启动
T-0:30  Lab 1 启动
T-1:00  buffer ☕
T-1:05  Lab 2 启动(最长的,55 min)
T-2:00  Lab 3 启动
T-2:25  Lab 4 启动
T-2:50  Wrap-up
T-3:00  下课
```

每个 Lab 的"出口检查点"详见对应 `workshop/docs/lab-N-*.md`。

## 评估反馈

- 反馈表用 Microsoft Forms / Google Forms
- 重点收集:Track A vs B 占比、最卡壳的 milestone、对 SWA 的反馈、对 Copilot 提示语模板的反馈
