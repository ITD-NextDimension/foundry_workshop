# Wrap-up 路 鎬荤粨 + 涓嬩竴姝?10 min)

## 5.1 鎬荤粨鍙ｈ瘈

- **Soul / Skills / Tools** 鏄?agent harness 鐨?DNA(`personas/` / `skills/` / `tools/`)
- **`azd up` + `azd deploy`** 鏄儴缃茬殑鍙屾墜鏌?涓€閿垱寤?vs 澧為噺鍙戝竷)
- **`gen_ai.response.id`** 鏄?trace 涓?eval 鐨?join key,鍩嬬偣鍔″繀閫忎紶
- **GitHub Copilot** 鏄妸姒傚康鍙樹唬鐮佺殑鍔涙斁澶у櫒:**Copilot 鏄墜,浣犳槸鑴?*

## 5.2 浣犱粖澶╂惌鍑烘潵鐨勪笢瑗?

```
浣?
 鈫?
[鏈湴 agentdev 璋冭瘯鐜]
 鈫?azd deploy
[Foundry Hosted Agent: billing-agent v1]
 鈫?OTel 鑷姩鍩嬬偣
[Application Insights]
 鈫?KQL
[Static Web App 浠〃鏉縘   鈫?浣犵殑杩愮淮鍏ュ彛
```

鍔犱笂 workshop 鑷甫鐨?**Track A 瀹㈡埛鏀寔楠ㄦ灦**,浣犲凡缁忚蛋瀹屼簡浠?0 鍒?1 鐨勫畬鏁撮棴鐜€?

## 5.3 涓嬩竴姝ュ涔犺矾寰?

### Phase 3 璇勪及闂幆(杩樻病鍦?workshop 閲岃窇)

鎶?trace 杞垚璇勪及鏁版嵁闆?鈫?璺?batch eval 鈫?姣旇緝鐗堟湰 鈫?`prompt_optimize` 鈫?redeploy:

- 鍙傝€?[`agent-observability-evaluation.md`](../../agent-observability-evaluation.md):
  - 搂5 Evaluators 閫夊瀷
  - 搂6 Datasets 鍥涚被(seed / traces / curated / prod)
  - 搂7 Batch Evaluation
  - 搂9 浼樺寲寰幆

### 澶?agent 缂栨帓

鎶婁粖澶╃殑 4 涓?agent 鐪熸涓茶捣鏉?

- `workflow.yaml`(澹版槑寮?鎺ㄨ崘鍋氫富璺敱)
- `WorkflowBuilder`(浠ｇ爜寮?澶嶆潅鎺у埗娴?
- `connected_agents`(鍙仛鏋佺畝 demo)

鍙傝€?[`agent-harness-architecture.md`](../../agent-harness-architecture.md) 搂7銆倃orkshop 浠撳簱 `track-A/workflows/triage.workflow.yaml` 宸茬粡缁欎簡涓€涓捣鐐广€?

### 鑷缓 MCP server

鎶婂唴閮ㄨ兘鍔?MCP 鍖?鍦?agent.manifest.yaml 閲?`type: mcp` 寮曠敤:

- Azure Container Apps 妯℃澘:[`Azure-Samples/mcp-container-ts`](https://github.com/Azure-Samples/mcp-container-ts)
- Azure Functions 妯℃澘:[`Azure-Samples/mcp-sdk-functions-hosting-python`](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python)

鍙傝€?[`agent-harness-architecture.md`](../../agent-harness-architecture.md) 搂6銆?

### CI/CD 鎺ュ叆

`.github/workflows/agent-eval.yml`:PR 闂ㄧ璺?P0 smoke
`.github/workflows/agent-eval-scheduled.yml`:nightly trace harvest + 鍥炲綊

鍙傝€?[`agent-observability-evaluation.md`](../../agent-observability-evaluation.md) 搂11銆?

## 5.4 璧勬簮娓呯悊

> 璧勬簮 RG 浼氫繚鐣?7 澶╀緵浣犵户缁帰绱€傚交搴曞垹:

```powershell
azd down --purge --force --no-prompt
```

- 鍒犳暣涓?RG(Foundry + 妯″瀷 + ACR + App Insights + SWA 鍏ㄦ病)
- `--purge` 瑙﹀彂 Foundry account 杞垹闄ゆ竻鐞?**閬垮厤** 48h 鍐呭悓鍚嶉噸寤哄け璐?

## 5.5 鍙嶉

璇锋壂鐮?/ 鐐归摼鎺ュ～鍙嶉琛?璁插笀鐜板満鎻愪緵 URL),3 鍒嗛挓瀹屾垚銆?
浣犵殑鍚愭Ы涓庡缓璁細鐩存帴杩涗笅涓€鏈?workshop 鏀硅繘鍒楄〃銆?

## 5.6 鐩稿叧閾炬帴

- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Hosted Agents](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [`azd ai agent` 鎵╁睍](https://aka.ms/azdaiagent/docs)
- [Foundry Samples (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [GitHub Copilot in VS Code](https://code.visualstudio.com/docs/copilot/overview)

## 5.7 鑷磋阿

鏈?workshop 鐨勭礌鏉愭潵鑷笁浠藉唴閮ㄨ皟鐮?

- `azd-foundry-research.md`
- `agent-harness-architecture.md`
- `agent-observability-evaluation.md`

鎰熻阿璋冪爺浣滆€呬滑鐨勬暣鐞嗗伐浣溿€備笅涓€鏈熷啀瑙?馃憢

