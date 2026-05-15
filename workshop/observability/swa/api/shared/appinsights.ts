/**
 * App Insights REST API client (KQL via /v1/apps/{appId}/query).
 *
 * Auth: Managed Identity via DefaultAzureCredential — the SWA's MI
 *       must have `Monitoring Reader` on the App Insights resource.
 */
import { DefaultAzureCredential } from "@azure/identity";

const APPINSIGHTS_API = "https://api.applicationinsights.io";

const credential = new DefaultAzureCredential();

async function getToken(): Promise<string> {
  const t = await credential.getToken(`${APPINSIGHTS_API}/.default`);
  if (!t) throw new Error("Failed to acquire token for App Insights API");
  return t.token;
}

export interface KqlResponse {
  tables: Array<{
    name: string;
    columns: Array<{ name: string; type: string }>;
    rows: any[][];
  }>;
}

export async function queryKql(kql: string): Promise<KqlResponse> {
  const appId = process.env.APPINSIGHTS_APPLICATION_ID;
  if (!appId) throw new Error("APPINSIGHTS_APPLICATION_ID env var not set");

  const url = `${APPINSIGHTS_API}/v1/apps/${appId}/query`;
  const token = await getToken();

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query: kql }),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`App Insights query failed: HTTP ${resp.status} ${text}`);
  }
  return (await resp.json()) as KqlResponse;
}

/** Convert KQL response rows to JS objects keyed by column name. */
export function rowsToObjects(resp: KqlResponse): Record<string, any>[] {
  const t = resp.tables[0];
  if (!t) return [];
  return t.rows.map((row) => {
    const obj: Record<string, any> = {};
    t.columns.forEach((col, i) => {
      obj[col.name] = row[i];
    });
    return obj;
  });
}
