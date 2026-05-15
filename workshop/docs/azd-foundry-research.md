# 浣跨敤 azd 鏈嶅姟涓讳綋鐧诲綍鍒涘缓 Foundry / Model / Hosted Agent 璋冪爺

> 鍦烘櫙:鍦?CI/CD 鎴栬嚜鍔ㄥ寲鐜涓?閫氳繃 Azure Developer CLI(`azd`)浠ユ湇鍔′富浣?Service Principal)闈炰氦浜掔櫥褰?鐒跺悗绔埌绔畬鎴?**Microsoft Foundry 璧勬簮 鈫?妯″瀷閮ㄧ讲 鈫?Hosted Agent 鍙戝竷**銆?
>
> 鏈皟鐮旇仛鐒﹀畼鏂规帹鑽愮殑涓€浣撳寲璺緞:`Azure-Samples/azd-ai-starter-basic` 妯℃澘 + `azd ai agent` 鎵╁睍 + `azd up`銆傛墍鏈夊懡浠ゅ潎涓虹ず渚?**鏈湪 Azure 涓婂疄闄呮墽琛?*銆?

---

## 0. TL;DR 鈥?涓€鍥炬祦鍛戒护娓呭崟

```bash
# 0. 涓€娆℃€у噯澶?
azd extension install azure.ai.agents
az login --service-principal -u <appId> -p "<secret>" --tenant <tid>
az account set --subscription <subId>

# 1. azd 鏈嶅姟涓讳綋鐧诲綍
azd auth login --client-id <appId> --client-secret "<secret>" --tenant-id <tid>
azd config set defaults.subscription <subId>
azd config set defaults.location northcentralus

# 2. 鍒涘缓椤圭洰鐩綍 + 鎷夊彇 Foundry starter 妯℃澘
mkdir my-foundry-app && cd my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt

# 3. (鍙€? 浠呭０鏄?Foundry 鍩虹璁炬柦
azd env set ENABLE_HOSTED_AGENTS true

# 4. 娉ㄥ叆涓€涓?Hosted Agent 瀹氫箟(鑷姩浼氬啓鍏ユā鍨嬮儴缃?+ ENABLE_HOSTED_AGENTS)
azd ai agent init -m https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml

# 5. 涓€閿?provision + 妯″瀷閮ㄧ讲 + 瀹瑰櫒鏋勫缓鎺ㄩ€?+ 鍙戝竷 Agent
azd up --no-prompt

# 6. 鏌ョ湅閮ㄧ讲浜х墿
azd env get-values
```

瀹屾暣璇存槑瑙佸悗鏂囧悇鑺傘€?

---

## 1. 鑳屾櫙涓庣洰鏍?

- **鏈嶅姟涓讳綋鐧诲綍**鏄?CI/CD 涓庤嚜鍔ㄥ寲鍦烘櫙涓?`azd` 鐨勬爣鍑嗚璇佹柟寮?鐢ㄦ埛缁欏嚭鐨勫懡浠ゆ牸寮忎笌瀹樻柟涓€鑷?
  ```bash
  azd auth login --client-id <appId> --client-secret "<secret>" --tenant-id <tid>
  ```
- 鐩爣:鍦ㄨ璁よ瘉鎬佷笅,**涓嶄氦浜?*鍦板畬鎴?
  1. Microsoft Foundry 璐﹀彿 + 椤圭洰鐨勮祫婧愬垱寤?
  2. 涓€涓垨澶氫釜妯″瀷閮ㄧ讲(渚嬪 `gpt-5-mini`)
  3. 涓€涓?Hosted Agent(瀹瑰櫒闀滃儚 鈫?ACR 鈫?Foundry Agent Application)
- 鑼冨洿澶?`az cognitiveservices account create` 绛夋洿缁嗙矑搴︾殑闈?azd 璺緞;Foundry MCP `agent_update` 鐩存帴璋冪敤銆?

---

## 2. 鍓嶇疆鏉′欢

### 2.1 宸ュ叿鐗堟湰

