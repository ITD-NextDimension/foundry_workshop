---
templateType: billing-dispute
sla:
  P0: same business day
  P1: 2 business days
  P2: 5 business days
fields:
  - customerId
  - tier
  - invoiceId
  - disputedAmount
  - reason
  - refundQuoteResult
  - policyVersion
---

# Billing Dispute Ticket Template

## Title

`[Billing][<tier>] <reasonShortCode>` (e.g., `[Billing][Enterprise] overcharge-q1`)

## Body

```
## Customer
- ID: <customerId>
- Tier: <tier>
- Invoice: <invoiceId>

## Dispute
- Amount: <disputedAmount> <currency>
- Reason: <one of: overcharge | wrong-tier | unauthorized-use | other>
- User-provided context: <verbatim from conversation, ≤200 chars>

## Refund Quote (from refund-quote skill)
- Max refund: <maxRefund>
- Policy version: <policyVersion>
- Capped: <true/false>

## Recommendation
- Action: <approve | partial-approve | reject | escalate-to-human>
- Reasoning: <≤2 sentences referencing policy section>

## Audit
- crm_lookup snapshot: <tier/arr/contractEnd as of timestamp>
- Conversation IDs: <ids>
```

## Routing

- `approve` / `partial-approve` → `team:billing-ops`
- `reject` → 自动回 customer 并 close
- `escalate-to-human` → `team:billing-manager`
