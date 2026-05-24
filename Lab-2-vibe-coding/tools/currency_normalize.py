"""Currency normalize tool — 把多币种金额折算到目标币 (默认 CNY)。

Backend:
- 真实: Frankfurter free API (https://api.frankfurter.app/latest) — 无 API key
- Mock: 固定汇率表，断网/限流时兜底
"""

from __future__ import annotations

import logging
import os
from typing import Literal

import httpx
from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.currency_normalize")
tracer = trace.get_tracer("workshop.tools.currency_normalize")

RateSource = Literal["mock", "frankfurter"]

# Mock fixed rates (anchored 2026-05; for offline workshop use only).
_MOCK_RATES_TO_CNY: dict[str, float] = {
    "USD": 7.20,
    "EUR": 7.80,
    "HKD": 0.92,
    "JPY": 0.046,
    "GBP": 9.10,
    "CNY": 1.0,
}


class Amount(BaseModel):
    amount: float = Field(ge=0)
    currency: str = Field(min_length=3, max_length=3, description="ISO 4217 3-letter code")


class NormalizedAmount(BaseModel):
    amount: float
    currency: str
    target_amount: float
    rate: float
    rate_source: RateSource


class NormalizeResult(BaseModel):
    target: str
    normalized: list[NormalizedAmount]


async def _frankfurter_rate(base: str, target: str, timeout: float = 5.0) -> float:
    """Fetch a single base→target rate from Frankfurter. Raises on failure."""
    base_url = os.environ.get("FRANKFURTER_BASE_URL", "https://api.frankfurter.app").rstrip("/")
    url = f"{base_url}/latest?from={base}&to={target}"
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        data = resp.json()
    rate = data.get("rates", {}).get(target)
    if rate is None:
        raise RuntimeError(f"Frankfurter returned no rate for {base}→{target}: {data}")
    return float(rate)


def _mock_rate(base: str, target: str) -> float | None:
    """Return a mock rate if both base and target are in the mock table; else None."""
    base_to_cny = _MOCK_RATES_TO_CNY.get(base.upper())
    target_to_cny = _MOCK_RATES_TO_CNY.get(target.upper())
    if base_to_cny is None or target_to_cny is None:
        return None
    if target_to_cny == 0:
        return None
    return base_to_cny / target_to_cny


@ai_function(
    name="currency_normalize",
    description=(
        "把多币种金额数组统一折算到目标币 (默认 CNY)。"
        "发票解读 agent 在 line items 含非 CNY 币种 (或用户明确要折算) 时**必须**调用此工具。"
        "输入 amounts 数组 (含 amount/currency) + target; 输出每项加 target_amount/rate/rate_source。"
        "无 FRANKFURTER 可用时自动走内置 mock 汇率表。"
    ),
)
async def currency_normalize(amounts: list[dict], target: str = "CNY") -> NormalizeResult:
    """Normalize a batch of amounts to a target currency.

    Args:
        amounts: 每项含 amount (float ≥ 0), currency (ISO 4217 3 字母)。
        target: 目标币 ISO 4217 (默认 "CNY")。
    """
    target = target.upper()
    with tracer.start_as_current_span("currency_normalize") as span:
        # Coerce dicts → pydantic.
        parsed = [
            x if isinstance(x, Amount) else Amount.model_validate(x)
            for x in amounts
        ]
        span.set_attribute("target", target)
        span.set_attribute("count", len(parsed))

        force_mock = os.environ.get("WORKSHOP_CURRENCY_NORMALIZE_FORCE_MOCK") == "1"
        normalized: list[NormalizedAmount] = []
        used_live = False
        used_mock = False

        for a in parsed:
            base = a.currency.upper()
            rate: float | None = None
            rate_source: RateSource = "mock"

            if base == target:
                rate = 1.0
                rate_source = "mock"
                used_mock = True
            elif not force_mock:
                try:
                    rate = await _frankfurter_rate(base, target)
                    rate_source = "frankfurter"
                    used_live = True
                except Exception as exc:
                    logger.warning(
                        "Frankfurter failed for %s→%s (%s); falling back to mock.",
                        base, target, exc,
                    )

            if rate is None:
                rate = _mock_rate(base, target)
                rate_source = "mock"
                used_mock = True
                if rate is None:
                    # Unknown pair — refuse to invent. Mark as 0 + 'mock' so caller sees.
                    logger.warning("No rate available for %s→%s; emitting 0.", base, target)
                    rate = 0.0

            normalized.append(
                NormalizedAmount(
                    amount=a.amount,
                    currency=base,
                    target_amount=round(a.amount * rate, 4),
                    rate=rate,
                    rate_source=rate_source,
                )
            )

        if used_live and used_mock:
            span.set_attribute("rate_source", "mixed")
        elif used_live:
            span.set_attribute("rate_source", "frankfurter")
        else:
            span.set_attribute("rate_source", "mock")

        return NormalizeResult(target=target, normalized=normalized)
