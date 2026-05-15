# Cloud-based Agent Harness 鏋舵瀯:Foundry + MAF + Hosted Agent + MCP

> **鍦烘櫙**:鎶?Microsoft Foundry(妯″瀷 + 鏈嶅姟绔伐鍏?銆丠osted Agent(瀹瑰櫒杩愯鏃?涓?Microsoft Agent Framework(MAF,Python SDK)缁勮鎴愪竴濂楅潰鍚?*鍏蜂綋涓氬姟**鐨?cloud-based agent harness銆?
> **璐┛绀轰緥**:**浼佷笟瀹㈡埛鏀寔 agent harness**(TriageAgent 璺敱 鈫?TechSupportAgent / BillingAgent / KBAgent)銆?
> **閰嶅鏂囨。**:鍩虹璁炬柦閮ㄥ垎瑙?[`azd-foundry-research.md`](./azd-foundry-research.md)(azd 鏈嶅姟涓讳綋鐧诲綍 + 鍒涘缓 Foundry/Model/Hosted Agent)銆傛湰鏂囦笉閲嶅 provision 缁嗚妭,鑱氱劍**搴旂敤鏋舵瀯灞?*銆?

---

## 0. TL;DR

**涓€鍙ヨ瘽**:harness 鏄妸"**浜烘牸(personas)+ 鎶€鑳?skills)+ 宸ュ叿(tools, 涓ゅ眰)+ 缂栨帓(workflow / connected agents)+ 妯″瀷(Foundry model)+ 杩愯鏃?Hosted Agent 瀹瑰櫒)**"鎸夌害瀹氱洰褰曠粍缁囥€佹寜鐢熷懡鍛ㄦ湡鐢?`azd` + `agentdev` + Foundry MCP 涓夊 CLI 涓茶捣鏉ョ殑搴旂敤宸ョ▼妯℃澘銆?

**鍒嗗眰鏋舵瀯**:

```
鈹屸攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L4 缂栨帓灞?   workflow.yaml / WorkflowBuilder / Connected     鈹?
鈹?             Agents(璋佽皟璋併€佷粈涔堟潯浠躲€丠ITL)                  鈹?
鈹溾攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L3 搴旂敤灞?   Hosted Agent 瀹瑰櫒 = MAF Agent                   鈹?
鈹?             鈹溾攢鈹€ instructions 鈫?personas/*.md (鈽?soul)        鈹?
鈹?             鈹溾攢鈹€ context_providers=[SkillsProvider] 鈫?skills/ 鈹?
鈹?             鈹溾攢鈹€ tools=[client-side @ai_function 鈥 鈫?tools/  鈹?
鈹?             鈹斺攢鈹€ client = FoundryChatClient                   鈹?
鈹溾攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L2 妯″瀷涓庡伐鍏峰眰  Foundry server-side tools                   鈹?
鈹?                 (File Search / Code Interpreter /            鈹?
鈹?                  AI Search / Bing / Memory / 杩滅▼ MCP)        鈹?
鈹?                 + Foundry Model Deployments                  鈹?
鈹溾攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
鈹? L1 鍩虹璁炬柦灞?   Foundry account/project + ACR + MI + RBAC   鈹?
鈹?                 (鐢?azd-ai-starter-basic + azd up 鍒涘缓)       鈹?
鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?
```

**涓€鍥鹃€熸煡**:

| 姒傚康 | 鏄粈涔?| 瀛樺摢閲?| 璋佸姞杞?|
|------|--------|--------|--------|
| **persona / soul** | 瑙掕壊瀹氫箟銆佽涓鸿竟鐣屻€佸彛鍚?| `personas/<agent>.md` | `main.py` 璇绘垚瀛楃涓插缁?`Agent(instructions=...)` |
| **skill** | 瀹屾垚鏌愮被浠诲姟鐨勬寚浠や功 + 鍙€夎剼鏈?| `skills/<skill>/SKILL.md` + `skills/<skill>/scripts/` | MAF `SkillsProvider.from_paths` 鑷姩鍙戠幇 |
| **client-side tool** | 涓氬姟绯荤粺闆嗘垚鍑芥暟 | `tools/*.py`(`@ai_function`) | 鏄惧紡浣滀负 `tools=[...]` 浼犵粰 `Agent` |
| **server-side tool** | Foundry 鎻愪緵鐨勬墭绠″伐鍏?| `agent.manifest.yaml` 鎴?`agent_update` | Foundry 鍚庣;妯″瀷鑷姩鍙 |
| **MCP** | 璺ㄨ繘绋嬫爣鍑嗗伐鍏峰崗璁?| 杩滅▼ endpoint / `mcp_servers/<name>/` | `MCPTool`(娑堣垂)鎴栫嫭绔嬮儴缃?鏆撮湶) |
| **subagent** | 琚埗 agent 璋冪敤鐨勪笓绉?agent | `src/<sub>/main.py` + `src/<sub>/agent.yaml` | `workflow.yaml` 鎴?`WorkflowBuilder` 鎴?connected_agents |

---

## 1. 璋冪爺鐩爣涓庤疮绌跨ず渚?

### 1.1 鐩爣

鍥炵瓟杩欎簺闂:

1. agent 鐨?**soul**"(浜烘牸/绯荤粺鎻愮ず)鍦ㄥ摢閲屻€佹€庝箞瀛樸€佹€庝箞鐗堟湰鍖栥€佹€庝箞鍦ㄥ agent 闂村鐢?guardrails?
2. **skill** 鏄粈涔?MAF 宸茬粡鏈夊師鐢熸満鍒?璺?鑷繁鍐欎竴鍧?prompt"鏈変粈涔堝尯鍒?
3. **tool** 鍒板簳鏈夊嚑绉?Foundry 鎻愪緵鐨勬湇鍔＄ tool 鍜屾垜鑷繁 Python 鍐欑殑鍑芥暟 tool 鎬庝箞閫?
4. **MCP** 鍦?harness 閲岃兘鎵紨鍑犱釜瑙掕壊?
5. 澶氫釜 agent(涓?+ 涓撶 sub-agents)鎬庝箞缂栨帓?澹版槑寮?vs 浠ｇ爜寮?vs Foundry 鍘熺敓?
6. 涓€涓」鐩噷鎵€鏈夎繖浜?*鏂囦欢鎬庝箞缁勭粐**鎵嶄笉浼氫贡?
7. 涓€濂?**CLI 宸ュ叿鏍?* 鍦?dev / deploy / ops 涓変釜闃舵鍒嗗埆鐢ㄥ摢涓懡浠?

### 1.2 璐┛绀轰緥:浼佷笟瀹㈡埛鏀寔 agent harness

```
鐢ㄦ埛闂
   鈹?
   鈻?
[TriageAgent] 鈹€鈹€ 鍒嗙被 鈹€鈹€鈹攢鈫?[TechSupportAgent]  + KB 妫€绱?+ 宸ュ崟鍒涘缓
                       鈹溾攢鈫?[BillingAgent]      + 閫€娆鹃搴﹁绠?+ CRM 鏇存柊
                       鈹溾攢鈫?[KBAgent]           + 鏂囨。妫€绱?+ 寮曠敤
                       鈹斺攢鈫?鐩存帴绛?/ 鍏滃簳
```

鍚庢枃姣忕珷鏈熬缁欎竴娈?**璐┛绀轰緥鎬庝箞钀藉湴**"銆?

---

## 2. 鍥涘眰鏋舵瀯

### 2.1 L1 鍩虹璁炬柦灞?

鐢?[Phase 1 鏂囨。](./azd-foundry-research.md) 宸茶鐩?`azd up` 涓€閿垱寤?Foundry account + project + ACR + Managed Identity + RBAC + 妯″瀷閮ㄧ讲銆?

harness 鏈眰鍙叧蹇?*浠?* L1 鍙栦袱涓嚭鍙?

```bash
azd env get-value AZURE_AI_PROJECT_ENDPOINT      # L3 鐢?
azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME # L3 鐢?
```

### 2.2 L2 妯″瀷涓庡伐鍏峰眰

L2 = **鍙敤鐨勬ā鍨嬮儴缃?* + **Foundry 鎻愪緵鐨勬湇鍔＄ tool 涓庡搴?connection**銆傝繖涓€灞傛槸 Foundry 鎺у埗闈㈣祫婧?涓嶅湪瀹瑰櫒閲岃窇銆?

- 妯″瀷閮ㄧ讲:`AI_PROJECT_DEPLOYMENTS` 鏁扮粍(瑙?Phase 1 搂5)
- 鏈嶅姟绔?tool 娓呭崟(鍚庣画 搂5.1 璇﹁堪):File Search / Code Interpreter / Azure AI Search / Bing Grounding / Memory / Remote MCP / Function Calling(澹版槑)
- 杩欎簺 tool 鐨?**connection**(API Key / Search resource / Bing resource)鐢?Foundry MCP `project_connection_*` 绠＄悊

> 鈿狅笍 **鍏抽敭姒傚康**:L2 鐨?tool 鏄?**妯″瀷鐩存帴鍙皟鐢?*"鐨?鍦?hosted agent 閲屽彧闇€鍦?`agent.manifest.yaml` / `agent_update` 鏃跺０鏄?浣犵殑瀹瑰櫒浠ｇ爜**瀹屽叏鐪嬩笉鍒拌皟鐢ㄨ繃绋?*,Foundry 鍚庣浠ｇ悊鎵ц鍚庢妸缁撴灉濉炶繘涓婁笅鏂囥€?

### 2.3 L3 搴旂敤灞?

L3 = **涓€涓垨澶氫釜 Hosted Agent 瀹瑰櫒**,姣忎釜瀹瑰櫒璺戜竴涓?MAF `Agent` 瀹炰緥,閫氳繃 [`azure-ai-agentserver-agentframework`](https://pypi.org/project/azure-ai-agentserver-agentframework/) 閫傞厤鍣ㄦ毚闇?Responses API銆?

瀹瑰櫒鍐呬竴涓?agent 鐨?浜斾欢濂?:

```python
agent = Agent(
    client=FoundryChatClient(...),                # 妯″瀷鏉ヨ嚜 L2
    instructions=load_persona("triage-agent.md"), # 鈽?soul
    context_providers=[skills_provider],          # 鈽?skills
    tools=[crm_lookup, create_ticket],            # 鈽?client-side tools
    default_options={"store": False},
)
ResponsesHostServer(agent).run()                  # 鍚?8088 HTTP
```

server-side tool **涓嶅湪杩欓噷**鍐?鑰屾槸鍦?`agent.manifest.yaml` 閲屽０鏄庣粰 Foundry銆?

### 2.4 L4 缂栨帓灞?

L4 = **澶氫釜 L3 瀹瑰櫒涔嬮棿鎬庝箞鍗忎綔**銆備笁绉嶆柟寮忓彲閫?搂7 璇﹁堪):

| 鏂瑰紡 | 璋佹墽琛?|
|------|--------|
| `workflow.yaml`(declarative) | Foundry Workflow runtime |
| `WorkflowBuilder`(MAF Python API) | 鐖?agent 鐨勫鍣?|
| `connected_agents` 瀛楁 | Foundry 鍚庣 |

**璐┛渚嬭惤鍦?*:Phase 1 鍒涘缓浜?Foundry + `gpt-5-mini` + `text-embedding-3-small`;L2 涓婃寕涓€涓?Azure AI Search connection(KB 绱㈠紩)+ 涓€涓?Memory store;L3 閮ㄧ讲 4 涓鍣?`triage`銆乣tech-support`銆乣billing`銆乣kb`);L4 鐢?`workflow.yaml` 璁?triage 璺敱鍒颁笁涓笓绉?agent銆?

---

## 3. Agent / Subagent Soul

### 3.1 涓轰粈涔堝崟鐙娊鍑?persona

"soul" = **瑙掕壊杈圭晫 + 浠诲姟鑼冨洿 + 鍙ｅ惢 + 鎷掔粷绛栫暐 + 寮曠敤鏍煎紡**銆傚畠鏃笉鏄?濡備綍瀹屾垚鍏蜂綋浠诲姟"(閭ｆ槸 SKILL),涔熶笉鏄?鎴戞湁鍝簺宸ュ叿"(閭ｆ槸 tools)銆傛妸瀹冪嫭绔嬫垚 markdown 鏈夎繖浜涘ソ澶?

- 澶?agent 鍏变韩 guardrails(`personas/shared/guardrails.md` 鍦ㄤ富 persona 閲?`{{include}}`)
- 闈炲伐绋嬪悓浜?legal / PM)鍙互鐩存帴瀹￠槄
- 鐗堟湰鍖栨竻鏅?git diff 涓€鐪肩湅鍑鸿姘斿彉鍖?
- 璇勪及鏃?persona 鍙綔涓哄彉閲?A/B 娴嬩袱涓?persona 鐪嬪摢涓?task_adherence 楂?

### 3.2 鏂囦欢绾﹀畾

```text
personas/
  triage-agent.md
  tech-support-agent.md
  billing-agent.md
  kb-agent.md
  shared/
    guardrails.md          # 瀹夊叏/鍚堣杈圭晫(璺?agent)
    citation-format.md     # 寮曠敤绾﹀畾(璺?KB 绫?agent)
    handoff-protocol.md    # 瀛?agent 涔嬮棿鐨勪氦鎺ユ湳璇?
```

`triage-agent.md` 妯℃澘:

```markdown
---
agent: triage-agent
version: 1.0.0
owner: support-team@contoso.com
extends:
  - shared/guardrails.md
  - shared/handoff-protocol.md
---

# Role

浣犳槸 Contoso 浼佷笟瀹㈡埛鏀寔鐨勬€诲彴 agent銆備綘鐨勫敮涓€鑱岃矗鏄妸鐢ㄦ埛闂**鍒嗙被骞惰矾鐢?*缁欐渶鍚堥€傜殑涓撶 agent,涓嶈灏濊瘯鑷繁鍥炵瓟鎶€鏈垨璐﹀崟闂銆?

# Categories

1. `Technical` 鈥?浜у搧 bug / 閰嶇疆 / API
2. `Billing` 鈥?鍙戠エ / 閫€娆?/ 鐢ㄩ噺
3. `KB` 鈥?閫氱敤鐭ヨ瘑搴撳彲绛?
4. `Clarification` 鈥?闇€杩介棶

# Output

姣忔杩斿洖涓ユ牸 JSON: `{"category": "...", "reply": "...", "needsClarification": bool}`

# Tone

绠€鐭€佷笓涓氥€佷笉甯︽儏缁€?

{{include: shared/guardrails.md}}
{{include: shared/handoff-protocol.md}}
```

### 3.3 鍔犺浇鍒?`Agent(instructions=...)`

```python
# src/shared/persona.py
import re
from pathlib import Path

PERSONAS_ROOT = Path(__file__).resolve().parents[2] / "personas"

def load_persona(name: str) -> str:
    text = (PERSONAS_ROOT / name).read_text(encoding="utf-8")
    # 绠€鏄?include 鏇挎崲;鐢熶骇鍙敤 jinja2
    def _sub(m):
        return load_persona(m.group(1))
    return re.sub(r"\{\{include:\s*([^\}]+?)\s*\}\}", _sub, text)
```

```python
# src/triage_agent/main.py
agent = Agent(
    client=FoundryChatClient(...),
    instructions=load_persona("triage-agent.md"),
    ...
)
```

### 3.4 persona vs SKILL.md vs agent.yaml

| 鏂囦欢 | 鍥炵瓟鐨勯棶棰?| 璋佽 |
|------|-----------|------|
| `personas/<name>.md` | **鎴戞槸璋?** 杈圭晫銆佸彛鍚汇€佹嫆缁濈瓥鐣?| MAF Agent 鐨?`instructions` 鍙傛暟 |
| `skills/<skill>/SKILL.md` | **鎬庝箞瀹屾垚 X 浠诲姟?** 璋冪敤浠€涔堣剼鏈?/ 姝ラ | MAF `SkillsProvider` 鍦ㄩ渶瑕佹椂杞藉叆 |
| `src/<agent>/agent.yaml` | **Foundry 瑕佹€庝箞閮ㄧ讲鎴?** kind/璧勬簮/鍗忚/鐜鍙橀噺 | Foundry control plane(閮ㄧ讲鏃? |
| `src/<agent>/agent.manifest.yaml` | **鎴戣鍝簺 server-side tool 鍜屾ā鍨?** | `azd ai agent` 鎵╁睍鐢熸垚 |

### 3.5 璐┛绀轰緥

`personas/shared/guardrails.md` 鍒楀嚭"缁濅笉娉勯湶鍏朵粬瀹㈡埛鏁版嵁 / 娑夊強娉曞緥鍜ㄨ鐩存帴杞汉宸?/ 涓嶆壙璇洪€€娆鹃搴︿笂闄?銆備笁涓笓绉?agent 閮介€氳繃 `extends` 澶嶇敤,閬垮厤閲嶅缁存姢銆?

---

## 4. Skills(MAF SkillsProvider)

### 4.1 宸ヤ綔鏈哄埗

MAF `agent_framework` Python 鍖呭唴缃?[`SkillsProvider`](https://github.com/microsoft/agent-framework),瀹冩槸涓€涓?`ContextProvider`:

1. 鍚姩鏃舵壂鎻?`skill_paths` 涓嬬殑瀛愮洰褰?姣忎釜鐩綍閲屾湁涓€涓?`SKILL.md`
2. 鎶婃瘡涓?skill 鐨?*鍚嶅瓧 + 涓€琛屾弿杩?+ 鍙Е鍙戝満鏅?*娉ㄥ叆妯″瀷鐨勫彲璋冪敤宸ュ叿/涓婁笅鏂囨竻鍗?
3. 妯″瀷鍐冲畾璋冪敤鏌愪釜 skill 鏃?SkillsProvider 鍔犺浇 `SKILL.md` 鍏ㄦ枃杩涗笂涓嬫枃;濡傛灉 skill 澹版槑浜?`scripts/`,閫氳繃 `script_runner` 娌欑鎵ц

### 4.2 鐩綍绾﹀畾

```text
skills/
  refund-quote/
    SKILL.md
    scripts/
      quote.py                # 杈撳叆 amount/tier,杈撳嚭鍙€€閲戦
  kb-search/
    SKILL.md                  # 绾?prompt,鏃犺剼鏈?
  ticket-template/
    SKILL.md
    templates/
      tech-bug.md
      billing-dispute.md
```

`SKILL.md` 澶撮儴寤鸿鍔?frontmatter,渚夸簬璇勪及鏃剁瓫閫?

```markdown
---
name: refund-quote
description: 鏍规嵁瀹㈡埛 tier + 鐢ㄩ噺鍘嗗彶璁＄畻鍙€€閲戦涓婇檺
triggers:
  - 鐢ㄦ埛闂?鎴戣兘閫€澶氬皯"
  - 璐﹀崟浜夎涓旀秹鍙婇噾棰?
scripts:
  - quote.py
---

# 姝ラ

1. 鐢?CRM 宸ュ叿璇诲嚭鐢ㄦ埛 tier
2. 璋冪敤 `scripts/quote.py --tier <T> --amount <A>`
3. 鎶婅剼鏈緭鍑?JSON 涓殑 `maxRefund` 缁欑敤鎴?骞堕檮 `policyVersion`
4. 濡傛灉 `maxRefund < A`,**蹇呴』**鍏堝憡鐭ュ樊棰濇潵婧?
```

### 4.3 鍏抽敭浠ｇ爜鐗囨(鐩存帴鏉ヨ嚜 `foundry-samples` 07-skills)

```python
from agent_framework import Agent, SkillsProvider
from pathlib import Path

def run_local_skill_script(skill, script, args=None):
    # 鏍￠獙 script.path 涓嶈秺鍑?skill 鐩綍,subprocess.run 闄愭椂 60s
    ...

skills_provider = SkillsProvider.from_paths(
    skill_paths=Path(__file__).parent.parent.parent / "skills",
    script_runner=run_local_skill_script,
)

agent = Agent(
    client=FoundryChatClient(...),
    instructions=load_persona("billing-agent.md"),
    context_providers=[skills_provider],
)
```

> 娌欑瑕佺偣:`script_runner` 蹇呴』**缁濆璺緞瑙ｆ瀽 + 瓒婄晫妫€鏌?+ 瓒呮椂**;Foundry hosted agent 瀹瑰櫒鏄复鏃舵枃浠剁郴缁?鑴氭湰杈撳嚭鏂囦欢鎸?`$HOME/<subdir>/` 绾﹀畾銆?

### 4.4 Skill 涓?Tool / Persona 鐨勫彇鑸?

| 閫?Skill | 閫?Tool | 閫?Persona |
|---------|--------|-----------|
| 浠诲姟**姝ラ澶?+ 鍙枃妗ｅ寲**,妯″瀷鎸夋枃妗ｆ墽琛?| 鍗曟鍘熷瓙鎿嶄綔(鏌?CRM銆佸彂閭欢) | 瑙掕壊韬唤 / 鎷掔粷绛栫暐 / 鍙ｅ惢 |
| 鍐呭鍙兘棰戠箒鏇存柊,杩愯惀涔熻兘鏀?| API 璋冪敤绛惧悕鍥哄畾 | 涓€娆″畾涔?璺?agent 澶嶇敤 |
| 鍙兘闄勫甫妯℃澘 / 琛ㄥ崟 / 鑴氭湰 | 闇€瑕佽繑鍥炵粨鏋勫寲鏁版嵁缁欐ā鍨?| 涓嶉渶瑕?璋冪敤" |

### 4.5 璐┛绀轰緥

`refund-quote/SKILL.md` 缁?BillingAgent 鐢?`ticket-template/SKILL.md` 缁?TechSupportAgent 鐢?`kb-search/SKILL.md` 缁?KBAgent 鐢ㄣ€傛瘡涓?skill 鐙珛 git history,杩愯惀鏀规枃妗ｄ笉闇€瑕佸彂鐗堝鍣ㄣ€?

---

## 5. Tools 鍙屽眰妯″瀷

### 5.1 Foundry server-side tool(L2)

妯″瀷鐩存帴璋?**瀹瑰櫒浠ｇ爜鐪嬩笉鍒?*,鍦?`agent.manifest.yaml` 鎴?`agent_update` API 澹版槑銆?

| Tool | 鐢ㄩ€?| 鏄惁闇€瑕?Connection |
|------|------|--------------------|
| `code_interpreter` | 娌欑 Python(鏁版嵁鍒嗘瀽 / 鍑哄浘 / 鏂囦欢) | 鍚?|
| `file_search` | 鍩轰簬 vector store 鐨勬枃浠舵绱?| 鍚?浣嗛渶瑕佸厛寤?vector store) |
| `web_search_preview` | 瀹炴椂鍏綉妫€绱?| 鍚?|
| `bing_grounding` | Bing 鎼滅储 + 寮曠敤 | 鏄?Bing connection) |
| `azure_ai_search` | 绉佹湁绱㈠紩鍚戦噺/娣峰悎妫€绱?| 鏄?AI Search connection) |
| `memory_search` | 闀挎湡璁板繂(鐢ㄦ埛鍋忓ソ) | 鍚?浣嗛渶瑕?embedding 妯″瀷 + memory store) |
| `mcp` | 杩滅▼ MCP 鏈嶅姟 | 瑙嗘湇鍔¤€屽畾 |
| `function`(澹版槑寮? | 瀹㈡埛绔嚱鏁拌皟鐢?杩斿洖 schema,妯″瀷鍐冲畾璋冪敤) | 鍚?|

鍦?`agent.manifest.yaml` 涓０鏄庣ず渚?

```yaml
# src/billing_agent/agent.manifest.yaml
agent:
  name: billing-agent
  instructions: ${BILLING_INSTRUCTIONS}   # 涔熷彲鏀?persona 鏂囦欢璺緞,閮ㄧ讲鏃舵敞鍏?
  model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}
  tools:
    - type: file_search
      file_search:
        vector_store_ids:
          - ${BILLING_DOCS_VECTOR_STORE_ID}
    - type: code_interpreter
    - type: memory_search
      memory_search:
        store_id: ${SUPPORT_MEMORY_STORE_ID}
        scope: "{{$userId}}"
