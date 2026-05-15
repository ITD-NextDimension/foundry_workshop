"""Persona loader smoke tests."""
from __future__ import annotations

import pytest

from src.shared.persona import load_persona


def test_load_billing_persona_expands_includes():
    text = load_persona("billing-agent.md")
    # Frontmatter intact
    assert "agent: billing-agent" in text
    # Include directives expanded:
    assert "Guardrails(跨 agent 通用)" in text
    assert "Handoff Protocol" in text
    assert "Citation Format" in text
    # Raw include markers replaced (must not contain literal markers anymore):
    assert "{{include:" not in text


def test_load_triage_persona():
    text = load_persona("triage-agent.md")
    assert "agent: triage-agent" in text
    assert "Categories" in text
    assert "{{include:" not in text


def test_unknown_persona_raises():
    with pytest.raises(FileNotFoundError):
        load_persona("does-not-exist.md")
