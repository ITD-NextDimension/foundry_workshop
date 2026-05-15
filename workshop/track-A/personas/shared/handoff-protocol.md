---
shared: true
version: 1.0.0
owner: support-team@contoso.com
---

# Handoff Protocol(子 agent 交接术语)

## 何时交接

| 当前 agent | 触发场景 | 目标 agent |
|----------|--------|----------|
| TriageAgent | 用户问题分类完成 | TechSupport / Billing / KB |
| BillingAgent | 涉及产品 bug / API 配置 | TechSupport |
| TechSupport | 涉及账单 / 退款 / 用量 | Billing |
| 任意 | 法律 / 监管 / 严重投诉 | Human |

## 交接 payload

调用 `handoff_to_<target>` 时,**必须**带:

```json
{
  "conversationId": "<原会话 ID>",
  "fromAgent": "<当前 agent>",
  "reason": "<一句话理由>",
  "context": {
    "customerId": "<已知>",
    "tier": "<已知,可空>",
    "summary": "<前 1-2 轮的关键事实摘要,≤100 字>"
  },
  "priority": "P0|P1|P2"
}
```

## 反向不发生

- **不要循环交接**:接收方判断已自己能处理,则停止交接。如果连续两次被同一对 agent 来回交接,**强制 handoff_to_human**。
- **不要丢弃用户消息**:交接时把用户最后一条原话放进 `context.summary`,目标 agent 看上下文继续。

## 交接后的回复

源 agent 把工具返回的 `acknowledgmentId` 告诉用户:

> "已转 <目标 agent>,工单号 #<acknowledgmentId>,稍候继续。"