```

> 鈿狅笍 **鐜板疄涓殑娣峰悎**:hosted agent 瀹瑰櫒璺?MAF 鏃?**涔熷彲浠?*涓诲姩璋冪敤 Foundry 鏈嶅姟绔?tool,浣嗗彧鏄负浜嗗湪瀹瑰櫒渚ф嬁鍒板師濮嬬粨鏋滃啀鍋氬悗澶勭悊鈥斺€斿ぇ澶氭暟鍦烘櫙搴旇鎶?server-side tool 閰嶅湪 agent definition 涓?璁?Foundry 鑷姩閫忎紶鍒版ā鍨嬨€?

### 5.2 MAF client-side function tool(L3,鍦ㄤ綘鐨勫鍣ㄩ噷鎵ц)

```python
# tools/crm.py
from agent_framework import ai_function
from pydantic import BaseModel

class CrmLookupResult(BaseModel):
    tier: str
    contractEnd: str
    arr: float

@ai_function(
    name="crm_lookup",
    description="鏍规嵁 customerId 鏌ヨ CRM 涓殑鍚堝悓绛夌骇銆丄RR銆佸埌鏈熸椂闂淬€?
)
async def crm_lookup(customer_id: str) -> CrmLookupResult:
    # 鐪熷疄瀹炵幇:httpx 璋冨唴閮?API,甯?MI token
    return await _internal_crm.get(customer_id)
