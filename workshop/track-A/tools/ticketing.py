"""Ticketing tool — create / update / get tickets.

Mock-first; switch to real ticketing system via TICKETING_API_BASE_URL.
"""
from __future__ import annotations

import logging
import os
import uuid
from datetime import datetime
from typing import Literal

import httpx
from agent_framework import ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.ticketing")
tracer = trace.get_tracer("workshop.tools.ticketing")

Category = Literal["tech-bug", "billing-dispute", "feature-request", "other"]
Priority = Literal["P0", "P1", "P2"]


class CreateTicketResult(BaseModel):
    ticket_id: str
    status: Literal["created", "duplicate"]
    sla: str = Field(description="人类可读 SLA,如 '4h response, 24h workaround'")


_MOCK_TICKETS: dict[str, dict] = {}


def _fake_ticket_id() -> str:
    return f"TICK-{uuid.uuid4().hex[:6].upper()}"


@ai_function(
    name="create_ticket",
    description=(
        "为客户创建工单。category 必填,priority 默认 P1。"
        "调用前**必须**先用 crm_lookup 拿到 customer_id 与 tier。"
        "返回 ticketId 与 SLA。"
    ),
)
async def create_ticket(
    customer_id: str,
    category: Category,
    summary: str,
    priority: Priority = "P1",
) -> CreateTicketResult:
    """Create a ticket.

    Args:
        customer_id: 已通过 crm_lookup 验证过的客户编号
        category: 工单类型
        summary: 工单摘要(≤200 字)
        priority: P0/P1/P2,默认 P1
    """
    with tracer.start_as_current_span("ticket.create") as span:
        span.set_attribute("ticket.customer_id", customer_id)
        span.set_attribute("ticket.category", category)
        span.set_attribute("ticket.priority", priority)

        base = os.environ.get("TICKETING_API_BASE_URL")
        if base:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.post(
                        f"{base.rstrip('/')}/tickets",
                        json={
                            "customerId": customer_id,
                            "category": category,
                            "summary": summary,
                            "priority": priority,
                        },
                        headers={"Authorization": f"Bearer {os.environ.get('TICKETING_API_TOKEN', '')}"},
                    )
                    resp.raise_for_status()
                    data = resp.json()
                span.set_attribute("ticket.source", "live")
                span.set_attribute("ticket.id", data["ticketId"])
                return CreateTicketResult(**data)
            except Exception as exc:
                logger.warning("Ticketing live call failed (%s); falling back to mock.", exc)
                span.set_attribute("ticket.fallback", "mock")

        # Mock path
        ticket_id = _fake_ticket_id()
        _MOCK_TICKETS[ticket_id] = {
            "customerId": customer_id,
            "category": category,
            "summary": summary,
            "priority": priority,
            "createdAt": datetime.utcnow().isoformat(),
        }
        sla = {
            "P0": "4h response, 24h workaround",
            "P1": "8h response, 48h workaround",
            "P2": "2 business days response",
        }[priority]
        span.set_attribute("ticket.source", "mock")
        span.set_attribute("ticket.id", ticket_id)
        return CreateTicketResult(ticket_id=ticket_id, status="created", sla=sla)


class GetTicketResult(BaseModel):
    ticket_id: str
    customer_id: str
    category: Category
    summary: str
    priority: Priority
    status: Literal["open", "in-progress", "resolved", "closed"]


@ai_function(
    name="get_ticket",
    description="按 ticket_id 查询工单当前状态。",
)
async def get_ticket(ticket_id: str) -> GetTicketResult:
    """Look up a ticket by id."""
    with tracer.start_as_current_span("ticket.get") as span:
        span.set_attribute("ticket.id", ticket_id)
        if ticket_id in _MOCK_TICKETS:
            t = _MOCK_TICKETS[ticket_id]
            return GetTicketResult(
                ticket_id=ticket_id,
                customer_id=t["customerId"],
                category=t["category"],
                summary=t["summary"],
                priority=t["priority"],
                status="open",
            )
        raise ValueError(f"Ticket not found: {ticket_id}")
