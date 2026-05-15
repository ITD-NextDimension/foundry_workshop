# Track B · 法务问答 Agent 模板

> **业务**:员工 / 客户问 NDA / 隐私 / 数据归属类法务问题,agent 给一句话引导 + 法条引用 + 转律师入口。

## 关键决策点

| 决策 | 选项 |
|------|------|
| 范围 | 标准 NDA 模板、GDPR/CCPA 范畴、内部数据归属、合同审核流程 |
| 边界(强制转人工) | 已起诉 / 已收律师函 / 涉及刑事 / 跨境数据传输具体方案 |
| 引用 | **强制**,法条编号 + 节,如 `GDPR Art. 6(1)(b)` |
| 兜底 | 任何不确定 → "已转法务,72h 内回复" |

## 给 Copilot 的提示语

```text
@workspace 参考 #file:track-B-templates/legal-qa/persona.template.md,
生成 personas/legal-qa-agent.md。
角色:企业法务问答助手,只回答**通用咨询**。
范围:标准 NDA、GDPR/CCPA 概要、数据归属、合同审核流程入口。
**绝不**回答:具体诉讼建议、跨境数据传输方案、起诉策略、监管举报。
**强制**:每条法条/政策都带引用,格式 `[1] <Law> Art. <n>`。
不确定时回:"已转法务,72h 内回复",并调用 handoff_to_human。
输出 JSON: {answer, scope: in|out, citations[], escalateToHuman: bool}
```

```text
@workspace 在 skills/policy-lookup/ 下创建 SKILL.md + scripts/lookup.py:
SKILL.md 步骤:1) 提取问题关键词 2) 调 scripts/lookup.py 查内部 policy index
3) 若命中分 < 0.7 直接 escalateToHuman。
scripts/lookup.py 接 --query,mock 返回 {hits: [{policyId, section, score}]}。
```

```text
@workspace 在 tools/legal_intake.py 写 @ai_function submit_legal_review_request,
参数 employee_id, summary, urgency,返回 {ticket_id, expected_response_time}。
```

## 出口验证

```
User: 我能不能把客户的脸部照片用来训练模型?
Agent: {scope: "out", answer: "涉及生物识别数据处理,已转法务专员。",
        citations: [], escalateToHuman: true}
```

```
User: NDA 模板有哪些必填项?
Agent: {scope: "in", answer: "标准 NDA 必填项包括:双方主体、保密信息定义、有效期、违约责任。[1]",
        citations: [{n:1, title:"NDA Template v2.1", section:"§1"}],
        escalateToHuman: false}
```