```

```python
# src/billing_agent/main.py
from tools.crm import crm_lookup
from tools.ticketing import create_ticket
from tools.handoff import handoff_to_tech

agent = Agent(
    client=FoundryChatClient(...),
    instructions=load_persona("billing-agent.md"),
    context_providers=[skills_provider],
    tools=[crm_lookup, create_ticket, handoff_to_tech],
)
```

### 5.3 閫夊瀷鍐崇瓥鐭╅樀

| 鍦烘櫙 | 閫?Foundry server-side | 閫?MAF client-side |
|------|----------------------|-------------------|
| 鏂囦欢 / 鏂囨。妫€绱?| 鉁?`file_search` / `azure_ai_search` | 鉂?|
| 鍏綉鎼滅储 | 鉁?`web_search_preview` / `bing_grounding` | 鉂?|
| 娌欑璺戞暟鎹垎鏋?| 鉁?`code_interpreter` | 鉂?|
| 璺ㄤ細璇濊蹇?| 鉁?`memory_search` | 鉂?鑷繁瀛? |
| 璋冨唴閮?API(CRM / 宸ュ崟) | 鉂?| 鉁?`@ai_function` |
| 淇敼涓氬姟鐘舵€?鍒涘缓宸ュ崟 / 鍙戦偖浠? | 鉂?| 鉁?渚夸簬瀹¤ + IAM) |
| 璋冪敤 subagent | 鉂?| 鉁?`handoff_to_<name>` 瀹㈡埛绔嚱鏁? |
| 宸叉槸鍏紑鏍囧噯 MCP server | 鉁?`mcp` server-side) | 鉁?涔熻兘瀹㈡埛绔? |

鍙ｈ瘈:**璇?/ 妫€绱?/ 娌欑 鈫?server-side;鍐?/ 鏀圭姸鎬?/ 涓氬姟闆嗘垚 鈫?client-side**銆?

### 5.4 璐┛绀轰緥

- BillingAgent:`file_search`(璐﹀崟鏉℃ KB,server-side) + `crm_lookup`(client-side) + `create_refund`(client-side)
- TechSupportAgent:`azure_ai_search`(浜у搧鏂囨。,server-side) + `create_ticket`(client-side)
- KBAgent:`file_search` + `web_search_preview`(閮?server-side)

---

## 6. MCP 鍏ㄩ潰鎺ュ叆

### 6.1 娑堣垂杩滅▼ MCP(鎶婂閮?MCP server 鎺ヨ繘 agent)

server-side 鍐欐硶:

```yaml
tools:
  - type: mcp
    mcp:
      server_label: github
      server_url: https://api.githubcopilot.com/mcp
      require_approval: always       # 寮哄埗姣忔瀹℃壒 鈽?
      allowed_tools: [search_issues, list_prs]
      project_connection_id: ${GITHUB_PAT_CONNECTION_ID}
