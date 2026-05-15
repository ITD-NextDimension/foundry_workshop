import { useEffect, useState } from "react";

export interface Trace {
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

export function useTraces(agentName: string, minutes: number) {
  const [data, setData] = useState<Trace | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const ctrl = new AbortController();
    setLoading(true);
    setError(null);
    fetch(`/api/traces?agentName=${encodeURIComponent(agentName)}&minutes=${minutes}&format=offline`, {
      signal: ctrl.signal,
    })
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((j: Trace) => setData(j))
      .catch((e) => {
        if (e.name !== "AbortError") setError(e.message);
      })
      .finally(() => setLoading(false));
    return () => ctrl.abort();
  }, [agentName, minutes]);

  return { data, error, loading };
}

export function useConversation(conversationId: string | undefined) {
  const [data, setData] = useState<Trace["conversations"][number] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!conversationId) {
      setData(null);
      return;
    }
    setLoading(true);
    setError(null);
    fetch(`/api/traces/${encodeURIComponent(conversationId)}`)
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((j) => setData(j))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [conversationId]);

  return { data, error, loading };
}
