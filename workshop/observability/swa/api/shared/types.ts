/**
 * Shape the SWA frontend (and the offline HTML) expects.
 * Matches observability/offline/data/traces.sample.json.
 */
export interface OfflineTracePayload {
  agent_name: string;
  generated_at: string;
  time_window_minutes: number;
  kpi: {
    qps: number;
    p50_ms: number;
    p95_ms: number;
    p99_ms: number;
    failure_rate: number;
    total_tokens: number;
    input_tokens: number;
    output_tokens: number;
  };
  conversations: Array<{
    conversation_id: string;
    started_at: string;
    agent_name: string;
    success: boolean;
    spans: Array<{
      name: string;
      type: string;
      start: number;
      duration_ms: number;
      success: boolean;
      tool_name?: string;
      tokens_in?: number;
      tokens_out?: number;
      error_type?: string;
      result_code?: number;
    }>;
  }>;
  failure_clusters: Array<{
    error_type: string;
    operation: string;
    tool_name: string | null;
    count: number;
    sample_conversation_id: string;
  }>;
  qps_timeseries: Array<{ t: string; qps: number; p95_ms: number; failure_rate: number }>;
}

export function emptyPayload(agentName: string, minutes: number): OfflineTracePayload {
  return {
    agent_name: agentName,
    generated_at: new Date().toISOString(),
    time_window_minutes: minutes,
    kpi: { qps: 0, p50_ms: 0, p95_ms: 0, p99_ms: 0, failure_rate: 0, total_tokens: 0, input_tokens: 0, output_tokens: 0 },
    conversations: [],
    failure_clusters: [],
    qps_timeseries: [],
  };
}