| 宸ュ叿 | 鏈€浣庣増鏈?| 瀹夎鍛戒护(Windows / Linux / macOS) |
|------|----------|-----------------------------------|
| Azure Developer CLI(`azd`) | **1.21.3+**(`azd ai agent` 鎵╁睍瑕佹眰) | `winget install microsoft.azd` / `curl -fsSL https://aka.ms/install-azd.sh \| bash` / `brew tap azure/azd && brew install azd` |
| Azure CLI(`az`) | 2.55+ | 鍙傝€?https://aka.ms/installazurecli |
| `azd ai agent` 鎵╁睍 | latest | `azd extension install azure.ai.agents`(`azd ai agent init` 棣栨杩愯涔熶細鑷姩瀹夎) |
| Docker(鍙€? | 浠绘剰 | 浠呭湪 `docker.remoteBuild: false` 鏃堕渶瑕?鎺ㄨ崘鍚敤浜戞瀯寤轰互鐪佺暐鏈湴 Docker |

### 2.2 鏈嶅姟涓讳綋 RBAC(鏈€灏忚鑹茬煩闃?

`azd up` 鍦?starter 涓婁細鍒涘缓澶氫釜璧勬簮 **骞剁粰鏂板缓鐨?managed identity 鍒嗛厤 RBAC 瑙掕壊**,鎵€浠ユ湇鍔′富浣撴湰韬繀椤绘嫢鏈夌粰鍒汉鍒嗚鑹茬殑鏉冮檺銆傛渶灏忛泦鍚?

| 瑙掕壊 | 浣滅敤鍩?| 蹇呴渶 | 璇存槑 |
|------|--------|------|------|
| **Contributor** | 璁㈤槄 鎴?鐩爣 RG | 鉁?| 鍒涘缓 Foundry account / project / ACR / App Insights / Log Analytics 绛夋墍鏈夋暟鎹潰澶栬祫婧?|
| **User Access Administrator**(鎴?`Role Based Access Control Administrator`) | 璁㈤槄 鎴?鐩爣 RG | 鉁?| 缁?Foundry 椤圭洰鐨?managed identity 鍒嗛厤 `AcrPull` / `Cognitive Services OpenAI User` 绛夎鑹?鍚﹀垯 bicep 浼氬湪 role assignment 姝ラ绾㈢潃鑴搁€€鍑?|
| **Cognitive Services Contributor** | RG | 鎺ㄨ崘 | 閮ㄥ垎璁㈤槄绛栫暐闄愬埗涓?妯″瀷 `accounts/deployments` 鍒涘缓闇€瑕佹瑙掕壊 |
| **Azure AI Account Owner**(鍙€? | RG | 鍙€?| 缁欏埌 SP 鍚庡彲鐩存帴绠＄悊 Foundry account 鍐呯殑椤圭洰/Agent |

> **閲嶈**:`Owner` 瑙掕壊铏界劧鑳?cover 鍏ㄩ儴闇€姹?浣嗛€氬父琚粍缁囩瓥鐣ョ鐢ㄣ€備紭鍏堜娇鐢?`Contributor + User Access Administrator` 涓や欢濂椼€?

### 2.3 鍖哄煙涓庨厤棰?

- **Hosted Agents 棰勮**寮哄埗 `northcentralus`(浠?[Region support](https://learn.microsoft.com/en-us/azure/ai-foundry/reference/region-support) 涓?[Agent model region support](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/model-region-support?tabs=global-standard) 涓哄噯)銆?
- 妯″瀷閮ㄧ讲鍙楅厤棰濋檺鍒?閮ㄧ讲鍓嶇‘璁ょ洰鏍囨ā鍨?濡?`gpt-5-mini`)鍦ㄧ洰鏍囧尯鍩熸湁 TPM 浣欓噺(鍙敤 Foundry 闂ㄦ埛 鈫?Management center 鈫?Quotas 鏌ョ湅)銆?

---

## 3. 绗竴姝?鏈嶅姟涓讳綋鐧诲綍

### 3.1 `azd auth login` 鍛戒护瑙ｆ瀽

瀹樻柟鏀寔鐨勬湇鍔′富浣撶櫥褰?鍙傝€?[azd auth login reference](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-auth-login)):

```bash
azd auth login \
  --client-id <appId> \
  --client-secret "<secret>" \
  --tenant-id <tid>
```

鍙浛鎹㈢殑鍑嵁褰㈠紡(涓夐€変竴):

| 鍙傛暟 | 閫傜敤鍦烘櫙 |
|------|----------|
| `--client-secret "<secret>"` | 鍏变韩 secret;鏈€甯歌,閫傚悎鏈哄櫒浜鸿处鎴?|
| `--client-certificate <path-to-pfx>` | 璇佷功鍑嵁;鏇村畨鍏?閫傚悎闀挎湡 SP |
| `--federated-credential-provider github\|azure-pipelines\|oidc` | OIDC 鑱斿悎韬唤;GitHub Actions / Azure Pipelines / 閫氱敤 OIDC 閮芥敮鎸?|

> **PowerShell 鎻愮ず**:secret 涓惈 `$`銆乣!`銆佺┖鏍?绛夌壒娈婂瓧绗︽椂鍔″繀鐢?*鍙屽紩鍙?*鍖呰９(鐢ㄦ埛缁欏嚭鐨勫懡浠ゅ凡姝ｇ‘鍔犱笂寮曞彿)銆?

### 3.2 鍚屾鐧诲綍 `az`(涓轰粈涔堥渶瑕?

`azd` 鍜?`az` 缁存姢**涓ゅ鐙珛**鐨勭櫥褰曟€併€俙azd-ai-starter-basic` 涓殑閮ㄥ垎 pre/post-provision hook 涓?`azd ai agent` 鎵╁睍鍐呴儴閮戒細璋冪敤 `az`,鍥犳鏈嶅姟涓讳綋鍦烘櫙涓嬪缓璁袱杈归兘鐧诲綍:

```bash
az login --service-principal \
  --username <appId> \
  --password "<secret>" \
  --tenant <tid>

az account set --subscription <subId>
```

### 3.3 璁剧疆榛樿璁㈤槄/鍖哄煙

```bash
# 璁?azd 鍚庣画鍛戒护榛樿璧拌繖涓闃呬笌鍖哄煙,閬垮厤姣忔鎻愮ず
azd config set defaults.subscription <subId>
azd config set defaults.location northcentralus
```

杩欎袱涓€间細鍐欏叆鐢ㄦ埛绾?`~/.azd/config.json`銆傚湪澶氳闃?SP 涓婁篃鍙互鏀圭敤 `azd env set AZURE_SUBSCRIPTION_ID <subId>` 鍐欏埌鐜绾с€?

### 3.4 鐧诲綍鎬佹牎楠?

```bash
# azd
azd auth login --check-status      # 閫€鍑虹爜 0 鍗冲凡鐧诲綍
azd auth status                     # 杈撳嚭璐﹀彿淇℃伅

# az
az account show --query "{Name:name, SubscriptionId:id, Tenant:tenantId}" -o table
```

---

## 4. 绗簩姝?鍒涘缓 Foundry(`azd-ai-starter-basic`)

> 杩欎竴姝?*涓嶄細绔嬪埢鍦?Azure 涓婂垱寤轰换浣曡祫婧?*,鍙槸鎶?IaC + 閰嶇疆鎷夊埌鏈湴銆傜湡姝ｇ殑 provision 鍦ㄧ 6 鑺?`azd up` 鏃舵墽琛屻€?

### 4.1 鎷夊彇妯℃澘

```bash
mkdir my-foundry-app
cd my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt
```

- `-t Azure-Samples/azd-ai-starter-basic` 鈥?Microsoft Foundry 瀹樻柟 azd bicep starter銆?
- `-e dev` 鈥?azd 鐜鍚?涔熺敤浣?RG 鍛藉悕 `rg-dev`)銆?
- `--no-prompt` 鈥?闈炰氦浜掓ā寮?浣跨敤榛樿鍊?CI/CD 蹇呴』鍔犮€?
- 蹇呴』鍦?*绌虹洰褰?*鎵ц銆?

鎵ц鍚庣洰褰曠粨鏋?

```
my-foundry-app/
鈹溾攢鈹€ .azure/dev/.env       # azd 鐜鍙橀噺(鍙敤 azd env set 淇敼)
鈹溾攢鈹€ infra/                # bicep 鏂囦欢(main.bicep + modules)
鈹溾攢鈹€ src/                  # Agent 浠ｇ爜(鍒濆涓虹┖)
鈹斺攢鈹€ azure.yaml            # 椤圭洰閰嶇疆鍏ュ彛
```

### 4.2 `azure.yaml` 缁撴瀯璇存槑

starter 鐨?`azure.yaml` 褰㈠:

```yaml
requiredVersions:
  extensions:
    azure.ai.agents: latest
services: {}      # 绗?6 鑺備細琚?azd ai agent init 濉厖
infra:
  provider: bicep
  path: ./infra
  module: main
```

鍏抽敭鐐?
- `requiredVersions.extensions.azure.ai.agents` 鈥?澹版槑椤圭洰渚濊禆 `azd ai agent` 鎵╁睍銆?
- `services` 鈥?姣忎釜 hosted agent 涓€涓潯鐩?鐢?`azd ai agent init` 鑷姩鐢熸垚,瑙?搂6.2)銆?
- `infra` 鈥?bicep 鍏ュ彛妯″潡銆傛ā鏉跨殑 bicep 浼氳鍙栧悗杩扮幆澧冨彉閲忔潵鍐冲畾瑕佷笉瑕佸缓 ACR銆佽涓嶈寤烘ā鍨嬮儴缃层€?

