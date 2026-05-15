import { useState } from "react";
import ReactECharts from "echarts-for-react";
import { Link } from "react-router-dom";
import { useTraces } from "../api";

const PANEL = { background: "#161a22", borderRadius: 8, border: "1px solid #2a2f3a", padding: 12, marginBottom: 16 };

export function Failures() {
  const [agent, setAgent] = useState("billing-agent");
  const { data, error, loading } = useTraces(agent, 60);

  const clusters = data?.failure_clusters || [];

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
        <span style={{ flex: 1 }} />
        {loading && <span style={{ color: "#8a8f99", fontSize: 12 }}>loading…</span>}
        {error && <span style={{ color: "#fc8d62", fontSize: 12 }}>error: {error}</span>}
      </div>

      <div style={PANEL}>
        <h2 style={titleStyle}>失败聚类(error_type × operation × tool_name)</h2>
        <ReactECharts
          style={{ height: 280 }}
          theme="dark"
          option={{
            backgroundColor: "transparent",
            tooltip: {},
            grid: { left: 220, right: 40, top: 10, bottom: 30 },
            xAxis: { type: "value" },
            yAxis: { type: "category", data: clusters.map((c) => `${c.error_type}/${c.operation}${c.tool_name ? "/" + c.tool_name : ""}`) },
            series: [{ type: "bar", data: clusters.map((c) => c.count), itemStyle: { color: "#fc8d62" } }],
          }}
        />
      </div>

      <div style={PANEL}>
        <h2 style={titleStyle}>聚类表</h2>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
          <thead>
            <tr style={{ color: "#8a8f99" }}>
              <th style={th}>Error type</th>
              <th style={th}>Operation</th>
              <th style={th}>Tool</th>
              <th style={th}>Count</th>
              <th style={th}>Sample conversation</th>
            </tr>
          </thead>
          <tbody>
            {clusters.map((c, i) => (
              <tr key={i} style={{ borderBottom: "1px solid #2a2f3a" }}>
                <td style={td}>
                  <span style={{ color: "#fc8d62" }}>●</span> {c.error_type}
                </td>
                <td style={td}>{c.operation}</td>
                <td style={td}>{c.tool_name || "—"}</td>
                <td style={td}>{c.count}</td>
                <td style={td}>
                  <Link to={`/conversation/${c.sample_conversation_id}`} style={{ color: "#66c2a5" }}>
                    {c.sample_conversation_id}
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

const titleStyle = { margin: "0 0 8px 8px", fontSize: 14, color: "#8a8f99", fontWeight: 500 } as const;
const selectStyle = { background: "#161a22", color: "#e6e6e6", border: "1px solid #2a2f3a", padding: "6px 10px", borderRadius: 4, fontSize: 13 } as const;
const th = { padding: "8px 10px", textAlign: "left", fontWeight: 500 } as const;
const td = { padding: "8px 10px" } as const;
