# Workshop Utility Scripts

> 4 个学员或讲师在 4 个 Lab 里会用到的小工具。

| 脚本 | 用在哪个 Lab | 干什么 |
|------|------------|------|
| [`sanity-check.ps1`](./sanity-check.ps1) | Lab 1 | `azd up` 后跑一次,验证 endpoint / SWA / 模型 / 占位 agent 全 ✅ |
| [`invoke-hosted.ps1`](./invoke-hosted.ps1) | Lab 3 / Lab 4 | 拿 token + POST hosted agent + 打印响应;`-StatusOnly` 只看可达 |
| [`export-traces.ps1`](./export-traces.ps1) | Lab 4 | 通过 SWA API 把过去 N 分钟 trace 拉成 JSON,喂给离线 HTML |
| [`lint-persona.py`](./lint-persona.py) | Lab 2 | 校验 persona frontmatter / `{{include}}` 引用 / 必备 section |

## 用法示例

```powershell
# Lab 1
cd workshop\track-A
..\workshop-scripts\sanity-check.ps1

# Lab 2
..\workshop-scripts\lint-persona.py personas\billing-agent.md

# Lab 3
..\workshop-scripts\invoke-hosted.ps1 -AgentName billing-agent -Prompt "ping"

# Lab 4
..\workshop-scripts\export-traces.ps1 -AgentName billing-agent -Minutes 60
```

## 跨平台说明

`*.ps1` 在 PowerShell 7(`pwoshell`)与 Windows PowerShell 5.1 都能跑。Mac/Linux 学员请装 [PowerShell on Linux/macOS](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux),或者用助教提供的 bash 版本(本 workshop 暂不提供)。