### 4.3 鍏抽敭鐜鍙橀噺

starter 閫氳繃 `.azure/<env>/.env` 涓殑鐜鍙橀噺椹卞姩 bicep 琛屼负銆傚彲浠ョ敤 `azd env set <KEY> <VALUE>` 鍐欏叆:

| 鍙橀噺 | 绫诲瀷 | 榛樿 | 浣滅敤 |
|------|------|------|------|
| `ENABLE_HOSTED_AGENTS` | bool | `false` | 璁句负 `true` 鏃?bicep 棰濆鍒涘缓 **Azure Container Registry** 涓?**capability host(`capabilityHosts/agents`)**,杩欐槸 hosted agent 鐨勫繀瑕佸墠鎻?|
| `ENABLE_MONITORING` | bool | `true` | 鍒涘缓 Application Insights + Log Analytics |
| `AI_PROJECT_DEPLOYMENTS` | JSON 鏁扮粍 | `[]` | 瑕佸湪 Foundry account 涓婂垱寤虹殑妯″瀷閮ㄧ讲鍒楄〃,瑙?搂5.1 |
| `AI_PROJECT_CONNECTIONS` | JSON 鏁扮粍 | `[]` | 瑕佸湪 Foundry project 涓婂垱寤虹殑杩炴帴(Search / Bing / Storage 绛? |
| `AI_PROJECT_DEPENDENT_RESOURCES` | JSON 鏁扮粍 | `[]` | 鍚屾椂鍒涘缓鐨勪緷璧栬祫婧?濡?Azure AI Search銆丅ing Grounding |

> **灏忚创澹?*:杩欎簺鍙橀噺鍦?`azd ai agent init` 鏃堕€氬父浼氳鎵╁睍**鑷姩濉厖**;鎵嬪伐绠＄悊鍙湪娌℃湁 agent 瀹氫箟銆佸崟鐙窇 Foundry 鏃堕渶瑕併€?

### 4.4 浠?provision Foundry(涓嶉儴缃?Agent)鐨勫啓娉?

濡傛灉鏆傛椂涓嶆兂閮ㄧ讲浠讳綍 agent,鍙兂鎶?Foundry 璧勬簮寤哄嚭鏉?

```bash
azd env set ENABLE_HOSTED_AGENTS false   # 鍏堜笉瑕?ACR/capability host(鍙€?
azd env set AI_PROJECT_DEPLOYMENTS '[{"name":"gpt-5-mini","model":{"format":"OpenAI","name":"gpt-5-mini","version":"2025-08-07"},"sku":{"name":"GlobalStandard","capacity":10}}]'

azd provision --no-prompt
```

`azd provision` 鍙窇 bicep,**涓?*鍋氶暅鍍忔瀯寤?agent 鍙戝竷;姝ゆ椂浼氬緱鍒颁竴涓湁妯″瀷閮ㄧ讲鐨勭┖ Foundry 椤圭洰銆?

鎵ц瀹屽悗:

```bash
azd env get-values
# 鍏抽敭杈撳嚭:
#   AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>
#   AZURE_RESOURCE_GROUP=rg-dev
#   AZURE_CONTAINER_REGISTRY_NAME=...(鑻ュ惎鐢?hosted agents)
```

---

## 5. 绗笁姝?鍒涘缓 Model

妯″瀷閮ㄧ讲鏄?Foundry account 涓婄殑 `Microsoft.CognitiveServices/accounts/deployments` 瀛愯祫婧?starter 鐨?bicep 浼氭牴鎹?`AI_PROJECT_DEPLOYMENTS` 鏁扮粍鑷姩 loop 鍒涘缓銆備袱绉嶅０鏄庢柟寮?

### 5.1 鎵嬪伐璁剧疆 `AI_PROJECT_DEPLOYMENTS`

```bash
azd env set AI_PROJECT_DEPLOYMENTS '[
  {
    "name": "gpt-5-mini",
    "model": { "format": "OpenAI", "name": "gpt-5-mini", "version": "2025-08-07" },
    "sku":   { "name": "GlobalStandard", "capacity": 10 }
  },
  {
    "name": "text-embedding-3-small",
    "model": { "format": "OpenAI", "name": "text-embedding-3-small", "version": "1" },
    "sku":   { "name": "Standard", "capacity": 30 }
  }
]'
```

瀛楁璇箟:

| 瀛楁 | 鍚箟 |
|------|------|
| `name` | 閮ㄧ讲鍚?鍚庣画 agent 寮曠敤杩欎釜鍚嶅瓧,涓嶆槸妯″瀷鏈韩鐨?name) |
| `model.format` | 閫氬父鏄?`OpenAI`;Anthropic / Meta / Mistral 绛夐渶瀵瑰簲鍊?|
| `model.name` / `model.version` | 妯″瀷瀹舵棌鍚嶄笌鐗堟湰鍙?鍙湪 Foundry 妯″瀷鐩綍鎴?`az cognitiveservices account list-models` 鏌?|
| `sku.name` | `Standard` / `GlobalStandard` / `ProvisionedManaged` 绛?|
| `sku.capacity` | TPM 閰嶉(鍗?token/鍒嗛挓),鍙楄闃呴厤棰濋檺鍒?|

