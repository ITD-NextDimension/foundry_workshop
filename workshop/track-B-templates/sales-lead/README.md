# Track B · 销售线索 Agent 模板

> **业务**:网页留言 / 邮件触发 → agent 给线索评分(BANT) + 联系人查重 + 写进 CRM。

## 关键决策点

| 决策 | 选项 |
|------|------|
| 评分模型 | BANT(Budget / Authority / Need / Timeline)各 0-3 分,总分 0-12 |
| 阈值 | ≥ 9 hot → 立刻 assign AE;6-8 warm → MQL 队列;< 6 nurture(放进邮件养护) |
| 数据脱敏 | 不在响应里回显手机号 / 邮箱完整值,做掩码 |
| 查重 | 在 CRM 里**先** lookup 邮箱 + 公司,避免重复 lead |

## 给 Copilot 的提示语

```text
@workspace 参考 #file:track-B-templates/sales-lead/persona.template.md,
生成 personas/sales-lead-agent.md。
角色:入站销售线索筛选员。
工作流:1) 解析留言提取 BANT 信息 2) lead_lookup 查重 3) 算分 4) 决定路由。
**不要**:回显完整邮箱 / 手机号(掩码 ***@xxx.com)。
**不要**:猜没提到的字段,缺失就标 `unknown`。
输出 JSON: {bant: {b, a, n, t}, score, route, dedup: {found, existingLeadId}}
```

```text
@workspace 在 skills/bant-score/ 下创建 SKILL.md + scripts/score.py:
SKILL.md 4 步:用 BANT 维度算分;每维 0-3;阈值 ≥9 hot, 6-8 warm, <6 nurture。
scripts/score.py 接 --b --a --n --t,输出 {score, route}。
```

```text
@workspace 在 tools/crm_leads.py 写两个 @ai_function:
lead_lookup(email, company) → {found, existingLeadId}
create_lead(payload) → {leadId, route}
mock 用 dict;脱敏邮箱后再返回。
```

## 出口验证

```
User: 我们是 Acme,500 人公司,CTO 在评估 LLM 平台,Q3 决策。我邮箱 alice@acme.com。
Agent:
{
  "bant": {"b": 2, "a": 3, "n": 3, "t": 2},
  "score": 10,
  "route": "hot",
  "dedup": {"found": false, "existingLeadId": null},
  "contact_display": {"email": "a***@acme.com", "company": "Acme"}
}
```
