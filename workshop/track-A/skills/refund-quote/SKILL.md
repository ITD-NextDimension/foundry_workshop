---
name: refund-quote
description: 根据客户 tier + 请求金额 + 合同情况计算可退金额上限,引用政策版本
triggers:
  - 用户问"我能退多少"
  - 账单争议涉及具体金额
  - tier 变更后追溯退款
scripts:
  - quote.py
---

# Refund Quote 步骤

## 1. 读 tier

```text
调用 crm_lookup(customer_id) → {tier, arr, contractEnd}
```

如果 `customer_id` 未知,先问用户;**不要**编 tier。

## 2. 调用 quote.py

```bash
python scripts/quote.py --tier <tier> --amount <requested_amount> --contract-end <contractEnd> --today <YYYY-MM-DD>
```

输出 JSON:

```json
{
  "maxRefund": <number>,
  "policyVersion": "v3.2",
  "capped": <bool>,
  "explanation": "<内部诊断,不要直接给用户>"
}
```

## 3. 把结果给用户

格式参考 `personas/billing-agent.md` 的 Output 段;**必须**附 `policyVersion` 作引用。

## 4. 处理超额请求

如果 `requested_amount > maxRefund`(`capped=true`):

- **必须**告知差额来源(例:"政策 v3.2 上限 50%,您要的 60% 超过 10%")
- **不要**说"我帮您争取"
- 引导用户:"如有特殊情况,请回复 'escalate' 由人工 review"

## 5. 越权情形

- Tier=Free 且 amount > 0:**直接拒绝**(参考 persona 的 Ex2 模板)
- Tier 与 amount 不匹配:**先 crm_lookup 二次确认**,确实不匹配则进入 escalate 流程