### 5.2 閫氳繃 `azd ai agent init` 鑷姩娉ㄥ叆

`azd ai agent init` 鍦ㄨВ鏋?agent.yaml 鏃朵細**鑷姩**鎶婃墍闇€妯″瀷鍐欏埌 `azure.yaml` 鐨?`services.<agentName>.config.deployments` 涓?渚嬪:

```yaml
services:
  CalculatorAgent:
    project: src/CalculatorAgent
    host: azure.ai.agent
    language: docker
    docker:
      remoteBuild: true
    config:
      container:
        resources: { cpu: "1", memory: 2Gi }
        scale:    { maxReplicas: 3, minReplicas: 1 }
      deployments:
        - name: gpt-5-mini
          model:
            format: OpenAI
            name: gpt-5-mini
            version: "2025-08-07"
          sku:
            name: GlobalStandard
            capacity: 10
```

`azd up` 鐨?**pre-provision hook** 浼氳仛鍚?`services.*.config.deployments` 涓?`AI_PROJECT_DEPLOYMENTS`,鍐欐垚鏈€缁堢殑閮ㄧ讲鍒楄〃浼犵粰 bicep銆?

> **鎺ㄨ崘**:璁?`azd ai agent init` 鏉ョ杩欎竴鍒?閬垮厤鎵嬪伐缁存姢 JSON銆?

