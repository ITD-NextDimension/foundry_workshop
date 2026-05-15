---
templateType: tech-bug
sla:
  P0: 4h response, 24h workaround
  P1: 8h response, 48h workaround
  P2: 2 business days response
fields:
  - customerId
  - tier
  - sdkVersion
  - region
  - errorCode
  - reproSteps
  - expectedBehavior
  - actualBehavior
  - attachments
---

# Tech Bug Ticket Template

## Title

`[<tier>] <oneLineSummary>` (≤80 chars)

## Body

```
## Environment
- Customer: <customerId> (<tier>)
- SDK: <sdkVersion>
- Region: <region>

## Error
- Code: <errorCode>
- Stack/Log excerpt: <≤20 lines, code-fenced>

## Reproduction
<numbered steps the customer can demonstrate>

## Expected
<expectedBehavior>

## Actual
<actualBehavior>

## Attachments
<list of URLs or "none">

## Triage Notes
<your initial diagnosis, KB references with [n] citations>
```

## Routing

- 默认 → `team:product-engineering`
- 含 `errorCode` 以 `IAM-` 开头 → `team:identity`
- 含 `region` 为 `customer-managed` → `team:cmek-ops`
