import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { queryKql, rowsToObjects } from "../../shared/appinsights";

async function handler(req: HttpRequest, ctx: InvocationContext): Promise<HttpResponseInit> {
  const responseId = req.query.get("responseId");
  if (!responseId) {
    return { status: 400, jsonBody: { error: "responseId is required" } };
  }
  if (!process.env.APPINSIGHTS_APPLICATION_ID) {
    return { status: 503, jsonBody: { error: "APPINSIGHTS_APPLICATION_ID not configured", scores: [] } };
  }

  try {
    const safeId = responseId.replace(/"/g, "");
    const kql = `customEvents | where timestamp > ago(30d)
| where name == "gen_ai.evaluation.result"
| where tostring(customDimensions["gen_ai.response.id"]) == "${safeId}"
| project timestamp,
    evaluator = tostring(customDimensions["gen_ai.evaluation.name"]),
    score = todouble(customDimensions["gen_ai.evaluation.score.value"]),
    label = tostring(customDimensions["gen_ai.evaluation.score.label"]),
    explanation = tostring(customDimensions["gen_ai.evaluation.explanation"])
| order by evaluator asc`;
    const rows = rowsToObjects(await queryKql(kql));
    return {
      jsonBody: {
        response_id: responseId,
        scores: rows.map((r) => ({
          evaluator: r.evaluator,
          score: r.score,
          label: r.label,
          explanation: r.explanation,
        })),
      },
    };
  } catch (e: any) {
    ctx.log(`eval-scores query failed: ${e.message}`);
    return { status: 502, jsonBody: { error: e.message } };
  }
}

app.http("evalScores", { route: "eval-scores", methods: ["GET"], authLevel: "anonymous", handler });
