---
name: invoice-explain
description: 发票解读标准 5 步流程：OCR → 解析元数据 → 行项分类 → 多币种归一 → 异常标记 + PII 脱敏 → 结构化 JSON。
triggers:
  - 用户上传发票图片或 PDF（含 image_url / pdf_url / source_url 字段）
  - 用户问"每笔花在哪 / 这张发票总共多少 / 哪些是差旅"
  - 用户输入含"发票 / 账单 / 收据 / invoice / receipt"关键词
scripts: []
---

# Invoice Explain 流程

## 1. 调 `ocr_extract` 抽取文本

把用户提供的 URL（图片或 PDF）交给 `ocr_extract`：

```text
ocr_extract(source_url="https://example.com/x.jpg", lang="auto")
→ { text, blocks: [{bbox, text, confidence}], pages, source: "mock|azure" }
```

记下 `blocks` 的平均 confidence — 后续 confidence 评级要用。

**禁止**自己从 source_url 推测内容（必须真的调工具）。

## 2. 解析发票元数据（不调工具，纯 LLM）

从 `text` 与 `blocks` 中识别：

| 字段 | 提取规则 |
|------|---------|
| `vendor` | 通常在右上角 / 顶部第一块；找"公司 / 商家 / Co. / Ltd."关键词 |
| `invoiceNumber` | "发票号 / No. / Invoice #" 紧邻的字符串 |
| `date` | 找 `YYYY-MM-DD` / `YYYY/MM/DD` / `YYYY 年 MM 月 DD 日`，标准化为 `YYYY-MM-DD` |
| `currency` | 看金额符号（¥/$/€/£/HK$）或显式 `CNY/USD/EUR` 标识 |
| `total` | 找"合计 / 总计 / Total / Grand Total"紧邻的金额 |

未识别的字段填 `null`，**不要编造**。

## 3. 调 `classify_charges` 整批分类

把每一行 line item 组成 list 一次性喂入：

```text
classify_charges(
  items=[
    {"description": "拿铁咖啡", "amount": 30.00, "currency": "CNY"},
    {"description": "提拉米苏", "amount": 22.50, "currency": "CNY"},
    ...
  ]
)
→ { classified: [{...原字段, category: "餐饮|差旅|办公|通讯|培训|其他"}] }
```

**禁止**逐行调用（浪费 token + span 噪音）。**禁止**自己手动判断类目（用工具结果）。

## 4. 多币种归一（条件触发）

仅在以下条件之一满足时调 `currency_normalize`：

- 任何 line item 的 `currency` 不是 `CNY`
- 用户**显式**要求"折算成人民币 / convert to CNY"

```text
currency_normalize(
  amounts=[{"amount": 23.50, "currency": "USD"}, {"amount": 18, "currency": "EUR"}],
  target="CNY"
)
→ { normalized: [{...原字段, target_amount, rate, rate_source: "mock|frankfurter"}] }
```

若全部 line items 都是 CNY，**跳过这一步**。

## 5. 异常标记 + PII 脱敏 + 组装输出

- **suspiciousFlags**：满足任一条件加 flag
  - 单项 amount > 1000 且 description 仅 1-2 个字（疑似汇总而非明细）
  - sum(lineItems) ≠ invoiceMeta.total（允许 ±0.01 浮点误差）
  - 同一 description 出现 2 次以上但 amount 不同（疑似重复扣费或单价变动）

- **PII 脱敏**：用正则 `\b\d{8,}\b` 匹配连续 8 位以上数字串 → 保留首尾 4 位，中间用 `*` 替换。
  例：`6225760012345678` → `6225 **** **** 5678`

- **confidence 评级**（详见 persona 输出契约）：
  - `high`：OCR avg confidence ≥ 0.9 + 所有行命中分类字典（无 `其他`）+ sum 校验通过
  - `medium`：OCR 0.7-0.9 或 ≥1 项 `其他`
  - `low`：OCR < 0.7 或 sum 不平或 mock 数据

把以上结果按 `personas/invoice-explainer.md` 的输出契约组装成 JSON 返回。

## 边界

- 不直接对外网 HTTP（OCR / 汇率 / PDF 抓取都通过 `@tool` 完成）。
- 不调其它 `@tool`（agent 编排，工具是叶子节点）。
- 遇到税务相关问题 → 触发 `personas/shared/guardrails.md` 的拒绝流程。
- 关联 skill：`citation-format` 的脱敏规则适用于 PII 脱敏格式。
