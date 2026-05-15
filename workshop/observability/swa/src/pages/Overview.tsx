import { useState } from "react";
import ReactECharts from "echarts-for-react";
import { useTraces } from "../api";

const PANEL = { background: "#161a22", borderRadius: 8, border: "1px solid #2a2f3a", padding: 12, marginBottom: 16 };

export function Overview() {
  const [agent, setAgent] = useState("billing-agent");
  const [minutes, setMinutes] = useState(60);
  const { data, error, loading } = useTraces(agent, minutes);

  return (
    <div>
      <div style={{ ...PANEL, display: "flex", gap: 12, alignItems: "center" }}>
        <label style={{ color: "#8a8f99", fontSize: 13 }}>Agent:</label>
        <select value={agent} onChange={(e) => setAgent(e.target.value)} style={selectStyle}>
          <option value="billing-agent">billing-agent</option>
          <option value="triage-agent">triage-agent</option>
          <option value="tech-support-agent">tech-support-agent</option>
          <option value="kb-agent">kb-agent</option>
        </select>
        <label style={{ color: "#8a8f99", fontSize: 13 }}>Window (min):</label>
        <select value={minutes} onChange={(e) => setMinutes(Number(e.target.value))} style={selectStyle}>
          {[15, 30, 60, 120, 360].map((m) => (
            <option key={m} value={m}>
              {m}
            </option>
          ))}
        </select>
        <span style={{ flex: 1 }} />
        {loading && <span style={{ color: "#8a8f99", fontSize: 12 }}>loading…</span>}
        {error && <span style={{ color: "#fc8d62", fontSize: 12 }}>error: {error}</span>}
      </div>

      {data && (
        <>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: 12, marginBottom: 16 }}>
            <KPI label="QPS" value={data.kpi.qps.toFixed(3)} />
            <KPI label="p50 (ms)" value={String(data.kpi.p50_ms)} />
            <KPI label="p95 (ms)" value={String(data.kpi.p95_ms)} />
            <KPI label="p99 (ms)" value={String(data.kpi.p99_ms)} />
            <KPI label="Failure rate" value={(data.kpi.failure_rate * 100).toFixed(1) + "%"} />
            <KPI label="Tokens in" value={data.kpi.input_tokens.toLocaleString()} />
            <KPI label="Tokens out" value={data.kpi.output_tokens.toLocaleString()} />
          </div>

          <div style={PANEL}>
            <h2 style={titleStyle}>QPS / p95 / failure rate(5min 桶)</h2>
            <ReactECharts
              style={{ height: 320 }}
              theme="dark"
              option={{
                backgroundColor: "transparent",
                tooltip: { trigger: "axis" },
                legend: { textStyle: { color: "#e6e6e6" }, top: 0 },
                grid: { left: 60, right: 60, top: 30, bottom: 30 },
                xAxis: { type: "time" },
                yAxis: [
                  { type: "value", name: "QPS / fail%", min: 0 },
                  { type: "value", name: "p95 (ms)", min: 0 },
                ],
                series: [
                  { name: "QPS",          type: "line", yAxisIndex: 0, data: data.qps_timeseries.map((p) => [p.t, p.qps]),                 color: "#66c2a5" },
                  { name: "Failure rate", type: "line", yAxisIndex: 0, data: data.qps_timeseries.map((p) => [p.t, p.failure_rate * 100]), color: "#fc8d62" },
                  { name: "p95 (ms)",     type: "line", yAxisIndex: 1, data: data.qps_timeseries.map((p) => [p.t, p.p95_ms]),              color: "#ffd166" },
                ],
              }}
            />
          </div>
        </>
      )}
    </div>
  );
}

const titleStyle = { margin: "0 0 8px 8px", fontSize: 14, color: "#8a8f99", fontWeight: 500 } as const;
const selectStyle = { background: "#161a22", color: "#e6e6e6", border: "1px solid #2a2f3a", padding: "6px 10px", borderRadius: 4, fontSize: 13 } as const;

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: "#161a22", padding: 14, borderRadius: 8, border: "1px solid #2a2f3a" }}>
      <div style={{ color: "#8a8f99", fontSize: 12 }}>{label}</div>
      <div style={{ fontSize: 24, marginTop: 6 }}>{value}</div>
    </div>
  );
}