```

瀹℃壒鍥炶矾:

1. Agent 瑙﹀彂 MCP tool 鈫?Foundry 杩斿洖 `mcp_approval_request` 椤?
2. 浣犵殑瀹㈡埛绔?鎴栦笓闂ㄧ殑瀹℃壒 UI)瀹?tool name + args
3. 鎻愪氦 `McpApprovalResponse(approve=True/False)` + `previous_response_id`
4. Agent 缁х画瀹屾垚

> 100s 瓒呮椂;Teams 鍙戝竷鐨?agent 涓嶆敮鎸佽韩浠界┛閫?缃戠粶闅旂 Foundry 涓嶈兘鐢ㄥ悓 VNET 鐨勭鏈?MCP銆?

### 6.2 鏆撮湶鑷繁鐨?MCP server(鎶婂唴閮ㄨ兘鍔?MCP 鍖?

Foundry **鍙帴鍙楄繙绋?* MCP endpoint,鎵€浠ユ湰鍦?stdio MCP 蹇呴』鍏堥儴缃叉垚鍏綉/VNET 鏈嶅姟銆備袱鏉′富娴佽矾寰?

| 骞冲彴 | 妯℃澘 | 閫傜敤 |
|------|------|------|
| **Azure Container Apps** | [`Azure-Samples/mcp-container-ts`](https://github.com/Azure-Samples/mcp-container-ts) | 浠绘剰璇█;鎸佺画杩愯;澶╃劧閫傚悎澶嶆潅鐘舵€?|
| **Azure Functions** | [`Azure-Samples/mcp-sdk-functions-hosting-python`](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python) | Python/Node/.NET/Java;key 璁よ瘉;鎸夎皟鐢ㄨ璐?|

harness 鐩綍閲岀殑浣嶇疆:

```
mcp_servers/
  internal-kb/                # 鎶婂唴閮?wiki 鏆撮湶鎴?MCP
    src/                      # FastMCP / TypeScript MCP
    Dockerfile                # 鎺?ACR(鍙互鍜?hosted agent 澶嶇敤)
    azure.yaml                # 涔熺敱 azd 缂栨帓閮ㄧ讲
  pricing-rules/              # 鎶婂畾浠疯鍒欏紩鎿?MCP 鍖?
    function_app/
    host.json
