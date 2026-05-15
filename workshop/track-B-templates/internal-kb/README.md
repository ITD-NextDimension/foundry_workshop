# Track B · 内部知识库 Agent 模板

> **业务**:员工问内部 wiki / Confluence / SharePoint 上的事(政策、流程、产品手册),agent 检索 + 引用 + 提示权限。

## 关键决策点

| 决策 | 选项 |
|------|------|
| 检索范围 | server-side `file_search` 或 `azure_ai_search` 接 wiki/SharePoint 索引 |
| 权限提示 | 命中文档若被标 `confidential` → 提示"此文档受限,请先申请访问" |
| 引用 | **强制**,每个事实 `[n]`,citations 段含 doc title + section + URL |
| 兜底 | top1 < 0.65 → "我不太确定,建议看 wiki" |

## 给 Copilot 的提示语

```text
@workspace 参考 #file:track-B-templates/internal-kb/persona.template.md
和 #file:track-A/personas/kb-agent.md,
生成 personas/internal-kb-agent.md。
范围:回答公司内部 wiki / 流程类问题。
**强制**引用每个事实,格式参考 shared/citation-format.md。
权限:若命中文档 confidential=true,提示用户先申请访问,**不要**复述文档内容。
不确定:top1 retrieval score < 0.65 → 直接说"建议看 wiki"。
输出 JSON: {answer, confidence, citations, accessRestricted: bool, suggestedNextStep}
```

```text
@workspace 在 skills/wiki-search/ 下创建 SKILL.md(纯 prompt,无脚本)。
内容:重写 query → 检索 → rerank → 输出骨架。
```

```text
@workspace 在 tools/wiki_metadata.py 写 @ai_function check_access,
按 doc_id 返回 {confidential: bool, requiredRole: <str|null>}。
```

## 出口验证

```
User: 公司差旅报销标准是?
Agent: {
  "answer": "差旅报销:经济舱机票实报实销 + 每日餐补 200 RMB。[1]",
  "confidence": "high",
  "citations": [{n:1, title:"差旅政策 2026", section:"§2"}],
  "accessRestricted": false,
  "suggestedNextStep": null
}
```

```
User: 给我看 M&A 项目代号 "Project Apollo" 的进展。
Agent: {
  "answer": "该文档为保密项目,需 M&A 团队授权访问。",
  "confidence": "high",
  "citations": [],
  "accessRestricted": true,
  "suggestedNextStep": "请联系您的部门 VP 申请权限。"
}
```
