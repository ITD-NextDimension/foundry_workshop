import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useConversation, useTraces } from "../api";

const PANEL = { background: "#161a22", borderRadius: 8, border: "1px solid #2a2f3a", padding: 12, marginBottom: 16 };

export function Conversation() {
  const { id } = useParams();
  const [agent, setAgent] = useState("billing-agent");
  const { data: list } = useTraces(agent, 60);
  const { data: detail } = useConversation(id);

  return (
    <div>
      <div style={{ ...PANEL, display: "flex", gap: 12, alignItems: "center" }}>
        <label style={{ color: "#8a8f99", fontSize: 13 }}>Agent (for browsing):</label>
        <select value={agent} onChange={(e) => setAgent(e.target.value)} style={selectStyle}>
          <option value="billing-agent">billing-agent</option>
          <option value="triage-agent">triage-agent</option>
          <option value="tech-support-agent">tech-support-agent</option>
          <option value="kb-agent">kb-agent</option>
        </select>
      </div>

      <div style={PANEL}>
        <h2 style={titleStyle}>选一条 Conversation</h2>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
          <thead>
            <tr style={{ color: "#8a8f99" }}>
              <th style={th}>Conversation</th>
              <th style={th}>Started</th>
              <th style={th}>Spans</th>
              <th style={th}>Status</th>
            </tr>
          </thead>
          <tbody>
            {(list?.conversations || []).map((c) => (
              <tr key={c.conversation_id} style={{ borderBottom: "1px solid #2a2f3a" }}>
                <td style={td}>
                  <span style={{ color: c.success ? "#66c2a5" : "#fc8d62" }}>●</span>{" "}
                  <Link to={`/conversation/${c.conversation_id}`} style={{ color: "#66c2a5" }}>
                    {c.conversation_id}
                  </Link>
                </td>
                <td style={td}>{c.started_at}</td>
                <td style={td}>{c.spans.length}</td>
                <td style={td}>
                  <span
                    style={{
                      padding: "2px 6px",
                      borderRadius: 4,
                      fontSize: 11,
                      background: c.success ? "rgba(102,194,165,0.2)" : "rgba(252,141,98,0.2)",
                      color: c.success ? "#66c2a5" : "#fc8d62",
                    }}
                  >
                    {c.success ? "OK" : "FAIL"}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {detail && <SpanTimeline conversation={detail} />}
    </div>
  );
}

function SpanTimeline({ conversation }: { conversation: ReturnType<typeof useConversation>["data"] }) {
  if (!conversation) return null;
  const max = Math.max(...conversation.spans.map((s) => s.start + s.duration_ms));
  return (
    <div style={PANEL}>
      <h2 style={titleStyle}>
        Span 时间线 — <span style={{ color: "#e6e6e6" }}>{conversation.conversation_id}</span>
      </h2>
      <div>
        {conversation.spans.map((s, i) => {
          const widthPct = Math.max(0.5, (s.duration_ms / max) * 100);
          const offsetPct = (s.start / max) * 100;
          return (
            <div
              key={i}
              style={{ display: "grid", gridTemplateColumns: "260px 1fr 80px", alignItems: "center", gap: 12, padding: "6px 0", fontSize: 13 }}
            >
              <div style={{ color: s.type === "request" ? "#e6e6e6" : "#8a8f99", paddingLeft: s.type === "request" ? 0 : 16 }}>{s.name}</div>
              <div style={{ position: "relative", height: 8 }}>
                <div
                  style={{
                    position: "absolute",
                    left: `${offsetPct}%`,
                    width: `${widthPct}%`,
                    height: 8,
                    background: s.success ? "#66c2a5" : "#fc8d62",
                    borderRadius: 4,
                  }}
                />
              </div>
              <div style={{ color: "#8a8f99", textAlign: "right" }}>{s.duration_ms}ms</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

const titleStyle = { margin: "0 0 8px 8px", fontSize: 14, color: "#8a8f99", fontWeight: 500 } as const;
const selectStyle = { background: "#161a22", color: "#e6e6e6", border: "1px solid #2a2f3a", padding: "6px 10px", borderRadius: 4, fontSize: 13 } as const;
const th = { padding: "8px 10px", textAlign: "left", fontWeight: 500 } as const;
const td = { padding: "8px 10px" } as const;
