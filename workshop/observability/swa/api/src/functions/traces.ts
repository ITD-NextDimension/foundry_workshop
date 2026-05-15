import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { queryKql, rowsToObjects } from "../../shared/appinsights";
import { emptyPayload } from "../../shared/types";

export async function tracesHandler(req: HttpRequest, ctx: InvocationContext): Promise<HttpResponseInit> {
  const agentName = req.query.get("agentName") || process.env.WORKSHOP_DEFAULT_AGENT || "billing-agent";
  const minutes = Math.max(1, Math.min(360, Number(req.query.get("minutes") || 60)));

  const payload = emptyPayload(agentName, minutes);

  if (!process.env.APPINSIGHTS_APPLICATION_ID) {
    ctx.log("APPINSIGHTS_APPLICATION_ID not set; returning empty payload.");
    return { jsonBody: payload };
  }

  try {
    const kqlBase = `let target = "${agentName.replace(/"/g, "")}";
let win = ${minutes}m;`;

    const kpiKql = `${kqlBase}
let r = requests | where timestamp > ago(win) | where tostring(customDimensions["gen_ai.agent.name"]) == target;
let d = dependencies | where timestamp > ago(win)
  | where tostring(customDimensions["gen_ai.agent.name"]) == target
  | where tostring(customDimensions["gen_ai.operation.name"]) == "invoke_agent";
let totalReq = toscalar(r | count);
let failures = toscalar(r | where success == false | count);
let p50 = toscalar(d | summarize p50 = percentile(duration, 50));
let p95 = toscalar(d | summarize p95 = percentile(duration, 95));
let p99 = toscalar(d | summarize p99 = percentile(duration, 99));
let tIn  = toscalar(d | summarize sum(toint(customDimensions["gen_ai.usage.input_tokens"])));
let tOut = toscalar(d | summarize sum(toint(customDimensions["gen_ai.usage.output_tokens"])));
print qps = totalReq * 1.0 / (win / 1s),
      failure_rate = iff(totalReq == 0, 0.0, failures * 1.0 / totalReq),
      p50_ms = coalesce(p50, 0.0),
      p95_ms = coalesce(p95, 0.0),
      p99_ms = coalesce(p99, 0.0),
      input_tokens = coalesce(tIn, 0),
      output_tokens = coalesce(tOut, 0)`;
    const kpi = rowsToObjects(await queryKql(kpiKql))[0];
    if (kpi) {
      payload.kpi = {
        qps: kpi.qps,
        p50_ms: Math.round(kpi.p50_ms),
        p95_ms: Math.round(kpi.p95_ms),
        p99_ms: Math.round(kpi.p99_ms),
        failure_rate: kpi.failure_rate,
        total_tokens: (kpi.input_tokens || 0) + (kpi.output_tokens || 0),
        input_tokens: kpi.input_tokens || 0,
        output_tokens: kpi.output_tokens || 0,
      };
    }

    const tsKql = `${kqlBase}
requests | where timestamp > ago(win)
| where tostring(customDimensions["gen_ai.agent.name"]) == target
| summarize qps = count() * 1.0 / 300, p95_ms = percentile(duration, 95), fails = countif(success == false), total = count() by bin(timestamp, 5m)
| project t = timestamp, qps, p95_ms = coalesce(p95_ms, 0.0), failure_rate = iff(total == 0, 0.0, fails * 1.0 / total)
| order by t asc`;
    payload.qps_timeseries = rowsToObjects(await queryKql(tsKql)).map((r) => ({
      t: new Date(r.t).toISOString(),
      qps: r.qps,
      p95_ms: Math.round(r.p95_ms),
      failure_rate: r.failure_rate,
    }));

    const failKql = `${kqlBase}
dependencies | where timestamp > ago(win)
| where tostring(customDimensions["gen_ai.agent.name"]) == target
| where success == false or toint(resultCode) >= 400
| summarize count = count(), sample_op = take_any(operation_Id)
  by error_type = tostring(customDimensions["error.type"]),
     operation  = tostring(customDimensions["gen_ai.operation.name"]),
     tool_name  = tostring(customDimensions["gen_ai.tool.name"])
| order by count desc`;
    const fails = rowsToObjects(await queryKql(failKql));
    payload.failure_clusters = fails.map((f) => ({
      error_type: f.error_type || "unknown",
      operation: f.operation || "unknown",
      tool_name: f.tool_name || null,
      count: f.count,
      sample_conversation_id: f.sample_op,
    }));

    const convKql = `${kqlBase}
requests | where timestamp > ago(win)
| where tostring(customDimensions["gen_ai.agent.name"]) == target
| project timestamp,
    conversation_id = coalesce(tostring(customDimensions["gen_ai.conversation.id"]), operation_Id),
    success, duration, operation_Id
| order by timestamp desc
| take 20`;
    const convs = rowsToObjects(await queryKql(convKql));

    payload.conversations = await Promise.all(
      convs.map(async (c) => {
        const spansKql = `dependencies | where timestamp > ago(${minutes}m)
| where operation_Id == "${c.operation_Id}"
| project name, type = tostring(customDimensions["gen_ai.operation.name"]),
    start_ts = timestamp, duration, success, result_code = resultCode,
    tool_name = tostring(customDimensions["gen_ai.tool.name"]),
    tokens_in = toint(customDimensions["gen_ai.usage.input_tokens"]),
    tokens_out = toint(customDimensions["gen_ai.usage.output_tokens"]),
    error_type = tostring(customDimensions["error.type"])
| order by start_ts asc`;
        const rows = rowsToObjects(await queryKql(spansKql));
        const t0 = rows[0]?.start_ts ? new Date(rows[0].start_ts).getTime() : 0;
        return {
          conversation_id: c.conversation_id,
          started_at: new Date(c.timestamp).toISOString(),
          agent_name: agentName,
          success: c.success,
          spans: rows.map((s) => ({
            name: s.name,
            type: s.type || "unknown",
            start: t0 ? new Date(s.start_ts).getTime() - t0 : 0,
            duration_ms: Math.round(s.duration),
            success: s.success,
            tool_name: s.tool_name || undefined,
            tokens_in: s.tokens_in || undefined,
            tokens_out: s.tokens_out || undefined,
            error_type: s.error_type || undefined,
            result_code: s.result_code ? Number(s.result_code) : undefined,
          })),
        };
      })
    );
  } catch (e: any) {
    ctx.log(`KQL query failed: ${e.message}`);
    return { status: 502, jsonBody: { error: e.message, payload } };
  }

  return { jsonBody: payload };
}

