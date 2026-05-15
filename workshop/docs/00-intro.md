# 0 · 开场:架构总览 + 选轨(10 min)

## 0.1 为什么需要 agent harness

一个能上生产的 agent 不是"写个 prompt + 接个模型"那么简单。它需要:

- **Soul**:角色边界、口吻、拒绝策略 → `personas/*.md`
- **Skills**:完成任务的步骤说明书 → `skills/<skill>/SKILL.md`
- **Tools**:调内部 API / 写状态的函数 → `tools/*.py`(`@ai_function`)
- **Runtime**:模型 + 容器 + 路由 → Microsoft Foundry Hosted Agent

`harness` 把这些按目录约定组织起来,可版本化、可评估、可观测。

## 0.2 四层架构

```
┌─────────────────────────────────────────────────────────────┐
│  L4 编排层    workflow.yaml / WorkflowBuilder              │  ← Lab 2 末尾点到
├─────────────────────────────────────────────────────────────┤
│  L3 应用层    Hosted Agent 容器 = MAF Agent                │  ← Lab 2/3 主战场
│              ├── instructions ← personas/*.md   (Soul)     │
│              ├── context_providers=[SkillsProvider]        │
│              ├── tools=[client-side @ai_function …]        │
│              └── client = FoundryChatClient                │
├─────────────────────────────────────────────────────────────┤
│  L2 模型与工具层  Foundry server-side tools                │  ← Lab 1/3 涉及
│                  + Foundry Model Deployments               │
├─────────────────────────────────────────────────────────────┤
│  L1 基础设施层    Foundry account/project + ACR + MI + RBAC│  ← Lab 1 主战场
│                  + Application Insights + Log Analytics    │  ← Lab 4 数据源
└─────────────────────────────────────────────────────────────┘
```

## 0.3 贯穿示例:企业客户支持

```
用户问题
   │
   ▼
[TriageAgent] ── 分类 ──┬─→ [TechSupportAgent]  + KB 检索 + 工单创建
                       ├─→ [BillingAgent]      + 退款额度计算 + CRM 更新
                       ├─→ [KBAgent]           + 文档检索 + 引用
                       └─→ 直接答 / 兜底
```

Track A 跟这个例;Track B 把这套骨架替换成你自己的业务。

## 0.4 选轨

| 你是谁 | 推荐 Track | 时间预期 |
|--------|-----------|---------|
| "我想先把流程走通,业务给我什么我做什么" | **A · 跟随** | 准时下课 |
| "我想试自己的业务,有点风险" | **B · 自带业务** | 可能需要助教兜底切回 |

> 现在请举手统计,助教把同 Track 的学员邻座调整。

## 0.5 GitHub Copilot 在本 workshop 的角色

| 阶段 | Copilot 任务 |
|------|------------|
| Lab 2 M1 Persona | 读 `personas/shared/guardrails.md`,生成新 agent 的 persona |
| Lab 2 M2 Skill | 写 SKILL.md + 配套 Python 脚本 |
| Lab 2 M3 Tool | 写 `@ai_function`,带类型注解 + pydantic |
| Lab 2 M4 组装 | 写 `src/<agent>/main.py` 串起来 |
| Lab 3 部署 | 写 `agent.yaml` 与 `agent.manifest.yaml` |
| Lab 4 观测 | 解释 trace span / 改 SWA 前端样式 |

口诀:**Copilot 是手,你是脑**。指令越具体、上下文越足(`#file:`),生成质量越高。

→ [Lab 0 · 环境补齐 + azd 登录](lab-0-setup.md)
