"""InvoiceExplainer — 发票解读 agent: OCR → 分类 → 多币种归一 → 异常 + PII 脱敏。

Local dev:
    set -a; source ../.env; set +a
    python3 -m src.invoice_agent.main      # binds 0.0.0.0:8088
"""
from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

from agent_framework import Agent, FileSkillsSource, SkillsProvider

# Repo root must be importable for `tools.*` / `src.shared.*`.
_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from src.shared.client_factory import build_chat_client  # noqa: E402
from src.shared.persona import load_persona  # noqa: E402
from tools.ocr_extract import ocr_extract  # noqa: E402
from tools.classify_charges import classify_charges  # noqa: E402
from tools.currency_normalize import currency_normalize  # noqa: E402


logging.basicConfig(level=logging.INFO)


def build_agent() -> Agent:
    skills_provider = SkillsProvider(FileSkillsSource(skill_paths=[_REPO / "skills"]))
    return Agent(
        build_chat_client(),
        instructions=load_persona("invoice-explainer.md"),
        name=os.environ.get("AGENT_NAME", "invoice-explainer"),
        context_providers=[skills_provider],
        tools=[ocr_extract, classify_charges, currency_normalize],
    )


agent = build_agent()


if __name__ == "__main__":
    # Foundry hosted runtime probes /readiness and /responses on port 8088.
    from agent_framework_foundry_hosting import ResponsesHostServer  # type: ignore
    from starlette.middleware.cors import CORSMiddleware  # type: ignore

    server = ResponsesHostServer(agent)
    # Allow the workshop chat-hosted UI (served from file://) to call this server.
    # No effect on the hosted Foundry deployment — that runs through the Foundry gateway.
    server.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    server.run()
