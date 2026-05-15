# Track A · 企业客户支持 Agent Harness(参考实现)

> 一个**完整可跑**的客户支持多 agent harness,作为 workshop 讲师 demo + Track A 学员的对照模板。

## 架构

```
用户问题
   │
   ▼
[TriageAgent] ── 分类 ──┬─→ [TechSupportAgent]  + KB 检索 + 工单创建
                       ├─→ [BillingAgent]      + 退款额度计算 + CRM 更新
                       ├─→ [KBAgent]           + 文档检索 + 引用
                       └─→ 直接答 / 兜底
```

## 目录

```
track-A/
├── personas/                 # Soul (markdown)
│   ├── shared/
│   │   ├── guardrails.md
│   │   ├── handoff-protocol.md
│   │   └── citation-format.md
│   ├── triage-agent.md
│   ├── billing-agent.md
│   ├── tech-support-agent.md
│   └── kb-agent.md
├── skills/                   # MAF SkillsProvider 加载
│   ├── refund-quote/
│   │   ├── SKILL.md
│   │   └── scripts/quote.py
│   ├── ticket-template/
│   │   ├── SKILL.md
│   │   └── templates/{tech-bug.md, billing-dispute.md}
│   └── kb-search/SKILL.md
├── tools/                    # client-side @ai_function (Python)
│   ├── crm.py
│   ├── ticketing.py
│   ├── handoff.py
│   └── _shared/auth.py
├── src/                      # 每个 agent 一个子目录
│   ├── billing_agent/
│   │   ├── main.py
│   │   ├── agent.yaml
│   │   ├── agent.manifest.yaml
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── triage_agent/         # 同上结构
│   ├── tech_support_agent/   # 同上结构
│   ├── kb_agent/             # 同上结构
│   └── shared/
│       ├── persona.py        # load_persona() with {{include}}
│       ├── client_factory.py # FoundryChatClient 工厂
│       └── skill_runner.py   # 沙箱 script_runner
├── workflows/                # L4 编排
│   └── triage.workflow.yaml
├── .foundry/
│   └── agent-metadata.yaml   # project endpoint / agent 名 / testCases
├── tests/unit/               # tool + skill_runner 单测
├── azure.yaml                # azd 入口(workshop 自动注入)
├── requirements.txt          # 顶层(本地 agentdev 用)
└── README.md                 # 本文件
```

## 本地跑通(Lab 2 末尾)

```powershell
# 1. 装依赖
pip install -r requirements.txt

# 2. 环境变量
$env:AZURE_AI_PROJECT_ENDPOINT      = azd env get-value AZURE_AI_PROJECT_ENDPOINT
$env:FOUNDRY_MODEL_DEPLOYMENT_NAME  = azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME

# 3. 起 billing-agent
agentdev run src/billing_agent/main.py --port 8087

# 4. 另一个终端发请求
$body = @{ input = "我是 Acme 企业版客户,上月用量 10%,能退多少?" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

## 部署到 Foundry(Lab 3)

```powershell
azd ai agent init -m src/billing_agent/agent.yaml
azd deploy billing-agent
```

详见 [`../docs/lab-3-deploy.md`](../docs/lab-3-deploy.md)。
