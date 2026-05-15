# Track B · 简历初筛 Agent 模板

> **业务**:HR 把岗位 JD + 简历(text)给 agent,agent 输出**结构化评估**(技能匹配、经验匹配、风险点),不做录用决定。

## 关键决策点(伦理高敏)

| 决策 | 必做 |
|------|------|
| 公平性 guardrails | **绝不**基于姓名 / 性别 / 籍贯 / 年龄 / 婚育给分;只看技能与经验 |
| 量化标准 | 技能匹配 0-5(列出命中/缺失的技能);经验匹配 0-5(年限 + 相关性) |
| 输出**不是录用决定** | 只是给 HR 看的评分参考,**最终决定权在人** |
| 数据保留 | 在响应中不要回显候选人完整姓名 / 联系方式,用代号 `Candidate#1234` |

## 给 Copilot 的提示语

```text
@workspace 参考 #file:track-B-templates/recruiting/persona.template.md,
生成 personas/recruiting-agent.md。
角色:简历初筛评估员,**只给量化分,不做录用决定**。
公平性:绝不考虑姓名/性别/年龄/籍贯/婚育/学校排名。
评估:skillMatch (0-5) + experienceMatch (0-5),每一项必须列出依据。
特殊:发现**任何**敏感字段被用户在 prompt 里强调(例如 "他是女性"),
直接 refuse 并提醒:"评估只看技能与经验"。
输出 JSON: {candidateId, skillMatch, experienceMatch, summary, redFlags, recommendNextStep: "interview|reject-with-feedback|hold"}
```

```text
@workspace 在 skills/skill-match/ 下创建 SKILL.md + scripts/match.py:
SKILL.md 步骤:1) 解析 JD 的 must-have/nice-to-have 技能
2) 在简历里匹配 3) 返回 {matched, missing, score}
scripts/match.py 接 --jd-skills --resume-text(json),输出 {score, matched, missing}。
```

```text
@workspace 在 tools/applicant_tracking.py 写 @ai_function 两个:
get_jd(job_id) → {title, mustHave: [], niceToHave: []}
attach_evaluation(candidate_id, payload) → {ok: bool}
```

## 出口验证

```
HR: 岗位 ML-PE-001,候选人简历(text)如下:...8 年 Python,5 年 TF/PyTorch,曾在 X 公司...

Agent:
{
  "candidateId": "Candidate#A91X",
  "skillMatch": 4,
  "experienceMatch": 5,
  "summary": "Python 8y + TF/PyTorch 5y 与 JD must-have 完全匹配;nice-to-have JAX 未提及。",
  "redFlags": [],
  "recommendNextStep": "interview"
}
```
