"""KBAgent — fact retrieval with citations."""
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
from tools.handoff import handoff_to_billing, handoff_to_tech_support, handoff_to_human  # noqa: E402

logging.basicConfig(level=logging.INFO)


def build_agent() -> Agent:
    skills_provider = SkillsProvider.from_paths(
        skill_paths=[_REPO / "skills"],
        script_runner=run_local_skill_script,
    )
    return Agent(
        name="kb-agent",
        client=build_chat_client(),
        instructions=load_persona("kb-agent.md"),
        context_providers=[skills_provider],
        # KBAgent intentionally has no business-state tools; it only answers facts.
        # Routing tools so it can hand off if a question is mis-routed here.
        tools=[handoff_to_billing, handoff_to_tech_support, handoff_to_human],
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
