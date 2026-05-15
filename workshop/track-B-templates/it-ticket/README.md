# Track B · IT 工单 Agent 模板

> **业务**:公司内部 IT 工单系统,员工提交后由 agent 分类 + 估优先级 + 路由到对应组。

## 关键决策点

| 决策 | 选项 |
|------|------|
| Category | `hardware` / `software` / `network` / `account` / `other` |
| Priority | `P0` (无法工作) / `P1` (有 workaround) / `P2` (一般) |
| Assignee | hardware → IT-Desk;software → DevTools;network → NetOps;account → IAM |
| 何时升级 | 同一人 24h 内 ≥ 2 次同类工单 → 标记 `recurring`,升 P1 |

## 给 Copilot 的提示语

```text
@workspace 参考 #file:track-B-templates/it-ticket/persona.template.md,
生成 personas/it-ticket-agent.md。
角色:公司 IT 工单分类员。
分类规则:hardware / software / network / account / other。
priority 判断:用户明确说"无法工作 / down" → P0;有 workaround → P1;其余 P2。
特殊规则:同人 24h ≥ 2 次同类 → 标记 recurring 并升 P1。
输出 JSON:{category, priority, assignee, recurring, summary}
不能承诺 SLA,引导用户去内部 IT portal 查实时 SLA。
```

```text
@workspace 在 skills/ticket-route/ 下创建 SKILL.md + scripts/route.py:
SKILL.md 3 步:1) 按 category 查 assignee 表 2) 调用 scripts/route.py
3) 若 recurring=true 自动添加 escalation note。
scripts/route.py 接 --category --recurring,输出 JSON {assignee, escalation_note}。
```

```text
@workspace 在 tools/it_directory.py 写 @ai_function lookup_employee,
按 employee_id 返回 {name, department, location, manager_email}。
先用 dict mock。
```

## 出口验证

跑通这个对话:

```
User: 我的 laptop 蓝屏了,完全开不了机,我什么也干不了!
Agent: {category: "hardware", priority: "P0", assignee: "IT-Desk", recurring: false,
        summary: "Laptop unable to boot (blue screen)."}
```
