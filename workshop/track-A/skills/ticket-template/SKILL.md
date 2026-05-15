---
name: ticket-template
description: 根据问题类别加载工单模板,产出结构化工单 payload 给 create_ticket
triggers:
  - 用户描述了可复现的 bug
  - 账单争议需要走工单流转
  - 需要升级处理(P0/P1)
---

# Ticket Template 步骤

## 1. 选模板

根据问题类型加载:

| 问题类型 | 模板 |
|---------|------|
| 产品 bug / 配置错误 | `templates/tech-bug.md` |
| 退款 / 账单争议 | `templates/billing-dispute.md` |

## 2. 填字段

把对话中已知字段填进模板:

- `customerId`(来自 crm_lookup)
- `tier`
- `category`(从 persona Output 拿)
- `summary`(≤200 字,概括用户原话 + 你的初步诊断)
- `priority`(P0=客户 down, P1=部分功能, P2=咨询/低影响)
- `attachments`(如有日志、截图链接)

## 3. 调用 `create_ticket`

把模板填好的 dict 传给 `create_ticket(...)` tool。

## 4. 反馈用户

把 `ticketId` 告诉用户,并写明 SLA(从模板 frontmatter 读取)。

## 注意

- **不要**伪造客户日志:模板里 `attachments` 留空就是空,不要编 URL
- **不要**把 `priority` 默认 P0:除非用户明确说 "down" / "outage",否则 P1 起步
- **不要**改模板里的 SLA 文案,SLA 来自合同,**模板即真相**
