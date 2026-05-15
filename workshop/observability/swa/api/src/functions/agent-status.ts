import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

/**
 * Placeholder for hosted agent container status.
 *
 * Real implementation would call Foundry MCP `agent_container_status_get`.
 * In this workshop we return a derived status from recent App Insights pings
 * (or a static "unknown" so the frontend doesn't break).
 */
async function handler(req: HttpRequest, _ctx: InvocationContext): Promise<HttpResponseInit> {
  const agentName = req.query.get("agentName") || "billing-agent";
  return {
    jsonBody: {
      agent_name: agentName,
      status: "unknown",
      note: "Live container status requires Foundry MCP agent_container_status_get; see Phase 3 docs.",
      replicas: { running: null, min: 1, max: 3 },
    },
  };
}

app.http("agentStatus", { route: "agent-status", methods: ["GET"], authLevel: "anonymous", handler });