```

> 鍛藉悕寤鸿:`mcp_servers/<domain>-<role>/`,閮ㄧ讲鍚庣粰 agent 鐢ㄤ竴涓?`api_key` connection 寮曠敤銆?

### 6.3 鏈湴 MCP 璋冭瘯

```bash
# 鏂瑰紡 A:agentdev(AI Toolkit)
pip install agent-dev-cli --pre
agentdev run src/billing_agent/main.py --port 8087   # 璧?agent
agentdev inspect                                      # Agent Inspector UI

# 鏂瑰紡 B:鏈湴鎶婅嚜宸辩殑 MCP server 璺戞垚 stdio,璁?Claude Desktop / VS Code Copilot 鐩磋繛楠岃瘉
python mcp_servers/internal-kb/src/server.py
```

璋冭瘯鏃舵妸鐜鍙橀噺鍒囨崲鎴?`FOUNDRY_MODEL_DEPLOYMENT_NAME=...`(鎸囧悜鍚屼竴涓?Foundry 椤圭洰);MAF 鐨?`FoundryChatClient` 鐢?`DefaultAzureCredential` 璧?`az login`/`azd auth` 鐨勫紑鍙戣€呭嚟鎹€?

### 6.4 璐┛绀轰緥

- 娑堣垂:鎶?`https://api.githubcopilot.com/mcp` 鎺ヨ繘 TechSupportAgent,妯″瀷鑳芥煡鍐呴儴 issue
- 鏆撮湶:鎶?浜у搧璁㈤槄瑙勫垯寮曟搸"鏀惧湪 `mcp_servers/pricing-rules/`,閮ㄧ讲鍒?Functions,BillingAgent 閫氳繃 MCP 璋冪敤
- 璋冭瘯:鏈湴 `agentdev run` 鍚屾椂璺?BillingAgent + Pricing MCP server,Agent Inspector 鐪?trace

---

## 7. Sub-agent 缂栨帓

### 7.1 Declarative `workflow.yaml`(鎺ㄨ崘鍋氫富璺敱)

`foundry-samples` 鐨?`09-declarative-customer-support` 缁欏嚭瀹屾暣楠ㄦ灦:

```yaml
kind: Workflow
trigger:
  kind: OnConversationStart
  id: customer_support_triage
  actions:
    - kind: InvokeAzureAgent
      id: triage
      agent: { name: TriageAgent }
      output: { autoSend: false, responseObject: Local.Triage }

    - kind: ConditionGroup
      conditions:
        - condition: =Local.Triage.NeedsClarification
          actions:
            - kind: SendActivity
              activity: { text: =Local.Triage.ClarificationQuestion }
        - condition: =Local.Triage.Category = "Technical"
          actions:
            - kind: InvokeAzureAgent
              agent: { name: TechSupportAgent }
              output: { autoSend: true }
        - condition: =Local.Triage.Category = "Billing"
          actions:
            - kind: InvokeAzureAgent
              agent: { name: BillingAgent }
              output: { autoSend: true }
      elseActions:
        - kind: SendActivity
          activity: { text: =Local.Triage.Reply }
    - kind: EndWorkflow
```

浼樼偣:

- 涓氬姟鍥㈤槦鍙鍙敼,娌℃湁 Python
- Foundry runtime 鍘熺敓鏀寔 trace + 瀹℃壒 + HITL
- 鏁翠釜 workflow 鍙互**鍜?agent 涓€鏍?*琚?deploy 鍜?invoke

