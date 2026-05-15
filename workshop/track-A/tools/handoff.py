"""Handoff tools — route to specialized sub-agents.

These tools generate a structured handoff payload (per `personas/shared/handoff-protocol.md`)
that the orchestration layer (workflow.yaml or WorkflowBuilder) picks up.
"""
from __future__ import annotations

import uuid
from typing import Literal, Optional

from agent_framework import ai_function
from opentelemetry import trace
from pydantic import BaseModel

tracer = trace.get_tracer("workshop.tools.handoff")

TargetAgent = Literal["tech-support", "billing", "kb", "human"]
Priority = Literal["P0", "P1", "P2"]


class HandoffResult(BaseModel):
    acknowledgment_id: str
    to_agent: TargetAgent
    accepted: bool
    note: str


class HandoffContext(BaseModel):
    customer_id: Optional[str] = None
    tier: Optional[str] = None
    summary: str


@ai_function(
    name="handoff_to_tech_support",
    description=(
        "把对话交接给 TechSupportAgent。"
        "用于:产品 bug、配置错误、限流、超时类问题。"
        "调用前**必须**填写 reason + context.summary(≤100 字)。"
    ),
)
async def handoff_to_tech_support(
    conversation_id: str,
    reason: str,
    context: HandoffContext,
    priority: Priority = "P1",
) -> HandoffResult:
    return await _handoff("tech-support", conversation_id, reason, context, priority)


@ai_function(
    name="handoff_to_billing",
    description=(
        "把对话交接给 BillingAgent。"
        "用于:退款、发票、用量超额、合同升降级。"
    ),
)
async def handoff_to_billing(
    conversation_id: str,
    reason: str,
    context: HandoffContext,
    priority: Priority = "P1",
) -> HandoffResult:
    return await _handoff("billing", conversation_id, reason, context, priority)


@ai_function(
    name="handoff_to_kb",
    description="把对话交接给 KBAgent,用于事实性查询(政策 / 定价 / SLA)。",
)
async def handoff_to_kb(
    conversation_id: str,
    reason: str,
    context: HandoffContext,
    priority: Priority = "P2",
) -> HandoffResult:
    return await _handoff("kb", conversation_id, reason, context, priority)


@ai_function(
    name="handoff_to_human",
    description=(
        "把对话交接给人工客服。"
        "用于:法律咨询、严重投诉、循环交接超过 2 次、guardrails 拒绝后用户坚持。"
    ),
)
async def handoff_to_human(
    conversation_id: str,
    reason: str,
    context: HandoffContext,
    priority: Priority = "P0",
) -> HandoffResult:
    return await _handoff("human", conversation_id, reason, context, priority)


async def _handoff(
    to_agent: TargetAgent,
    conversation_id: str,
    reason: str,
    context: HandoffContext,
    priority: Priority,
) -> HandoffResult:
    with tracer.start_as_current_span("subagent.handoff") as span:
        span.set_attribute("from", "current-agent")
        span.set_attribute("to", to_agent)
        span.set_attribute("reason", reason)
        span.set_attribute("priority", priority)
        span.set_attribute("conversation.id", conversation_id)

        ack_id = f"HOFF-{uuid.uuid4().hex[:6].upper()}"
        return HandoffResult(
            acknowledgment_id=ack_id,
            to_agent=to_agent,
            accepted=True,
            note=f"Handoff accepted; downstream {to_agent} will continue.",
        )
