"""ResearchAgent — market/competitive research using web_search + web_fetch + report_builder.

Local dev:
    $env:AZURE_AI_PROJECT_ENDPOINT     = azd env get-value AZURE_AI_PROJECT_ENDPOINT
    $env:AZURE_AI_MODEL_DEPLOYMENT_NAME = azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME
    agentdev run src/research_agent/main.py --port 8087
"""
from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

from agent_framework import Agent, SkillsProvider

# Track-A repo root must be importable for `tools.*` / `src.shared.*`.
_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from src.shared.client_factory import build_chat_client  # noqa: E402
from src.shared.persona import load_persona  # noqa: E402
from src.shared.skill_runner import run_local_skill_script  # noqa: E402
from tools.web_search import web_search  # noqa: E402
from tools.web_fetch import web_fetch  # noqa: E402
from tools.report_builder import report_builder  # noqa: E402


logging.basicConfig(level=logging.INFO)


def build_agent() -> Agent:
    skills_provider = SkillsProvider.from_paths(
        skill_paths=[_REPO / "skills"],
        script_runner=run_local_skill_script,
    )
    return Agent(
        name=os.environ.get("AGENT_NAME", "research-agent"),
        client=build_chat_client(),
        instructions=load_persona("research-agent.md"),
        context_providers=[skills_provider],
        tools=[web_search, web_fetch, report_builder],
        default_options={"store": False},
    )


agent = build_agent()


if __name__ == "__main__":
    try:
        from azure_ai_agentserver_agentframework import ResponsesHostServer  # type: ignore

        port = int(os.environ.get("PORT", "8087"))
        ResponsesHostServer(agent).run(port=port)
    except ImportError:
        print("Install azure-ai-agentserver-agentframework or run via `agentdev run`.")
