# Offline Observability(Lab 4 兜底)

> 网络 / SWA 故障时的备胎。单文件 HTML + 内置 echarts CDN。

## 跑起来

```powershell
# 直接打开(双击 index.html 或:)
start index.html
```

页面有 3 个 Tab:

- **Overview** — KPI 卡 + QPS/p95/failure rate 时序图
- **Failures** — 失败聚类柱状图 + 表格
- **Conversation** — 选一条对话看 span 时间线

## 数据源

顶栏选 `traces.sample.json`(讲师 demo)或 `my-traces.json`(你刚导出的)。

导出自己的:

```powershell
..\..\workshop-scripts\export-traces.ps1 -AgentName billing-agent -Minutes 60
```

## 完全离线版

如果连 echarts CDN 都挂(企业内网),用助教信封 USB 里的 `offline-full/` 版本:那里 echarts 已经内嵌到 HTML 里。

## 数据格式

```jsonc
{
  "agent_name": "billing-agent",
  "kpi": { "qps": ..., "p95_ms": ..., "failure_rate": ..., ... },
  "conversations": [
    { "conversation_id": ..., "spans": [{"name", "type", "start", "duration_ms", "success", ...}] }
  ],
  "failure_clusters": [
    { "error_type", "operation", "tool_name", "count", "sample_conversation_id" }
  ],
  "qps_timeseries": [
    { "t": "<iso>", "qps", "p95_ms", "failure_rate" }
  ]
}
```

SWA API `/api/traces?format=offline` 输出格式与此**完全一致**,可直接喂给本页。
