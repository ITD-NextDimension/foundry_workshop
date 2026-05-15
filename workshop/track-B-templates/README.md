# Track B · 自带业务模板(5 套)

> 如果你在 Lab 2 想跑自己的业务而不是参考的"企业客户支持"场景,从这里挑一个最接近你业务的模板,改 persona / skill / tool 名字与具体规则。

## 模板清单

| 模板目录 | 业务 | 关键决策点 |
|---------|------|----------|
| [`it-ticket/`](./it-ticket) | IT 工单分类 + 创建 | priority 判断 / assignee 路由 |
| [`legal-qa/`](./legal-qa) | 法务问答(NDA / 隐私 / 数据归属) | 何时强制转人工 / 引用法条格式 |
| [`sales-lead/`](./sales-lead) | 销售线索筛选 + CRM 录入 | 评分模型 / 数据脱敏 |
| [`recruiting/`](./recruiting) | 简历初筛 + 候选人评估 | 公平性 guardrails / 量化标准 |
| [`internal-kb/`](./internal-kb) | 内部知识库问答 | 文档权限 / 引用必需 |

## 每个模板包含

```
<template>/
├── README.md               # 业务背景、决策点、给 Copilot 的提示语建议
├── persona.template.md     # Soul 模板,带 frontmatter + 占位符
├── skill.template/
│   ├── SKILL.md            # 步骤说明书占位
│   └── scripts/...         # 业务脚本占位
└── tools.template.py       # 一个 @ai_function 骨架
```

## 用法

1. 选定模板,**整目录复制**进 `track-A/`(或自己的工作目录)
2. 用 Copilot Chat 配合 `README.md` 里的提示语扩写到完整
3. 跑 `python ../workshop-scripts/lint-persona.py persona.md` 验证

> 💡 助教在 Lab 2 学员卡 ≥ 15 min 时会直接切到这里。