### 7.2 MAF `WorkflowBuilder`(浠ｇ爜寮?澶嶆潅鎺у埗娴侀閫?

```python
from agent_framework import WorkflowBuilder

w = (WorkflowBuilder()
  .add_agent("triage", triage_agent)
  .add_agent("tech", tech_agent)
  .add_agent("billing", billing_agent)
  .route("triage", lambda s: s["category"], {
      "Technical": "tech",
      "Billing": "billing",
  })
  .build())

response = await w.run(input="...")
```

鏀寔鐨勮繘闃舵ā寮?reflection銆乻witch-case銆乫an-out / fan-in銆乴oop銆乭uman-in-the-loop銆?

### 7.3 Connected Agents(Foundry 鍘熺敓瀛楁)

鍦ㄧ埗 agent 瀹氫箟閲岀洿鎺ユ寕瀛?agent 寮曠敤:

```json
{
  "kind": "prompt",
  "model": "gpt-5-mini",
  "instructions": "...",
  "connected_agents": [
    {"agent_reference": "TechSupportAgent"},
    {"agent_reference": "BillingAgent"}
  ]
}
```

鏈€鐪佷簨,浣嗚矾鐢遍€昏緫钘忓湪鐖?agent 鐨?prompt 閲?鍙瀵熸€ф渶宸€?

### 7.4 涓夎€呮€庝箞閫?

| 閫夐」 | 璺敱鍙瀵?| 涓氬姟鍙敼 | 鎺у埗娴佸鏉傚害 | trace 鍙嬪ソ |
|------|----------|----------|------------|-----------|
| `workflow.yaml` | 鉁?| 鉁?| 涓瓑(鏉′欢 + 椤哄簭) | 鉁?Foundry 鍘熺敓) |
| `WorkflowBuilder` | 閮ㄥ垎 | 鉂?浠ｇ爜) | 鉁?浠绘剰 | 闇€瑕?OpenTelemetry 鍩嬬偣 |
| `connected_agents` | 鉂?钘忓湪 prompt) | 鉂?| 浣?| 閮ㄥ垎 |

**鎺ㄨ崘缁勫悎**:**涓昏矾鐢辩敤 `workflow.yaml`**,鍐呴儴涓撶 agent 濡傛灉杩橀渶瑕?reflection / 鑷垜淇,**鍐呴儴鍐嶇敤 `WorkflowBuilder`**銆侰onnected Agents 鍙敤浜?*鏋佺畝 demo**銆?

### 7.5 璐┛绀轰緥

- `workflows/triage.workflow.yaml`:Triage 璺敱
- TechSupportAgent **鍐呴儴**鐢?`WorkflowBuilder` 鍋?鍏?RAG 鈫?妫€鏌ョ疆淇″害 鈫?涓嶅鍒欒拷闂?鐨?reflection loop
- 鏁翠釜椤圭洰閲屾病鏈?`connected_agents`(閬垮厤 prompt 榛戠洅)

---

## 8. 鐩綍涓庢枃浠剁害瀹?

```text
support-agent-harness/
鈹溾攢鈹€ azure.yaml                            # azd 鍏ュ彛
鈹溾攢鈹€ infra/                                 # bicep(starter 妯℃澘)
鈹溾攢鈹€ .azure/<env>/.env                      # azd 鐜鍙橀噺
鈹溾攢鈹€ .foundry/
鈹?  鈹溾攢鈹€ agent-metadata.yaml                # project endpoint / agent 鍚?/ testCases
鈹?  鈹溾攢鈹€ datasets/                          # 璇勪及鏁版嵁闆嗘湰鍦扮紦瀛?
鈹?  鈹溾攢鈹€ evaluators/                        # 璇勪及鍣ㄥ畾涔?
鈹?  鈹斺攢鈹€ results/                           # 璇勪及缁撴灉
鈹溾攢鈹€ personas/                              # 鈽?L3: soul
鈹?  鈹溾攢鈹€ triage-agent.md
鈹?  鈹溾攢鈹€ tech-support-agent.md
鈹?  鈹溾攢鈹€ billing-agent.md
鈹?  鈹溾攢鈹€ kb-agent.md
鈹?  鈹斺攢鈹€ shared/
鈹?      鈹溾攢鈹€ guardrails.md
鈹?      鈹溾攢鈹€ citation-format.md
鈹?      鈹斺攢鈹€ handoff-protocol.md
鈹溾攢鈹€ skills/                                # 鈽?L3: MAF SkillsProvider
鈹?  鈹溾攢鈹€ refund-quote/
鈹?  鈹?  鈹溾攢鈹€ SKILL.md
鈹?  鈹?  鈹斺攢鈹€ scripts/quote.py
鈹?  鈹溾攢鈹€ ticket-template/
鈹?  鈹?  鈹溾攢鈹€ SKILL.md
鈹?  鈹?  鈹斺攢鈹€ templates/{tech-bug,billing-dispute}.md
鈹?  鈹斺攢鈹€ kb-search/SKILL.md
鈹溾攢鈹€ tools/                                 # 鈽?L3: MAF client-side tools
鈹?  鈹溾攢鈹€ crm.py                             # @ai_function: 鏌?CRM
鈹?  鈹溾攢鈹€ ticketing.py                       # @ai_function: 鍒涘缓/鏇存柊宸ュ崟
鈹?  鈹溾攢鈹€ handoff.py                         # @ai_function: 璋冪敤 subagent
鈹?  鈹斺攢鈹€ _shared/auth.py                    # MI / DefaultAzureCredential 宸ュ巶
鈹溾攢鈹€ mcp_servers/                           # 鈽?L2 鎵╁睍: 鑷毚闇?MCP
鈹?  鈹溾攢鈹€ pricing-rules/                     # Azure Functions 閮ㄧ讲
鈹?  鈹?  鈹溾攢鈹€ function_app.py
鈹?  鈹?  鈹溾攢鈹€ host.json
鈹?  鈹?  鈹斺攢鈹€ requirements.txt
鈹?  鈹斺攢鈹€ internal-kb/                       # Azure Container Apps 閮ㄧ讲
鈹?      鈹溾攢鈹€ src/server.py                  # FastMCP
鈹?      鈹溾攢鈹€ Dockerfile
鈹?      鈹斺攢鈹€ azure.yaml
鈹溾攢鈹€ workflows/                             # 鈽?L4: declarative
鈹?  鈹斺攢鈹€ triage.workflow.yaml
鈹溾攢鈹€ src/                                   # 鈽?L3: 涓€涓?agent 涓€涓瓙鐩綍
鈹?  鈹溾攢鈹€ triage_agent/
鈹?  鈹?  鈹溾攢鈹€ main.py                        # 瑁呴厤 SkillsProvider + tools + persona
鈹?  鈹?  鈹溾攢鈹€ agent.yaml                     # Foundry hosted agent 瀹氫箟
鈹?  鈹?  鈹溾攢鈹€ agent.manifest.yaml            # 妯″瀷 + server-side tools
鈹?  鈹?  鈹溾攢鈹€ Dockerfile
鈹?  鈹?  鈹溾攢鈹€ requirements.txt
鈹?  鈹?  鈹斺攢鈹€ .env.example
鈹?  鈹溾攢鈹€ tech_support_agent/
鈹?  鈹溾攢鈹€ billing_agent/
鈹?  鈹溾攢鈹€ kb_agent/
鈹?  鈹斺攢鈹€ shared/                            # 璺?agent 澶嶇敤
鈹?      鈹溾攢鈹€ persona.py                     # load_persona() with include
鈹?      鈹溾攢鈹€ client_factory.py              # FoundryChatClient + 鍑嵁
鈹?      鈹斺攢鈹€ skill_runner.py                # 娌欑 script_runner
鈹溾攢鈹€ tests/
鈹?  鈹溾攢鈹€ unit/                              # tools / skill_runner 鍗曟祴
鈹?  鈹斺攢鈹€ eval/                              # Foundry 璇勪及鍦烘櫙
鈹斺攢鈹€ README.md
```

