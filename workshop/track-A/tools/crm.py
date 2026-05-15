"""CRM lookup tool — workshop mock + real-call placeholder.

在生产环境中,把 _MOCK_CRM 部分换成真实 HTTPX 调用即可。
"""
from __future__ import annotations

import logging
import os
from typing import Literal

import httpx
from agent_framework import ai_function
from opentelemetry import trace
from pydantic import BaseModel

logger = logging.getLogger("workshop.tools.crm")
tracer = trace.get_tracer("workshop.tools.crm")

Tier = Literal["Enterprise", "Business", "Free"]


class CrmLookupResult(BaseModel):
    customer_id: str
    tier: Tier
    arr: float
    contract_end: str
    company_name: str
    primary_contact_email: str


_MOCK_CRM: dict[str, CrmLookupResult] = {
    "ACME-001": CrmLookupResult(
        customer_id="ACME-001",
        tier="Enterprise",
        arr=120_000.0,
        contract_end="2026-12-01",
        company_name="Acme Corp",
        primary_contact_email="ops@acme.example.com",
    ),
    "BIZCO-042": CrmLookupResult(
        customer_id="BIZCO-042",
        tier="Business",
        arr=12_000.0,
        contract_end="2026-08-31",
        company_name="BizCo Ltd",
        primary_contact_email="admin@bizco.example.com",
    ),
    "FREE-999": CrmLookupResult(
        customer_id="FREE-999",
        tier="Free",
        arr=0.0,
        contract_end="9999-12-31",
        company_name="Hobby User",
        primary_contact_email="user@example.com",
    ),
}


async def _real_crm_call(customer_id: str) -> CrmLookupResult:
    base = os.environ.get("CRM_API_BASE_URL")
    if not base:
        raise RuntimeError("CRM_API_BASE_URL not set; falling back to mock.")
    token = os.environ.get("CRM_API_TOKEN", "")
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            f"{base.rstrip('/')}/customers/{customer_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        resp.raise_for_status()
        data = resp.json()
    return CrmLookupResult(**data)


@ai_function(
    name="crm_lookup",
    description=(
        "根据 customerId 查询 CRM 中的客户信息(tier / arr / 合同到期日 / 公司名)。"
        "BillingAgent 在处理任何金额相关问题前**必须**先调用此工具。"
    ),
)
async def crm_lookup(customer_id: str) -> CrmLookupResult:
    """Look up a customer in CRM by ID.

    Args:
        customer_id: CRM 客户编号,如 'ACME-001'。
    """
    with tracer.start_as_current_span("crm.lookup") as span:
        span.set_attribute("customer.id", customer_id)
        if os.environ.get("CRM_API_BASE_URL"):
            try:
                result = await _real_crm_call(customer_id)
                span.set_attribute("crm.source", "live")
                return result
            except Exception as exc:
                logger.warning("CRM live call failed (%s); falling back to mock.", exc)
                span.set_attribute("crm.fallback", "mock")
        if customer_id in _MOCK_CRM:
            span.set_attribute("crm.source", "mock")
            span.set_attribute("customer.tier", _MOCK_CRM[customer_id].tier)
            return _MOCK_CRM[customer_id]
        raise ValueError(f"Customer not found: {customer_id}")
