"""Unit tests for the refund-quote skill script."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[2] / "skills" / "refund-quote" / "scripts" / "quote.py"


def _run(args: list[str]) -> dict:
    cp = subprocess.run(
        [sys.executable, str(_SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    assert cp.returncode == 0, f"stderr={cp.stderr}"
    return json.loads(cp.stdout)


def test_enterprise_within_window():
    out = _run(["--tier", "Enterprise", "--amount", "100000", "--contract-end", "2099-12-31", "--today", "2026-05-14"])
    assert out["policyVersion"] == "v3.2"
    assert out["maxRefund"] == 50000.0
    assert out["capped"] is True


def test_business_within_window():
    out = _run(["--tier", "Business", "--amount", "10000", "--contract-end", "2099-12-31", "--today", "2026-05-14"])
    assert out["maxRefund"] == 2500.0


def test_free_no_refund():
    out = _run(["--tier", "Free", "--amount", "100"])
    assert out["maxRefund"] == 0
    assert "no refund" in out["explanation"].lower()


def test_contract_ended():
    out = _run(["--tier", "Enterprise", "--amount", "100000", "--contract-end", "2020-01-01", "--today", "2026-05-14"])
    assert out["maxRefund"] == 0
    assert "outside refund window" in out["explanation"]
