---
name: kb-search
description: 在知识库中检索答案,带 dense + rerank 两阶段,产出可引用的回答骨架
triggers:
  - 用户问事实性问题(定价 / 政策 / 配额)
  - KBAgent 被路由进来
---

# KB Search 步骤

## 1. 重写 query

把用户口语化的问题改写成检索友好的短语:

- ❌ "你们怎么处理我的数据?" → 检索难命中
- ✅ "data residency policy default regions" → 检索友好

## 2. 用 `azure_ai_search` server-side tool

(由 `agent.manifest.yaml` 配置)

- top_k: 5
- semantic_configuration: enabled
- 返回 `[{title, content, section, source_url}]`

## 3. Rerank(由 server-side tool 自动做或人工 prompt)

按"段落与 query 的语义距离 + 文档权威度"重排,取 top 2-3 进答案。

## 4. 输出骨架

按 `personas/kb-agent.md` 的 Output 格式:每个事实 `[n]` 标号,citations 段对应。

## 5. 不确定时

如果 rerank 后 top1 的分 < 0.65,**直接说不知道**,不要硬答。

参考 `personas/kb-agent.md` Ex2。