### 8.1 姣忎釜鏂囦欢绫诲瀷鐨?鍞竴鑱岃矗"

| 鏂囦欢 | 鍞竴鑱岃矗 | 璋佽礋璐?|
|------|---------|--------|
| `personas/*.md` | 瑙掕壊 + 杈圭晫 + 鍙ｅ惢 | PM + Legal |
| `skills/*/SKILL.md` | 鍏蜂綋浠诲姟鐨勬楠よ鏄?| 涓氬姟杩愯惀 + 鐮斿彂 |
| `skills/*/scripts/*.py` | 纭畾鎬х畻娉?/ 妯℃澘鐢熸垚 | 鐮斿彂 |
| `tools/*.py` | 涓氬姟绯荤粺 API 闆嗘垚 | 鐮斿彂 |
| `workflows/*.workflow.yaml` | 澶?agent 璺敱 | PM + 鐮斿彂 |
| `src/<agent>/main.py` | 缁勮 Agent + 鍚姩 HTTP server | 鐮斿彂 |
| `src/<agent>/agent.yaml` | Foundry 閮ㄧ讲鍏冩暟鎹?kind/璧勬簮/鍗忚) | 鐮斿彂 |
| `src/<agent>/agent.manifest.yaml` | 妯″瀷 + server-side tools 澹版槑 | 鐮斿彂 |
| `mcp_servers/*/` | 鑷毚闇?MCP 鏈嶅姟瀹炵幇 | 骞冲彴鐮斿彂 |
| `.foundry/agent-metadata.yaml` | 鐜 + agent 鍚?+ 璇勪及閰嶇疆 | 鐮斿彂 |
| `azure.yaml` / `infra/` | 鍩虹璁炬柦(Phase 1 鏂囨。) | DevOps |

### 8.2 鍛藉悕瑙勭害

- agent 鍚?/ 闀滃儚鍚?灏忓啓杩炲瓧绗?渚?`tech-support-agent`(MAF agent 鍚嶈姹?alphanumeric + `-`,棣栧熬 alphanumeric,鈮?3 瀛楃)
- skill 鐩綍鍚?鍔ㄨ瘝-鍚嶈瘝,渚?`refund-quote`銆乣ticket-template`銆乣kb-search`
- persona 鏂囦欢鍚?= agent 鍚?+ `.md`
- workflow 鏂囦欢鍚?`<scenario>.workflow.yaml`

### 8.3 鍏变韩浠ｇ爜鏀惧摢

- **璺?agent Python**:`src/shared/`(琚?`src/<agent>/main.py` 閫氳繃 `..shared` 瀵煎叆)
- **璺?agent prompt**:`personas/shared/`
- **璺?agent skill**:鐩存帴鏀惧湪 `skills/<name>/`,鐢辨瘡涓?agent 鐨?SkillsProvider 鐙珛鍔犺浇

---

## 9. CLI 宸ュ叿鏍堜笌鐢熷懡鍛ㄦ湡瀵圭収琛?

| 闃舵 | CLI / Tool | 鍛戒护 | 骞蹭粈涔?|
|------|-----------|------|--------|
| **provision** | `az` | `az login --service-principal ...` | 鎺у埗闈㈢櫥褰?|
| **provision** | `azd` | `azd auth login --client-id ...` | Developer CLI 鐧诲綍 |
| **provision** | `azd` | `azd init -t Azure-Samples/azd-ai-starter-basic` | 鎷夋ā鏉?|
| **provision** | `azd` | `azd up` | 涓€閿?provision + 閮ㄧ讲 |
| **dev** | `agentdev` | `agentdev run src/<agent>/main.py --port 8087` | 鏈湴璧?agent HTTP |
| **dev** | `agentdev` | AI Toolkit 涓?`ai-mlstudio.openTestTool` | 鎵撳紑 Agent Inspector UI |
| **dev** | `debugpy` | `debugpy --listen 127.0.0.1:5679` | 鏂偣璋冭瘯 |
| **dev** | `pytest` | `pytest tests/unit` | client-side tool / skill_runner 鍗曟祴 |
| **deploy** | `azd` | `azd ai agent init -m src/<agent>/agent.yaml` | 鎶?agent 娉ㄥ唽杩?azure.yaml |
| **deploy** | `azd` | `azd deploy <service-name>` | 鍗曠嫭閲嶅彂鏌愪釜 agent 瀹瑰櫒 |
| **deploy** | Foundry MCP | `agent_definition_schema_get` | 鍙栨渶鏂?schema 楠岃瘉 |
| **deploy** | Foundry MCP | `agent_update` | 鍒涘缓/鏇存柊 agent(鏀寔 cloneRequest) |
| **deploy** | Foundry MCP | `agent_container_control` | 鍚仠 hosted agent 瀹瑰櫒 |
| **deploy** | Foundry MCP | `agent_container_status_get` | 杞 Running/Failed |
| **deploy** | Foundry MCP | `project_connection_create` | 寤?MCP / Search / Bing 杩炴帴 |
| **invoke** | curl / SDK | `POST <endpoint>/agents/<name>/responses` | 璋?agent |
| **invoke** | Foundry MCP | `agent_invoke` | MCP 宸ュ叿鐩村彂 |
| **observe** | Foundry MCP | `evaluation_run_create` + `evaluator_catalog_get` | 璺戣瘎浼?|
| **observe** | Foundry MCP | `trace_search` | 鏌?App Insights customEvents |
| **observe** | Foundry MCP | `prompt_optimize` | 鍩轰簬璇勪及浼樺寲 instructions/persona |
| **ops** | `azd` | `azd down --purge --force` | 鎷?RG(鎱庣敤) |

---

## 10. 绔埌绔紑鍙戞祦绋?

### 10.1 First-Time Setup

