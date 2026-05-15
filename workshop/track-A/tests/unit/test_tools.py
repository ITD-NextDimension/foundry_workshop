"""Unit tests for client-side @ai_function tools."""
from __future__ import annotations

import asyncio

import pytest

from tools.crm import CrmLookupResult, crm_lookup
from tools.ticketing import create_ticket, get_ticket


def _run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


@pytest.mark.parametrize(
    "customer_id, expected_tier",
    [
        ("ACME-001", "Enterprise"),
        ("BIZCO-042", "Business"),
        ("FREE-999", "Free"),
    ],
)
def test_crm_lookup_mock_paths(customer_id, expected_tier):
    result: CrmLookupResult = _run(crm_lookup(customer_id))
    assert result.customer_id == customer_id
    assert result.tier == expected_tier


def test_crm_lookup_unknown_raises():
    with pytest.raises(ValueError):
        _run(crm_lookup("NOPE-000"))


def test_create_ticket_returns_id_and_sla():
    r = _run(
        create_ticket(
            customer_id="ACME-001",
            category="tech-bug",
            summary="API returns 429",
            priority="P1",
        )
    )
    assert r.ticket_id.startswith("TICK-")
    assert "8h" in r.sla
    assert r.status == "created"


def test_get_ticket_returns_open_ticket():
    created = _run(
        create_ticket(
            customer_id="BIZCO-042",
            category="billing-dispute",
            summary="invoice overcharge",
        )
    )
    fetched = _run(get_ticket(created.ticket_id))
    assert fetched.ticket_id == created.ticket_id
    assert fetched.customer_id == "BIZCO-042"
    assert fetched.status == "open"
