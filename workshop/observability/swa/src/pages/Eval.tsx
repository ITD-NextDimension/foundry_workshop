const PANEL = { background: "#161a22", borderRadius: 8, border: "1px solid #2a2f3a", padding: 24, marginBottom: 16 };

export function Evaluations() {
  return (
    <div>
      <div style={PANEL}>
        <h2 style={{ marginTop: 0, fontSize: 16 }}>Evaluations</h2>
        <p style={{ color: "#8a8f99", lineHeight: 1.7 }}>
          本 workshop 没有跑 batch evaluation,这里是空的。等你跑了 P0 smoke / nightly P1 之后,评估结果会以
          <code style={{ color: "#66c2a5" }}> gen_ai.evaluation.result </code>
          customEvents 形式回写 App Insights,本页会自动呈现:
        </p>
        <ul style={{ color: "#8a8f99", lineHeight: 1.8 }}>
          <li>每个 evaluator 的均值 / p95 时间序列</li>
          <li>版本间对比(v(n) vs v(n-1))</li>
          <li>失败案例反向链路:点 eval 失败行 → 跳到 <code>/conversation/:id</code></li>
        </ul>
        <p style={{ color: "#8a8f99", lineHeight: 1.7 }}>
          想自己跑评估?参考 <code style={{ color: "#66c2a5" }}>agent-observability-evaluation.md</code> §7 Batch Evaluation。
        </p>
      </div>
    </div>
  );
}
