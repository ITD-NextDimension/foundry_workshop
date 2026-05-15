import { Link, Route, Routes, useLocation } from "react-router-dom";
import { Overview } from "./pages/Overview";
import { Failures } from "./pages/Failures";
import { Conversation } from "./pages/Conversation";
import { Evaluations } from "./pages/Eval";

const TABS = [
  { to: "/overview", label: "Overview" },
  { to: "/failures", label: "Failures" },
  { to: "/conversation", label: "Conversation" },
  { to: "/eval", label: "Eval" },
];

export function App() {
  const loc = useLocation();
  return (
    <div style={{ minHeight: "100vh" }}>
      <header style={{ padding: "14px 24px", background: "#161a22", borderBottom: "1px solid #2a2f3a", display: "flex", alignItems: "center", gap: 16 }}>
        <h1 style={{ margin: 0, fontSize: 18 }}>Workshop Observability</h1>
        <span style={{ background: "#2a2f3a", color: "#8a8f99", padding: "2px 8px", borderRadius: 4, fontSize: 12 }}>SWA</span>
        <span style={{ flex: 1 }} />
        <a href="https://github.com/azure-ai-foundry/foundry-samples" style={{ color: "#8a8f99", fontSize: 12 }}>foundry-samples 鈫?/a>
      </header>

      <nav style={{ background: "#161a22", padding: "0 24px", display: "flex", gap: 8, borderBottom: "1px solid #2a2f3a" }}>
        {TABS.map((t) => {
          const active = loc.pathname.startsWith(t.to);
          return (
            <Link
              key={t.to}
              to={t.to}
              style={{
                color: active ? "#e6e6e6" : "#8a8f99",
                textDecoration: "none",
                padding: "12px 16px",
                borderBottom: active ? "2px solid #66c2a5" : "2px solid transparent",
                fontSize: 14,
              }}
            >
              {t.label}
            </Link>
          );
        })}
      </nav>

      <main style={{ padding: 24, maxWidth: 1400, margin: "0 auto" }}>
        <Routes>
          <Route path="/" element={<Overview />} />
          <Route path="/overview" element={<Overview />} />
          <Route path="/failures" element={<Failures />} />
          <Route path="/conversation" element={<Conversation />} />
          <Route path="/conversation/:id" element={<Conversation />} />
          <Route path="/eval" element={<Evaluations />} />
        </Routes>
      </main>

      <footer style={{ padding: "16px 24px", color: "#8a8f99", fontSize: 12, textAlign: "center" }}>
        workshop 路 SWA observability 路 涓嶇櫥 Azure Portal,鎵€鏈夋暟鎹粠 SWA Functions 缁?App Insights REST API 鎷?
      </footer>
    </div>
  );
}