```
1. (Phase 1) azd auth login + azd init -t azd-ai-starter-basic
2. 鍦?src/ 涓?azd ai agent init -m <agent.yaml>(姣忎釜 agent 涓€娆?
3. 鎶?personas/ skills/ tools/ workflows/ 鐩綍寤哄ソ
4. azd up 鈫?鍏ㄩ儴 agent 閮ㄧ讲涓婂幓 + 鍒涘缓 Foundry 璧勬簮
5. agent-metadata.yaml 鎸佷箙鍖?project endpoint / agent names
```

### 10.2 鏃ュ父杩唬

```
鏈湴寰幆:
   淇敼 persona / skill / tool
   鈫?
   agentdev run src/<agent>/main.py --port 8087
   鈫?
   Agent Inspector 楠岃瘉
   鈫?
   pytest tests/unit

浜戜笂:
   azd deploy <agent-service-name>     # 鍙噸鍙戞敼鍔ㄧ殑瀹瑰櫒
   鈫?
   agent_container_status_get 绛?Running
   鈫?
   evaluation_run_create 璺?P0 smoke
   鈫?
   trace_search 鐪嬫柊鐗堟湰澶辫触 case
```

### 10.3 澧炲姞涓€涓柊涓撶 sub-agent

```
1. 鏂板 personas/<new>-agent.md
2. 鏂板 src/<new>_agent/(main.py + agent.yaml + agent.manifest.yaml + Dockerfile)
3. 鍦?workflows/triage.workflow.yaml 鍔犱竴鏉?ConditionGroup 鍒嗘敮
4. 濡傛湁涓撳睘 skill,鏂板 skills/<new>-skill/SKILL.md
5. azd deploy <new>-agent + azd deploy triage(workflow 鏇存柊)
6. 璇勪及:eval-datasets 鍔犺涓撶鐨勬祴璇曠敤渚?
```

### 10.4 澧炲姞涓€涓柊宸ュ叿

```
鍐崇瓥鏍?
  绾绱?/ 鍏綉 / 娌欑        鈫?鍔犲埌 agent.manifest.yaml(server-side)
  璋冨唴閮?API / 鍐欑姸鎬?         鈫?tools/*.py 鍔?@ai_function,鏀?src/<agent>/main.py
  璺ㄥ涓?agent / 鎯虫爣鍑嗗崗璁?   鈫?mcp_servers/<name>/ 瀹炵幇 + 閮ㄧ讲 + project_connection_create
```

---

## 11. 鍏抽敭椋庨櫓涓庢渶浣冲疄璺?

| 椋庨櫓 | 缂撹В |
|------|------|
| **Persona 婕傜Щ**:澶?agent 鍚勮嚜缁存姢 guardrails 涓嶄竴鑷?| `personas/shared/guardrails.md` 寮哄埗 include;璇勪及閲屽姞 indirect_attack / safety 璇勪及鍣?|
| **Skill 瓒婃潈鎵ц**:script_runner 琚?prompt-injection 鎿嶆帶 | 缁濆璺緞瑙ｆ瀽 + 鐩綍杈圭晫妫€鏌?+ 鐧藉悕鍗?cmd + 瓒呮椂(鍙傝€?07-skills 瀹炵幇) |
| **Tool 婊ョ敤**:client-side tool 淇敼涓氬姟鐘舵€佹病鏈夊璁?| 姣忎釜 `@ai_function` 鍐呴儴璁?OpenTelemetry span;鏁忔劅鎿嶄綔璧?MCP `require_approval=always` |
| **MCP 100s 瓒呮椂** | 鏈嶅姟绔仛寮傛 + 鐘舵€佺爜 + 鐭疆璇?鎴栨媶鍒?tool |
| **Sub-agent 璺敱涓嶅彲瑙?* | 鐢?`workflow.yaml` 鏇夸唬 `connected_agents`;涓昏矾鐢?trace 蹇呴』鍖呭惈 categoryDecision |
| **鐜鑰﹀悎**:dev 鍐欐 endpoint | 鍏ㄨ蛋 `.azure/<env>/.env` + `agent-metadata.yaml` 鐨?`environments.<env>.*` |
| **Persona / Skill 娌℃湁鐗堟湰** | frontmatter 鍔?`version`;姣忔鍙戝竷鍦?`agent-metadata.yaml` 璁?personaVersion |
| **鍐峰惎鍔ㄦ參** | `agent.yaml` 璁?`minReplicas: 1`(鎴愭湰鍙帶鍓嶆彁) |
| **Hosted agent 闀滃儚蹇呴』 linux/amd64** | Dockerfile 璁?`--platform linux/amd64`,鎴?`docker.remoteBuild: true` 璧?ACR Tasks |
| **鏈嶅姟涓讳綋缂?User Access Administrator** | 鍙傝€?Phase 1 鏂囨。 搂2.2 RBAC 鐭╅樀 |

---

## 12. 鍙傝€冮摼鎺?

### 鏂囨。
- [Microsoft Agent Framework 姒傝堪](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Agent Framework Quick Start](https://learn.microsoft.com/agent-framework/tutorials/quick-start)
- [Microsoft Agent Framework User Guide](https://learn.microsoft.com/agent-framework/user-guide/overview)
- [Foundry Hosted Agents 姒傚康](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [Foundry Agent Runtime Components](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/runtime-components)
- [Foundry Agent Tool Catalog](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/tool-catalog)
- [Foundry MCP Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/model-context-protocol)
- [Foundry File Search Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/file-search)
- [Foundry Azure AI Search Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/azure-ai-search)
- [Foundry Code Interpreter Tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/code-interpreter)
- [Foundry Function Calling](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/function-calling)
- [Foundry Memory](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/what-is-memory)
- [`azd ai agent` extension](https://aka.ms/azdaiagent/docs)

### 浠撳簱涓庢牱渚?
- [Microsoft Agent Framework (GitHub)](https://github.com/microsoft/agent-framework)
- [Foundry Samples 鈥?Hosted Agents (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [Foundry Samples 鈥?`07-skills`(SkillsProvider 绀轰緥)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/07-skills)
- [Foundry Samples 鈥?`09-declarative-customer-support`(workflow.yaml 绀轰緥)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/09-declarative-customer-support)
- [Foundry Samples 鈥?`05-workflows`(WorkflowBuilder 绀轰緥)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents/agent-framework/responses/05-workflows)
- [MCP server on Azure Container Apps (TS 妯℃澘)](https://github.com/Azure-Samples/mcp-container-ts)
- [MCP server on Azure Functions (Python 妯℃澘)](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python)
- [`azd-ai-starter-basic` 妯℃澘](https://github.com/Azure-Samples/azd-ai-starter-basic)

### 閰嶅鏂囨。
- [`azd-foundry-research.md`](./azd-foundry-research.md) 鈥?Phase 1:azd 鏈嶅姟涓讳綋鐧诲綍 + 鍒涘缓 Foundry/Model/Hosted Agent