### 5.3 SKU / capacity / 鍖哄煙鍙敤鎬?

- 閮ㄧ讲鍓嶇敤 Azure CLI 鏌ョ洰鏍囨ā鍨嬪湪褰撳墠 account 鏄惁鍙揪:
  ```bash
  az cognitiveservices account list-models \
    --name <foundry-account-name> \
    --resource-group <rg> \
    --query "[?name=='gpt-5-mini'].{name:name, version:version, format:format}" -o table
  ```
- 閰嶉鏌ヨ瑙?[`microsoft-foundry:quota`](https://learn.microsoft.com/en-us/azure/ai-foundry/) 鐩稿叧鏂囨。,鎴?Foundry 闂ㄦ埛 Management center 鈫?Quotas銆?
- 涓嶅悓鍖哄煙 SKU 鏀寔宸紓杈冨ぇ,`GlobalStandard` 涓€鑸湪涓昏鍖哄煙鍙敤;`ProvisionedManaged` 闇€瑕侀璐?PTU銆?

---

## 6. 绗洓姝?鍒涘缓 Hosted Agent

### 6.1 瀹夎 `azd ai agent` extension

```bash
azd extension install azure.ai.agents
# 楠岃瘉
azd extension list
```

鏈畨瑁呮椂,棣栨 `azd ai agent init` 浼氭彁绀哄苟鑷姩瀹夎銆?

### 6.2 鐢?`azd ai agent init` 鎷夊彇 agent 瀹氫箟

`agent.yaml` 鎻忚堪浜?agent 鐨?kind / 鍗忚 / 鐜鍙橀噺 / 妯″瀷闇€姹傘€傚彲鐢ㄥ畼鏂圭ず渚?涔熷彲鎸囧悜鑷繁浠撳簱閲岀殑 yaml銆?

```bash
# 渚?Microsoft Agent Framework 鐨?basic responses 绀轰緥
azd ai agent init -m https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml
```

> 涔熷彲浠ユ祻瑙堝叾瀹冪ず渚?`agent-framework/responses/02-tools`銆乣03-mcp`銆乣05-workflows` 绛?鎴?[`bring-your-own`](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents/bring-your-own) 鐩綍閲岀殑鑷畾涔夋鏋剁ず渚嬨€?

鎵╁睍浼?

1. 鎶?agent 婧愪唬鐮佷笅杞藉埌 `src/<AgentName>/`(鍖呭惈 Dockerfile銆乤gent 鍏ュ彛銆乣agent.yaml`)銆?
2. 鍦?`azure.yaml` 涓柊澧炰竴椤?`services.<AgentName>`(瑙?搂5.2 绀轰緥),`host: azure.ai.agent`,`language: docker`銆?
3. 璁剧疆 `ENABLE_HOSTED_AGENTS=true`(鑷姩鍐欏叆 `.azure/<env>/.env`)銆?
4. 鎶?agent 鎵€闇€鐨勭幆澧冨彉閲忔槧灏勮繘 azd env(`AZURE_AI_PROJECT_ENDPOINT`銆乣AZURE_AI_MODEL_DEPLOYMENT` 绛?銆?

> 鍚屼竴涓?azd 鐜閲屽彲浠ュ娆?`azd ai agent init`,寰楀埌澶?agent 鐨勯」鐩€?

### 6.3 `azd up` 鎵ц娴佺▼鎷嗚В

```bash
azd up --no-prompt
```

浼氭寜椤哄簭鍋氳繖浜涗簨鎯?

| 闃舵 | 鍐呴儴鍔ㄤ綔 | 鍏抽敭缁嗚妭 |
|------|----------|----------|
| **pre-provision hook** | 瑙ｆ瀽 `services.*` + 鐜鍙橀噺,鑱氬悎 `AI_PROJECT_DEPLOYMENTS` / `AI_PROJECT_CONNECTIONS` / `AI_PROJECT_DEPENDENT_RESOURCES` / `ENABLE_HOSTED_AGENTS` | 鎶婂０鏄庡紡閰嶇疆缈昏瘧鎴?bicep 鍙傛暟 |
| **provision (bicep)** | 鍒涘缓 Resource Group銆丗oundry account銆丗oundry project銆丄CR銆乧apability host銆丮anaged Identity銆佹ā鍨嬮儴缃层€丷ole Assignments | 5鈥?0 鍒嗛挓;澶辫触鍙洿鎺ラ噸璺?|
| **package** | 瀵规瘡涓?`host: azure.ai.agent` 鐨?service 鏋勫缓瀹瑰櫒闀滃儚 | `docker.remoteBuild: true` 鏃惰蛋 ACR Tasks 浜戞瀯寤?`az acr build`),鏃犻渶鏈湴 Docker;闀滃儚 tag 鐢ㄦ椂闂存埑淇濊瘉鍞竴 |
| **publish (ACR push)** | 鎺ㄩ€侀暅鍍忓埌涓婁竴姝ュ缓濂界殑 ACR | 鐢?capability host 鐨?managed identity `AcrPull` 閴存潈 |
| **agent publish** | 璋冪敤 Foundry control plane,鍒涘缓 Agent Application,缁戝畾闀滃儚 + 妯″瀷 + 鐜鍙橀噺 | 杈撳嚭 agent name / version / endpoint |
| **post hook** | 杈撳嚭 Playground 閾炬帴 | https://ai.azure.com/... |

> **閲嶈**:蹇呴』鐢?`linux/amd64` 闀滃儚;starter 鐨?Dockerfile 宸茶缃ソ銆傚鏋滆嚜琛屾浛鎹?Dockerfile,璁板緱 `--platform linux/amd64`銆?

### 6.4 楠岃瘉 Agent

#### 鏂瑰紡 A:Foundry Portal

```bash
# 鎷垮埌 portal 閾炬帴
azd env get-values | grep AZURE_AI_PROJECT_ENDPOINT
```

鎵撳紑 https://ai.azure.com 鈫?閫変腑瀵瑰簲椤圭洰 鈫?**Agents** 鑺傜偣 鈫?鎵惧埌鍒氬彂甯冪殑 agent 鈫?鐐?**Open in playground** 鍙戞祴璇曟秷鎭€?

#### 鏂瑰紡 B:Responses API 鐩存帴璋冪敤

Hosted agent 榛樿鎻愪緵 OpenAI Responses 鍗忚:

```bash
ENDPOINT=$(azd env get-value AZURE_AI_PROJECT_ENDPOINT)
TOKEN=$(az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv)

curl -X POST "$ENDPOINT/agents/<AgentName>/responses" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"input":"Hello, who are you?"}'
```

#### 鏂瑰紡 C:瀹瑰櫒鍋ュ悍妫€鏌?

濡傛灉鍙兂纭瀹瑰櫒鍦?Foundry 涓婅窇璧锋潵浜?Foundry MCP 宸ュ叿 `agent_container_status_get` 浼氳繑鍥?`Running`/`Failed`(鏈皟鐮旀湭瀹為檯璋冪敤)銆?

---

## 7. 涓€浣撳寲绔埌绔ず渚嬭剼鏈?

> 鍗犱綅绗?`<appId>` `<secret>` `<tid>` `<subId>` 鍦?CI 涓€氬父浠?Secret Store(GitHub Secrets / KeyVault / Pipelines Variable Group)璇诲叆銆?

### 7.1 Bash 鐗?

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_ID="<appId>"
APP_SECRET="<secret>"
TENANT_ID="<tid>"
SUB_ID="<subId>"
ENV_NAME="dev"
LOCATION="northcentralus"
AGENT_YAML_URL="https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml"

# 1. 鍙岀櫥褰?
az login --service-principal -u "$APP_ID" -p "$APP_SECRET" --tenant "$TENANT_ID" >/dev/null
az account set --subscription "$SUB_ID"
azd auth login --client-id "$APP_ID" --client-secret "$APP_SECRET" --tenant-id "$TENANT_ID"

# 2. 榛樿鍊?
azd config set defaults.subscription "$SUB_ID"
azd config set defaults.location "$LOCATION"

# 3. 鎵╁睍
azd extension install azure.ai.agents

# 4. 鍒濆鍖?
mkdir -p my-foundry-app && cd my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e "$ENV_NAME" --no-prompt

# 5. 娉ㄥ叆 agent(鑷姩璁剧疆妯″瀷 + ENABLE_HOSTED_AGENTS=true)
azd ai agent init -m "$AGENT_YAML_URL"

# 6. 涓€閿儴缃?
azd up --no-prompt

# 7. 杈撳嚭
azd env get-values
```

### 7.2 PowerShell 鐗?

```powershell
$ErrorActionPreference = "Stop"

$AppId    = "<appId>"
$Secret   = "<secret>"
$TenantId = "<tid>"
$SubId    = "<subId>"
$EnvName  = "dev"
$Location = "northcentralus"
$AgentYaml = "https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml"

# 1. 鍙岀櫥褰?
az login --service-principal -u $AppId -p $Secret --tenant $TenantId | Out-Null
az account set --subscription $SubId
azd auth login --client-id $AppId --client-secret $Secret --tenant-id $TenantId

# 2. 榛樿鍊?
azd config set defaults.subscription $SubId
azd config set defaults.location $Location

# 3. 鎵╁睍
azd extension install azure.ai.agents

# 4. 鍒濆鍖?蹇呴』鍦ㄧ┖鐩綍)
New-Item -ItemType Directory -Force my-foundry-app | Out-Null
Set-Location my-foundry-app
azd init -t Azure-Samples/azd-ai-starter-basic -e $EnvName --no-prompt

# 5. 娉ㄥ叆 agent
azd ai agent init -m $AgentYaml

# 6. 涓€閿儴缃?
azd up --no-prompt

# 7. 杈撳嚭
azd env get-values
```

> CI 鍦烘櫙涓嬬敤 OIDC 鑱斿悎鍑嵁鏇村畨鍏?鎶婄 1 姝ユ浛鎹负:
> `azd auth login --client-id $AppId --federated-credential-provider github --tenant-id $TenantId`(GitHub Actions)銆?

---

## 8. 甯歌閿欒涓庢帓鏌?

| 閿欒鐗瑰緛 | 鏍瑰洜 | 澶勭悊 |
|----------|------|------|
| `Authorization failed ... does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'` | SP 缂?**User Access Administrator** | 缁?SP 鍦ㄨ闃?RG 涓婂姞璇ヨ鑹插悗 `azd provision` 閲嶈窇 |
| `AuthorizationFailed: ... Microsoft.CognitiveServices/accounts/write` | SP 缂?Contributor 鎴栬绛栫暐绂佹鍒涘缓 Cognitive Services | 鍔?Contributor;鑻ョ粍缁囩瓥鐣ョ鐢?AIServices,鑱旂郴璁㈤槄 owner |
| `RegionNotSupportedForHostedAgents` | 閫変簡闈為瑙堟敮鎸佸尯鍩?| `azd config set defaults.location northcentralus` 鍚庨噸璺?|
| `Failed to authenticate` 鎴?`ChainedTokenCredential ... no credential available` | `azd` 娌＄櫥褰曟垨 secret 杩囨湡 | `azd auth login --check-status` 鎺掓煡;CI 涓鏌?secret 鏄惁鏇存柊 |
| `docker: command not found` 鎴栨湰鍦?Docker 涓嶅彲鐢?| 榛樿 `docker.remoteBuild` 鏈惎鐢?| 鍦?`azure.yaml` 涓?`docker.remoteBuild: true`,鎴栨湰鏈鸿 Docker Desktop |
| `image platform does not match host platform` | 鏈湴 `docker build` 娌″姞 `--platform linux/amd64` | 鐢ㄤ簯鏋勫缓,鎴栨湰鍦版瀯寤烘椂鏄惧紡鍔?`--platform linux/amd64` |
| `azd up` 鍗″湪 `package` 寰堜箙 | 澶т綋绉緷璧栫涓€娆℃帹 ACR | 绛夊緟鎴栨媶 base image;鍚庣画鏋勫缓浼氬鐢?layer |
| `azd ai agent init` 鎶ユ墿灞曟湭娉ㄥ唽 | 娌¤鎵╁睍 | `azd extension install azure.ai.agents` |
| `--client-secret` 鍚?`$`/`!`/`"` 绛夊瓧绗﹀湪 bash 涓嬭鏇挎崲 | shell 杞箟 | 鐢ㄥ崟寮曞彿(bash)鎴栧弻寮曞彿(PowerShell);鎴栫敤 `--client-certificate` 鏇夸唬 |
| `azd up` 鎴愬姛浣?portal 鐪嬩笉鍒?agent | 鐢ㄤ簡閿欒鐨?Foundry account/project | `azd env get-value AZURE_AI_PROJECT_ENDPOINT` 鎷垮埌鐨勯摼鎺ユ墠鏄綋鍓嶉儴缃茬殑椤圭洰 |

璋冭瘯鎶€宸?

```bash
azd up --debug 2>&1 | tee azd-up.log     # 璇︾粏 trace 鍚?bicep 閿欒
az deployment group list -g rg-dev --query "[].{Name:name, State:properties.provisioningState}" -o table
```

---

## 9. 娓呯悊:`azd down`

```bash
azd down --purge --force --no-prompt
```

- 鍒犻櫎褰撳墠 azd 鐜瀵瑰簲鐨?*鏁翠釜 Resource Group**(Foundry account銆佹墍鏈夋ā鍨嬮儴缃层€丄CR銆丄pp Insights銆丩og Analytics 鍏ㄩ儴娑堝け)銆?
- `--purge` 瑙﹀彂 Foundry account 鐨勮蒋鍒犻櫎娓呯悊,**閬垮厤** 48 灏忔椂鍐呭悓鍚嶉噸寤哄け璐ャ€?
- CI/CD 涓皑鎱庝娇鐢?涓嶈璇垹鐢熶骇 RG銆?

---

## 10. 鍙傝€冮摼鎺?

- [`azd auth login` 鍛戒护鍙傝€僝(https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-auth-login)
- [Azure Developer CLI 瀹夎](https://aka.ms/azure-dev/install)
- [`azd ai agent` extension 鏂囨。](https://aka.ms/azdaiagent/docs)
- [`Azure-Samples/azd-ai-starter-basic` 妯℃澘](https://github.com/Azure-Samples/azd-ai-starter-basic)
- [Foundry Hosted Agents 姒傚康](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [Foundry Agent Runtime Components](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/runtime-components)
- [Foundry 鍖哄煙鏀寔](https://learn.microsoft.com/en-us/azure/ai-foundry/reference/region-support)
- [Foundry Agent Service 妯″瀷鍖哄煙鏀寔](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/model-region-support?tabs=global-standard)
- [Foundry Samples 鈥?Hosted Agents (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [Foundry Samples 鈥?Hosted Agents (C#)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/csharp/hosted-agents)
- [Azure Identity:鏈嶅姟涓讳綋鏈€浣冲疄璺礭(https://learn.microsoft.com/azure/developer/intro/passwordless-overview)

