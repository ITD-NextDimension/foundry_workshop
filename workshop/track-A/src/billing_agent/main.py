"""BillingAgent — refund / invoice / contract questions.

Local dev:
    $env:AZURE_AI_PROJECT_ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT
    $env:FOUNDRY_MODEL_DEPLOYMENT_NAME = azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME
    agentdev run src/billing_agent/main.py --port 8087
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

from agent_framework import Agent, SkillsProvider

# Workshop imports
import sys as _sys
_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in _sys.path:
    _sys.path.insert(0, str(_REPO))

from src.shared.client_factory import build_chat_client  # noqa: E402
from src.shared.persona import load_persona  # noqa: E402
from src.shared.skill_runner import run_local_skill_script  # noqa: E402
from tools.crm import crm_lookup  # noqa: E402
from tools.ticketing import create_ticket, get_ticket  # noqa: E402
from tools.handoff import handoff_to_tech_support, handoff_to_human  # noqa: E402

logging.basicConfig(level=logging.INFO)


def build_agent() -> Agent:
    skills_provider = SkillsProvider.from_paths(
        skill_paths=[_REPO / "skills"],
        script_runner=run_local_skill_script,
    )
    return Agent(
        name="billing-agent",
        client=build_chat_client(),
        instructions=load_persona("billing-agent.md"),
        context_providers=[skills_provider],
        tools=[crm_lookup, create_ticket, get_ticket, handoff_to_tech_support, handoff_to_human],
        default_options={"store": False},
    )


agent = build_agent()


if __name__ == "__main__":
    # Local dev path: agentdev run will pick up `agent`. Fallback: start ResponsesHostServer.
    try:
        from azure_ai_agentserver_agentframework import ResponsesHostServer  # type: ignore
        port = int(os.environ.get("PORT", "8087"))
        ResponsesHostServer(agent).run(port=port)
    except ImportError:
        print("Install azure-ai-agentserver-agentframework or run via `agentdev run`.")