export async function tracesByConvHandler(req: HttpRequest, ctx: InvocationContext): Promise<HttpResponseInit> {
  const conversationId = req.params.conversationId;
  if (!conversationId) return { status: 400, jsonBody: { error: "conversationId is required" } };

  if (!process.env.APPINSIGHTS_APPLICATION_ID) {
    return { status: 503, jsonBody: { error: "APPINSIGHTS_APPLICATION_ID not configured" } };
  }

  try {
    const safeId = conversationId.replace(/"/g, "");
    const kql = `dependencies | where timestamp > ago(7d)
| where tostring(customDimensions["gen_ai.conversation.id"]) == "${safeId}" or operation_Id == "${safeId}"
| project name, type = tostring(customDimensions["gen_ai.operation.name"]),
    start_ts = timestamp, duration, success, result_code = resultCode,
    tool_name = tostring(customDimensions["gen_ai.tool.name"]),
    tokens_in = toint(customDimensions["gen_ai.usage.input_tokens"]),
    tokens_out = toint(customDimensions["gen_ai.usage.output_tokens"]),
    error_type = tostring(customDimensions["error.type"])
| order by start_ts asc`;
    const rows = rowsToObjects(await queryKql(kql));
    if (!rows.length) return { status: 404, jsonBody: { error: "conversation not found", conversation_id: conversationId } };
    const t0 = new Date(rows[0].start_ts).getTime();
    const success = rows.every((r) => r.success);
    return {
      jsonBody: {
        conversation_id: conversationId,
        started_at: new Date(rows[0].start_ts).toISOString(),
        agent_name: req.query.get("agentName") || "unknown",
        success,
        spans: rows.map((s) => ({
          name: s.name,
          type: s.type || "unknown",
          start: new Date(s.start_ts).getTime() - t0,
          duration_ms: Math.round(s.duration),
          success: s.success,
          tool_name: s.tool_name || undefined,
          tokens_in: s.tokens_in || undefined,
          tokens_out: s.tokens_out || undefined,
          error_type: s.error_type || undefined,
          result_code: s.result_code ? Number(s.result_code) : undefined,
        })),
      },
    };
  } catch (e: any) {
    return { status: 502, jsonBody: { error: e.message } };
  }
}

app.http("traces", { route: "traces", methods: ["GET"], authLevel: "anonymous", handler: tracesHandler });
app.http("tracesByConversation", { route: "traces/{conversationId}", methods: ["GET"], authLevel: "anonymous", handler: tracesByConvHandler });
