"""TechSupportAgent — product / config / runtime-error troubleshooting."""
from __future__ import annotations

import logging
import os
import sys as _sys
from pathlib import Path

from agent_framework import Agent, SkillsProvider

_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in _sys.path:
    _sys.path.insert(0, str(_REPO))

from src.shared.client_factory import build_chat_client  # noqa: E402
from src.shared.persona import load_persona  # noqa: E402
from src.shared.skill_runner import run_local_skill_script  # noqa: E402
from tools.crm import crm_lookup  # noqa: E402
from tools.ticketing import create_ticket, get_ticket  # noqa: E402
from tools.handoff import handoff_to_billing, handoff_to_kb, handoff_to_human  # noqa: E402

logging.basicConfig(level=logging.INFO)


def build_agent() -> Agent:
    skills_provider = SkillsProvider.from_paths(
        skill_paths=[_REPO / "skills"],
        script_runner=run_local_skill_script,
    )
    return Agent(
        name="tech-support-agent",
        client=build_chat_client(),
        instructions=load_persona("tech-support-agent.md"),
        context_providers=[skills_provider],
        tools=[
            crm_lookup,
            create_ticket,
            get_ticket,
            handoff_to_billing,
            handoff_to_kb,
            handoff_to_human,
        ],
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
