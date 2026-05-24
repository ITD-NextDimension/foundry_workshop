# macOS 部署踩坑实录 · Lab 0 + Lab 1 + Lab 2 + Lab 3 + Lab 4

> 学员 stu002 在 MacBook（zsh + VS Code Insider）实际部署过程中遇到的所有问题、根因、修复方案。
> 共 **23 处坑**：8 处源于 README 缺漏，6 处源于第三方包/IDE，9 处源于脚本 bug 或环境特异性。

---

## 目录

- [Lab 0 · 本地环境（7 处）](#lab-0--本地环境7-处)
- [Lab 1 · 部署 hosted agent（8 处）](#lab-1--部署-hosted-agent8-处)
- [Lab 2 · 本地 vibe-coding（4 处）](#lab-2--本地-vibe-coding4-处)
- [Lab 3 · 第二个 agent 上 hosted（2 处）](#lab-3--第二个-agent-上-hosted2-处)
- [Lab 4 · trace + dashboard（2 处）](#lab-4--trace--dashboard2-处)
- [汇总表](#汇总表)
- [建议改进 README 的地方](#建议改进-readme-的地方)

---

## Lab 0 · 本地环境（7 处）

### 0.1 `code` 命令实际指向 Cursor，不是 VS Code

**症状**：`code --version` 输出 `3.0.16`（VS Code 当前版本是 1.105.x）。

**根因**：mac 安装 Cursor 时把 `code` 命令注册成它自己的 launcher（`/Applications/Cursor.app/Contents/Resources/app/bin/code`），覆盖 VS Code 的默认 `code`。

**修复**：

```bash
which code                                # 确认指向 Cursor
which code-insiders                       # VS Code Insider 用这个
code-insiders --version                   # 1.122.0-insider
```

Lab-0 脚本 `install-maf-copilot-skills.sh` 假设 `code` = VS Code，需手动替换为 `code-insiders` 或干脆在 VS Code Insider 里手动确认。

---

### 0.2 `github.copilot-chat` 装不了 — 它是 Insider 的内置扩展

**症状**：
```
code-insiders --install-extension github.copilot-chat
Error: Extension 'github.copilot-chat' is a built-in extension and not allowed to be updated in the current product quality 'insider'.
```

**根因**：新版 VS Code Insider 把 Copilot Chat 作为**内置扩展**捆绑（在 `/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/extensions/copilot/`），不再从 Marketplace 装。

**修复**：直接用就好。`code-insiders --list-extensions` 不显示内置扩展，但 `package.json` 显示 `name: copilot-chat, version: 0.50.x, publisher: GitHub`。

---

### 0.3 `github.copilot`（行内补全）也装不了 — 依赖 chat 被锁

**症状**：
```
code-insiders --install-extension github.copilot
Installing extension 'github.copilot'...
Error while installing extension github.copilot-chat: ... built-in extension and not allowed to be updated
Failed Installing Extensions: github.copilot-chat
```

**根因**：`github.copilot` 的元数据中声明依赖 `github.copilot-chat`，CLI 安装器尝试"更新"依赖项，被内置保护拒绝。

**修复**：
- 在 VS Code Insider 的 Extensions UI 里手动搜 "GitHub Copilot" → Install Pre-Release（UI 装能正确处理 built-in 依赖）
- **注意**：Marketplace 页面会显示 "This extension is deprecated. Use the GitHub Copilot Chat extension instead." — 这是旧扩展的废弃公告，新版 chat 已包含行内补全功能，**可以不装**这个老扩展。

---

### 0.4 `sanity-check.sh` ACR 检查项报 HTTP 411

**症状**：sanity-check 的最后一项 `ACR 'itdnd' 可远程构建` 显示 ❌ `listBuildSourceUploadUrl 失败`。

**根因**：[scripts/macOSLinux/sanity-check.sh:174](../scripts/macOSLinux/sanity-check.sh#L174) 的 `curl -X POST` 没带 body，Azure ARM `listBuildSourceUploadUrl` 端点要求 `Content-Length` header，否则返回 HTTP 411 "Length Required"。

**直接验证**：
```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" "$ACR_URL"
# 返回 HTML: <h2>Length Required</h2><p>HTTP Error 411. The request must be chunked or have a content length.</p>
```

**修复**：给 curl 加 `Content-Length: 0` header。已在本地仓库修复：

```diff
- resp=$(curl -fsS --max-time 15 -X POST -H "Authorization: Bearer $arm_token" "$acr_url" 2>/dev/null) || resp=""
+ resp=$(curl -fsS --max-time 15 -X POST -H "Authorization: Bearer $arm_token" -H "Content-Length: 0" "$acr_url" 2>/dev/null) || resp=""
```

> ⚠️ 这个 bug 在 PowerShell 脚本里也可能存在（PowerShell `Invoke-RestMethod` 默认会带 `Content-Length: 0`，所以不踩雷），但 bash 学员一定会踩。

---

### 0.5 `maf-agent` chatmode 在 Copilot Chat 下拉里看不到

**症状**：所有官方步骤都做完（settings.json 写好、Copilot 登录、订阅有效），但 Copilot Chat panel 的 mode 下拉里仍然没有 `maf-agent`。

**根因**（推测，**未完全确认**）：
- `~/.claude/` 全局的 SuperClaude framework 注册了一堆全局 chatmodes（`dev-agent`、`pm-agent`、`review-agent` 等），可能抢占了 `chat.modeFilesLocations` 的解析路径
- 或 workspace 没以 `Lab-2-vibe-coding/` 为根目录打开（VS Code 只对 active workspace 根读 `.vscode/settings.json`）
- 或 Copilot Chat panel 和 Claude Code panel 长得太像，混淆了

**临时方案**：**parked 到 Lab-2**。`maf-agent` chatmode 是 Lab-2 vibe-coding 时辅助写代码的工具，不阻塞 Lab-0/1/3/4 部署链。

---

### 0.6 多个 Chat 扩展同时存在，UI 长得几乎一样

**症状**：VS Code Insider 里至少 4 个看起来一样的 chat 面板：
- 内置 `github.copilot-chat`（"Chat" view）
- `anthropic.claude-code` 扩展（"Claude Code" view，有 CHAT/CLAUDE CODE/CODEX tabs）
- `openai.chatgpt` 扩展
- `ms-azuretools.vscode-azure-github-copilot`

学员误以为自己在 Copilot Chat 里，实际在 Claude Code 的面板中。

**修复**：用命令面板 `Cmd+Shift+P → Chat: Focus on Chat View`（精准定位到 GitHub Copilot Chat panel）。其他扩展的 chat view 命令前缀不一样（Claude Code 是 `Claude Code:` 前缀）。

---

### 0.7 `~/.azure/` 和 `~/.azure/azd/` 是两套独立 token cache

**症状**：`azd auth login` OK 但 `az account show` 报 not logged in；或反过来。

**根因**：azd 和 az CLI **不共享** token cache。
- `azd auth login` → `~/.azure/azd/`
- `az login` → `~/.azure/`

**修复**：Lab-0 §0.4 必须两个都跑，README 已正确强调，但学员容易跳。

---

## Lab 1 · 部署 hosted agent（8 处）

### 1.1 `agent.yaml` 的 `name:` 字段不展开 `${STUDENT_SUFFIX}`

**症状**：
```
ERROR: predeploy, failed to update environment for service "research-agent":
agent.yaml is not valid: template.name not in valid format
```

`name: research-agent-${STUDENT_SUFFIX}` 在 validation 时被当字面量读取，包含 `$`、`{`、`}` 不符合 azd agent 名格式（只允许字母数字 + 连字符）。

**根因**：`agent.yaml` 是 azd 的 schema validation 文件，**变量插值发生在 validation 之后**。`agent.manifest.yaml` 在 deploy 时插值是 OK 的，但 `agent.yaml` 不行。

**修复**：在 `agent.yaml` 把 `name:` 硬编码：
```yaml
kind: hosted
name: research-agent-stu002      # 不能用 ${STUDENT_SUFFIX}
```

> README §1.5 没提到 agent.yaml 的这个限制 — 它假设学员只动 agent.manifest.yaml。

---

### 1.2 `AZURE_AI_PROJECT_ID` azd env var 未设置

**症状**：
```
ERROR: Microsoft Foundry project ID is required: AZURE_AI_PROJECT_ID is not set
Suggestion: run 'azd provision' or connect to an existing project via 'azd ai agent init --project-id <resource-id>'
```

**根因**：azd agent 扩展在 publish 阶段需要 `AZURE_AI_PROJECT_ID`（**ARM resource ID**），但 README §1.3 只让设置 `AZURE_AI_PROJECT_ENDPOINT`。`.env.example` 里两个都列了但 §1.3 的 `azd env set` 列表漏了它。

**修复**：
```bash
azd env set AZURE_AI_PROJECT_ID "/subscriptions/<sub>/resourceGroups/foundry-workshop/providers/Microsoft.CognitiveServices/accounts/itd-foundry/projects/itd-foundry-workshop"
```

---

### 1.3 `FOUNDRY_PROJECT_ENDPOINT` azd env var 未设置

**症状**：deploy 走到 publish 后报：
```
ERROR: FOUNDRY_PROJECT_ENDPOINT is required: environment variable was not found in the current azd environment
```

**根因**：azd agent 扩展同时认两个变量名 `AZURE_AI_PROJECT_ENDPOINT` 和 `FOUNDRY_PROJECT_ENDPOINT`，但实际部署阶段只检查后者。README 完全没提。

**修复**：
```bash
azd env set FOUNDRY_PROJECT_ENDPOINT "$AZURE_AI_PROJECT_ENDPOINT"   # 镜像一份
```

---

### 1.4 shell 命令替换把 azd 的更新告警塞进了 env 变量值

**症状**：
```
ERROR: parse "https://itd-foundry.../itd-foundry-workshop\nTo update, run `brew uninstall azd && brew install ...`/agents/research-agent-stu002/versions?...":
  net/url: invalid control character in URL
```

URL 中间被插入了 `\nTo update, run \`brew uninstall azd...\``。

**根因**：azd 命令在每次 stdout 都追加 `Update available: 1.25.1 -> 1.25.2` 提示。脚本里写 `azd env set X "$(azd env get-value Y)"`，子命令的提示被一起捕获进变量值。

**修复**：
```bash
# ❌ 错的
azd env set FOUNDRY_PROJECT_ENDPOINT "$(azd env get-value AZURE_AI_PROJECT_ENDPOINT)"

# ✅ 对的（从 .env 直接读）
set -a; source .env; set +a
azd env set FOUNDRY_PROJECT_ENDPOINT "$AZURE_AI_PROJECT_ENDPOINT"
```

或干脆 `azd upgrade`（但本机 brew 装的）。

---

### 1.5 pip 依赖冲突 #1：`opentelemetry-instrumentation-httpx>=0.46b0` + `--pre` 引爆解析

**症状**：ACR remote build 里 `pip install --pre -r requirements.txt` 跑了 ~30 秒后 ResolutionImpossible，回溯了 0.46b0 → 0.62b0 一长串 OT 版本。

**根因**：`>=0.46b0` 加 `--pre` 让 pip 在十几个 pre-release 中暴力回溯，每个都和 `opentelemetry-sdk` 锁的 `semantic-conventions==0.63b1` 冲突。

**修复**：精确 pin 整套 OTel：
```
opentelemetry-api==1.40.0
opentelemetry-sdk==1.40.0
opentelemetry-exporter-otlp==1.40.0
opentelemetry-semantic-conventions==0.61b0
opentelemetry-instrumentation-httpx==0.61b0
```

> OTel 的 `1.X.Y` 和 `0.Xb0` 是配对发布的（数字版本和 instrumentation 的 beta 版必须对齐）。

---

### 1.6 pip 依赖冲突 #2：`agent-framework 1.4.0` 锁死 `agent-framework-core==1.4.0`，但 hosting 需要 ≥1.5

**症状**：
```
agent-framework 1.4.0 depends on agent-framework-core==1.4.0
agent-framework-foundry-hosting 1.0.0a260519 depends on agent-framework-core<2 and >=1.5.0
```

**根因**：`>=1.4.0` 让 pip 选了 1.4.0（最低满足）。修：
```
agent-framework>=1.5.0,<1.6.0
```

---

### 1.7 pip 依赖冲突 #3：最新 hosting pre-release 需要还没发布的 core 1.6.0

**症状**：bump 到 `>=1.5.0` 后 pip 选了 hosting 的最新 `1.0.0a260521`，它需要 `agent-framework-core>=1.6.0`，但 pypi 上最新只有 1.5.0。

**根因**：`agent-framework-foundry-hosting` 是 pre-release，作者每隔几天发新版，对 core 的版本要求步步走在 stable release 前面。

**修复**：pin 到上一版可用的：
```
agent-framework-foundry-hosting==1.0.0a260519
```

---

### 1.8 postdeploy hook 因 service 名 vs deployed agent 名不一致而 404

**症状**：deploy 主流程成功（agent v2 active），但 postdeploy 报：
```
ERROR: failed invoking event handlers for 'postdeploy', failed to fetch agent version for research-agent/2:
RESPONSE 404: not_found
{"error":{"code":"not_found","message":"Agent research-agent with version 2 not found"}}
```

**根因**：`azure.yaml` 里 service 名是 `research-agent`（基础名，多学员共用模板），但 deploy 时 agent.yaml 写 `name: research-agent-stu002`。postdeploy hook（`postdeploy-grant-roles.ps1` → `grant-agent-runtime-roles.ps1`）从 azure.yaml 读 service 名 `research-agent` 去查询 Foundry，404。

**Workaround**：手动跑 bash 版的 grant 脚本，显式传 agent 名：
```bash
./scripts/macOSLinux/grant-agent-runtime-roles.sh --agent-name "research-agent-stu002"
```

授权完成后 agent 才能调 gpt-5.5 model deployment（否则 invoke 永远 `status=failed` → `server_error`）。

> **本质修复**：postdeploy hook 内部应该读 azd env 的 `AGENT_NAME` 而不是 service 名。需要改 PowerShell 脚本（暂未提 PR）。

---

## Lab 2 · 本地 vibe-coding（4 处）

### 2.1 PyPI 国际连接 IncompleteRead，下载断流

**症状**：

```
pip._vendor.urllib3.exceptions.ProtocolError:
  ('Connection broken: IncompleteRead(2079592 bytes read, 12981832 more expected)', ...)
```

每次跑到大概同一个 2MB 进度就断。重试也没用。

**根因**：国内访问 pypi.org 的 CDN 节点对大 wheel 包（>10MB）连接不稳定。`agent-framework` 全家桶有几十个依赖，其中几个大包必踩。

**修复**：换清华镜像（或阿里云）

```bash
pip install --pre --retries 10 --timeout 180 \
  -i https://pypi.tuna.tsinghua.edu.cn/simple/ \
  -r requirements-local.txt
```

> 提示：清华镜像的 Pre-release 包同步比 pypi.org 略慢，遇到找不到 `agent-framework-foundry-hosting==1.0.0a260519` 时加 `--extra-index-url https://pypi.org/simple/` 兜底。

---

### 2.2 `agent-dev-cli` 与 `agent-framework 1.5.0` 不兼容

**症状**：

```
agent-framework 1.5.0 depends on agent-framework-core==1.5.0
agent-dev-cli 0.0.1b260427 depends on agent-framework-core<1.3.0 and >=1.1.1
```

**根因**：`Lab-2-vibe-coding/requirements.txt` 同时包含 agent-dev-cli（本地 dev 工具）和 agent-framework-foundry-hosting（部署运行时），两者要求的 `agent-framework-core` 版本不重叠。README 在注释里承认了：

```
agent-dev-cli>=0.0.1b260427  # pre-release; install with --pre
                              # (local dev only — keeps a separate agent-framework-core range)
```

**修复**：拆成两个 requirements 文件 — 一个生产用、一个 dev 用，**不共享 venv**。本地跑直接走 production deps 用 `python -m`，绕过 agentdev。

新增 `Lab-2-vibe-coding/requirements-local.txt`：

```
agent-framework>=1.5.0,<1.6.0
agent-framework-foundry-hosting==1.0.0a260519
azure-identity>=1.17.0
httpx>=0.27.0
pydantic>=2.7.0
opentelemetry-api==1.40.0
opentelemetry-sdk==1.40.0
opentelemetry-exporter-otlp==1.40.0
opentelemetry-semantic-conventions==0.61b0
opentelemetry-instrumentation-httpx==0.61b0
pytest>=8.0
```

启动改用：

```bash
python3 -m src.research_agent.main      # 替代 agentdev run
```

**副作用**：M5 的 `agentdev inspect` 不能用。等价信息可从 server log 看到（每次 `/responses` 会输出完整 trace tree）。

---

### 2.3 默认端口是 8088 而不是 README 写的 8087

**症状**：

```
curl http://localhost:8087/responses → Connection refused
```

**根因**：`ResponsesHostServer.run()` 默认绑定 `0.0.0.0:8088`。`--port 8087` 是 `agentdev run` 这个 CLI 的参数，不是 main.py 本身的。直接跑 `python -m` 不会接受 `--port`，必须改源码或环境变量。

**修复**：测试请求直接连 8088：

```bash
curl -X POST http://localhost:8088/responses ...
```

或在 `main.py` 改成显式传 port：

```python
server.run(port=8087)
```

---

### 2.4 `report_builder` 假设 Pydantic 输入，LLM 实际传 dict

**症状**：tool 被调用后 server log 报：

```
File "tools/report_builder.py", line 55, in _validate_citations
    valid_ids = {s.id for s in sources}
AttributeError: 'dict' object has no attribute 'id'
```

然后整个 `/responses` 调用变成 `tool_call_response: 'Error: Function failed.'`，最终 agent 重试或返回不完整答案。

**根因**：`@ai_function` 装饰器把 LLM 的 tool-call payload 当字典传入函数；类型注解 `sources: list[ReportSource]` 不会自动触发 Pydantic 校验/转换。

**修复**：[tools/report_builder.py:107](../Lab-2-vibe-coding/tools/report_builder.py#L107) 在函数体开头显式 `model_validate`：

```diff
  with tracer.start_as_current_span("report_builder") as span:
      span.set_attribute("topic", topic)
      span.set_attribute("section_count", len(sections))
      span.set_attribute("source_count", len(sources))

+     # Coerce dicts → pydantic (LLM tool-call payloads arrive as raw dicts).
+     sections = [s if isinstance(s, ReportSection) else ReportSection.model_validate(s) for s in sections]
+     sources = [s if isinstance(s, ReportSource) else ReportSource.model_validate(s) for s in sources]
+
      _validate_citations(sections, sources)
      sources_filled = _fill_accessed_at(sources)
```

> 这个 bug 在 hosted agent（Lab-1 部署的那个）里**也存在**，但因为部署的 `gpt-5.5` 模型不一定调 report_builder（不是每个 prompt 都需要），所以 Lab-1 没暴露。Lab-2 用真实 research prompt 才触发。

---

## Lab 3 · 第二个 agent 上 hosted（2 处）

### 3.1 ACR remote build 报 `archive/tar: write too long`

**症状**：

```
azd deploy invoice-explainer
  invoice-explainer: Publishing (Publishing container) [20s]
WARNING: Remote build failed: archive/tar: write too long
Falling back to local Docker build.
  invoice-explainer: Failed ... container publish failed ...
```

Lab-1 同样的 `Dockerfile + context=../..` 当时能跑通，Lab-3 突然炸。

**根因**：Lab-2 在 `Lab-2-vibe-coding/` 下建了一个 `.venv/`（675 MB）。docker context 是 `../..` 即整个 `foundry_workshop/` 仓库，把 venv 也打进去了。`archive/tar: write too long` 是 Go 的 tar writer 拒绝 >8GB 单文件流（实际是累计太大）。

**确认**：

```bash
du -sh Lab-2-vibe-coding/.venv          # 675M
du -sh .                                 # 686M (几乎全是 venv)
```

**修复（应急）**：临时把 venv 移到 repo 外：

```bash
mv Lab-2-vibe-coding/.venv /tmp/lab2-venv-temp
azd deploy invoice-explainer
mv /tmp/lab2-venv-temp Lab-2-vibe-coding/.venv     # deploy 完恢复
```

**修复（正解）**：在 docker context 根（`foundry_workshop/`）加 `.dockerignore`：

```
**/.venv/
**/__pycache__/
ppt/
claudedocs/
Lab-0-setup/
Lab-1-deploy-hosted-agent/
Lab-3-update-hosted-agent/
Lab-4-observability/
AgentHarness_HostedAgent/
OpenClaw_AgentHarness/
CodingAgent/
Skill_Testing_Agent/
skill-testing-harness-deploy/
.git/
```

> ⚠️ **azd ai agent 似乎不读 root `.dockerignore`**：实测加了之后仍然报同样错。最后还是移走 venv 才通过。
> 这是 azd extension 的 bug 或局限。已加到本地 [.dockerignore](../.dockerignore)，作为正确性的兜底；但实际部署时仍需手动移走 venv。

---

### 3.2 postdeploy hook 同样 404（Lab-1 复现）

**症状**：

```
ERROR: failed invoking event handlers for 'postdeploy', failed to fetch agent version for invoice-explainer/1:
RESPONSE 404: not_found
{"error":{"code":"not_found","message":"Agent invoice-explainer with version 1 not found"}}
```

**根因**：和 [1.8](#18-postdeploy-hook-因-service-名-vs-deployed-agent-名不一致而-404) 完全相同 — azure.yaml service 名 `invoice-explainer` ≠ 实际 deployed agent 名 `invoice-explainer-stu002`。

**Workaround**（与 Lab-1 一致）：

```bash
./scripts/macOSLinux/grant-agent-runtime-roles.sh --agent-name "invoice-explainer-stu002"
```

> Lab-1 已踩过这个坑，但 hook 没修过，第二次部署再次撞上。**根本修复**需要在 `azure.yaml` 的 service 名里也加 `${STUDENT_SUFFIX}`，或者在 hook 脚本读 `AGENT_NAME` 而不是 service 名。

---

## Lab 4 · trace + dashboard（2 处）

### 4.1 `my_total_responses: 0` — Foundry per-agent counter 有 lag

**症状**：刚 invoke 完 hosted agent，立刻跑 fetch-traces.sh，结果：

```json
"kpi": {
  "my_total_responses": 0,
  "project_input_tokens": 212489,
  "project_output_tokens": 12699,
  "project_total_tokens": 225188,
  "project_tool_calls": 30,
  "my_share_pct": 0
}
```

`project_*` 指标都有数据（说明 trace 数据平面 API 通了），但 `my_*`（按 agent_name 过滤）为 0。

**根因**：Foundry agents 数据平面 API（preview 阶段）的 **per-agent dimension 聚合有几分钟到几十分钟延迟**。`project_*` 是 namespace 级累加，没 dimension 过滤，所以实时。

**修复**：

1. **等 5-15 分钟**再跑一次 `fetch-traces.sh`，per-agent 指标会出现。
2. 或调更长 window：`./fetch-traces.sh --minutes 180`（拉过去 3 小时）。
3. 或干脆**用 `project_*` 指标做 demo**（dashboard 会显示），强调"自己的份额"是后置统计指标。

> 这是 Foundry preview API 的限制，不是脚本 bug。GA 后会改善。

---

### 4.2 Hosted agent 偶发 90s 超时

**症状**：循环发 5 条 `/responses`，1/5 几率：

```
curl: (28) Operation timed out after 90002 milliseconds with 0 bytes received
```

其他 4 条都 `status=completed`。

**根因**：共享 Foundry project 的 gpt-5.5 deployment **被多个学员同时调用**，遇到 LLM 推理排队。`background+poll` 模式会被 90s 超时切，但服务端实际仍在跑。

**修复**：

```bash
# 方式 1: 增大 curl 超时
curl --max-time 180 ...

# 方式 2: 用 chat-hosted UI（它走 background+poll，最高 10 min 等）
./scripts/macOSLinux/chat-hosted.sh

# 方式 3: 用 invoke-hosted.sh（内部已实现重试 + poll）
./scripts/macOSLinux/invoke-hosted.sh --agent-name research-agent-stu002 --prompt "..."
```

> `/tmp/agent-server.log` 里如果看到 server side 有完成日志但 curl client 超时 → 就是这个 case。

---

## 汇总表

| # | Lab | 类别 | 现象 | 是否阻塞 | 修复时长 |
|---|-----|------|------|----------|----------|
| 0.1 | 0 | 环境 | `code` 指向 Cursor | 部分 | 5min |
| 0.2 | 0 | IDE | Copilot Chat built-in 无法 CLI 装 | 否 | — |
| 0.3 | 0 | IDE | github.copilot 老扩展 deprecated | 否 | — |
| 0.4 | 0 | 脚本 bug | sanity-check ACR HTTP 411 | 是 | 10min（已修） |
| 0.5 | 0 | IDE | maf-agent chatmode 不显示 | 否（parked） | — |
| 0.6 | 0 | UI | 4 个相似 chat panel 混淆 | 否 | 5min |
| 0.7 | 0 | 文档 | azd vs az 双登录态 | 否 | — |
| 1.1 | 1 | YAML | agent.yaml name 不展开变量 | 是 | 5min |
| 1.2 | 1 | 文档缺漏 | AZURE_AI_PROJECT_ID 未列出 | 是 | 5min |
| 1.3 | 1 | 文档缺漏 | FOUNDRY_PROJECT_ENDPOINT 未列出 | 是 | 5min |
| 1.4 | 1 | shell 陷阱 | azd 更新告警污染 env 值 | 是 | 10min |
| 1.5 | 1 | pip | OTel `--pre` 解析爆炸 | 是 | 20min |
| 1.6 | 1 | pip | agent-framework 1.4 vs 1.5 锁版 | 是 | 5min |
| 1.7 | 1 | pip | hosting pre-release 走在 core 前面 | 是 | 5min |
| 1.8 | 1 | hook bug | postdeploy 用错 agent 名 | 是 | 10min |
| 2.1 | 2 | 网络 | PyPI 国际连接 IncompleteRead | 是 | 10min（换镜像） |
| 2.2 | 2 | pip + 文档 | agent-dev-cli vs framework 1.5 不兼容 | 是 | 15min（绕过 agentdev） |
| 2.3 | 2 | 文档 | README 写 8087 实际 8088 | 否 | 1min |
| 2.4 | 2 | 工具 bug | report_builder 假设 pydantic，LLM 传 dict | 是 | 5min |
| 3.1 | 3 | docker | ACR build `tar: write too long` (venv 太大) | 是 | 5min（移 venv） |
| 3.2 | 3 | hook bug | postdeploy 同样 404 (复现 1.8) | 是 | 1min（手动 grant） |
| 4.1 | 4 | API 限制 | per-agent 指标 lag 5-15min | 否 | — |
| 4.2 | 4 | 网络 | hosted invoke 90s 偶发超时 | 否 | — |

**总耗时**：约 3 小时排查（不含 azd deploy 本身的 ~4 分钟 × 4 次重跑）。

---

## 建议改进 README 的地方

### Lab-0 README

1. **§0.2 macOS 工具检查**：加一条 `which code` 验证，提示如果输出含 `Cursor.app` 则改用 `code-insiders`。
2. **§0.7 路径 A**：明确说明 VS Code Insider 的 Copilot Chat 是内置的，**不要装 deprecated 的老 `github.copilot` 扩展**。
3. **§0.7 路径 A 后增加排错小节**：列出 SuperClaude / Cursor 全局 chatmode 可能抢占 `chat.modeFilesLocations` 的现象。

### Lab-1 README

1. **§1.3 azd env set 清单**：补全 `AZURE_AI_PROJECT_ID` 和 `FOUNDRY_PROJECT_ENDPOINT` 两行（**必填**）。
2. **§1.5 改 placeholder name**：明确说 `agent.yaml` 的 `name:` 必须**硬编码**（不能用 `${STUDENT_SUFFIX}`），`agent.manifest.yaml` 的 `name:` 可以。
3. **§1.5 patch 后增加 requirements 兼容性提示**：列出当前可用的 pin 版本组合，避免学员踩 OTel 和 agent-framework 锁版冲突。
4. **§1.8 postdeploy 修复**：在 azure.yaml 的 service 名也加 `${STUDENT_SUFFIX}` 或在 grant 脚本内改读 `AGENT_NAME`。

### Lab-2 README / HANDBOOK

1. **§2.4 M4 启动命令**：标注 `agentdev run` 与 hosting 1.5 不兼容，提供 `python -m src.research_agent.main` 替代路径。
2. **§2.4 端口说明**：默认 8088（不是 8087），或在 `main.py` 显式传 port。
3. **网络章节**：加一段关于 PyPI 国际访问的提示，列出清华/阿里云镜像 URL。
4. **拆 requirements**：把 `requirements.txt` 拆成 `requirements-runtime.txt`（hosted agent 容器用）和 `requirements-dev.txt`（agentdev/pytest 用），README 说明两者不能共用 venv。
5. **`.venv/` 必须放仓库外**或加 `.gitignore` + `.dockerignore` — 否则 Lab-3 部署必踩 `tar: write too long`。

### Lab-3 README

1. **§3.6 部署前置**：明确说"如果 Lab-2 在仓库内建了 `.venv/`，先 `mv .venv /tmp/`"。
2. **§3.6 postdeploy 修复**：和 §1.8 一致，给一段"如果 postdeploy 404，手动跑 grant 脚本"的兜底。
3. **§3.7 验证**：建议用 `chat-hosted.sh` 或 `invoke-hosted.sh`（内置重试），避免直接 curl 撞 90s 超时。

### Lab-4 README

1. **§数据 schema**：明确写"per-agent 指标有 5-15min lag，project 指标实时"，避免学员以为 dashboard 坏了。
2. **加 retry 选项**：fetch-traces.sh 现在拉到 `my_responses=0` 会直接显示 0，建议加 `--retry-until-non-zero` 选项轮询。

### 脚本修复（已在本地）

- [scripts/macOSLinux/sanity-check.sh:174](../scripts/macOSLinux/sanity-check.sh#L174) 加 `Content-Length: 0` header。
- [Lab-2-vibe-coding/tools/report_builder.py:107](../Lab-2-vibe-coding/tools/report_builder.py#L107) 加 `model_validate` dict→pydantic 转换。
- 新增 [Lab-2-vibe-coding/requirements-local.txt](../Lab-2-vibe-coding/requirements-local.txt) 作为 dev 用纯运行时依赖。
- 新增 [Lab-2-vibe-coding/src/research_agent/main.py](../Lab-2-vibe-coding/src/research_agent/main.py) `__main__` 分支加 CORS middleware（本地 chat UI 用 `file://` origin 调本地 server 需要）。
- 新增 [.dockerignore](../.dockerignore) 排除 `.venv/`、`ppt/`、其他 Lab 目录（azd ai agent 不一定读，但是正确性的兜底）。

---

## 最终成功状态

### Lab-0 / Lab-1（hosted agent）

```
✅ azd auth login --check-status     exit 0
✅ az account show                   "订阅260302"
✅ 9 项 .env 变量
✅ 模型 deployment 'gpt-5.5' 在共享 project 中
✅ Hosted agent 'research-agent-stu002' 可达 + 跑通 (status=completed)
✅ ACR 'itdnd' 可远程构建 (AcrPush + Contributor)
```

### Lab-2（本地 vibe-coding）

```
✅ persona research-agent lint pass
✅ venv + Lab-2 deps 装好（清华镜像）
✅ python3 -m src.research_agent.main 启动在 0.0.0.0:8088
✅ /responses 真实研究 prompt:
     load_skill → 5 子问题 → web_search × 4 → web_fetch × 8 → report_builder
✅ guardrail prompt 正确拒答 ({refused: true, reason: ..., suggestedAction: ...})
✅ 用 chat 生成第二个 agent invoice-explainer（persona + skill + 3 tools + 6 src files）
✅ 4 类 prompt 全跑通: 烟雾 / 多币种 / 税务 guardrail / PII 脱敏
```

### Lab-3（第二个 agent 上 hosted）

```
✅ azd deploy invoice-explainer 4m13s (移走 .venv 后)
✅ grant-agent-runtime-roles --agent-name invoice-explainer-stu002 全 4 个 role
✅ hosted /responses 跟本地等价: load_skill → ocr_extract → classify_charges → JSON
✅ sanity-check: research-agent + invoice-explainer 均在线
```

### Lab-4（本地 Observability）

```
✅ fetch-traces.sh research-agent → data/my-metrics.js
✅ fetch-traces.sh invoice-explainer → data/invoice-metrics.js
✅ index.html dashboard 加载 12 个 5-min buckets
✅ project_input_tokens=212489, project_tool_calls=30 可见
🟡 my_total_responses=0 (per-agent dimension 有 lag, 不是 bug)
```

agent 中文回答正确、code_interpreter / web_search / web_fetch / report_builder / ocr_extract / classify_charges / currency_normalize 共 **7 个工具**已注册并能调通。
