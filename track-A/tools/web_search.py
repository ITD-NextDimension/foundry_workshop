"""Web search tool — 工作坊用 Bing 风格搜索包装 (mock + 真调用).

真实模式: 设 BING_SEARCH_API_KEY (Bing Web Search v7) 或 GOOGLE_CSE_KEY+GOOGLE_CSE_CX,
否则回退到内置 mock，方便学员离线 vibe coding.
"""
from __future__ import annotations

import logging
import os
from datetime import date
from typing import Literal

import httpx
from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.web_search")
tracer = trace.get_tracer("workshop.tools.web_search")

Provider = Literal["bing", "google", "mock"]


class SearchHit(BaseModel):
    title: str
    url: str
    snippet: str = ""
    domain: str = ""
    publishedAt: str | None = None


class WebSearchResult(BaseModel):
    query: str
    provider: Provider
    count: int
    results: list[SearchHit]
    cached: bool = Field(default=False, description="True 表示命中本地 mock，无外部调用")


# ---------------------------------------------------------------------------
# Mock dataset — 让学员离线也能跑通 vibe coding 流程
# ---------------------------------------------------------------------------
_MOCK_HITS: dict[str, list[SearchHit]] = {
    "ai notes app market": [
        SearchHit(
            title="The State of AI Note-Taking Apps in 2025",
            url="https://example-research.com/ai-notes-2025",
            snippet="Market overview of consumer AI note-taking apps: top 5 players, pricing, growth.",
            domain="example-research.com",
            publishedAt="2025-02-10",
        ),
        SearchHit(
            title="Notion AI vs Obsidian vs Mem — feature comparison",
            url="https://blog.example.com/notion-obsidian-mem",
            snippet="Side-by-side functional comparison updated for 2025.",
            domain="blog.example.com",
            publishedAt="2024-11-22",
        ),
        SearchHit(
            title="Consumer AI productivity report (analyst sample)",
            url="https://analyst.example.org/consumer-ai-2025",
            snippet="Estimated DAU + ARR for top 10 AI productivity apps.",
            domain="analyst.example.org",
            publishedAt="2025-01-05",
        ),
    ],
    "新茶饮市场": [
        SearchHit(
            title="2024 新茶饮赛道白皮书",
            url="https://example-research.com/cn-tea-2024",
            snippet="中国新茶饮 2024 市场规模约 ¥3,547 亿元，同比增长 23%。",
            domain="example-research.com",
            publishedAt="2024-12-01",
        ),
        SearchHit(
            title="蜜雪 / 古茗 / 茶百道 招股书摘要",
            url="https://example-finance.com/tea-ipo-2024",
            snippet="头部茶饮品牌 IPO 招股书的门店与营收数据。",
            domain="example-finance.com",
            publishedAt="2024-08-15",
        ),
    ],
}


def _normalize_domain(url: str) -> str:
    try:
        from urllib.parse import urlparse

        return urlparse(url).netloc.lower()
    except Exception:
        return ""


async def _bing_search(query: str, count: int, api_key: str) -> list[SearchHit]:
    endpoint = os.environ.get("BING_SEARCH_ENDPOINT", "https://api.bing.microsoft.com/v7.0/search")
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            endpoint,
            params={"q": query, "count": count, "mkt": os.environ.get("BING_SEARCH_MARKET", "en-US")},
            headers={"Ocp-Apim-Subscription-Key": api_key},
        )
        resp.raise_for_status()
        data = resp.json()

    hits: list[SearchHit] = []
    for item in (data.get("webPages", {}).get("value", []) or [])[:count]:
        hits.append(
            SearchHit(
                title=item.get("name", ""),
                url=item.get("url", ""),
                snippet=item.get("snippet", ""),
                domain=_normalize_domain(item.get("url", "")),
                publishedAt=item.get("dateLastCrawled", "")[:10] or None,
            )
        )
    return hits


async def _google_cse_search(query: str, count: int, key: str, cx: str) -> list[SearchHit]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            "https://www.googleapis.com/customsearch/v1",
            params={"key": key, "cx": cx, "q": query, "num": min(count, 10)},
        )
        resp.raise_for_status()
        data = resp.json()

    hits: list[SearchHit] = []
    for item in (data.get("items", []) or [])[:count]:
        hits.append(
            SearchHit(
                title=item.get("title", ""),
                url=item.get("link", ""),
                snippet=item.get("snippet", ""),
                domain=_normalize_domain(item.get("link", "")),
                publishedAt=None,
            )
        )
    return hits


def _mock_search(query: str, count: int) -> list[SearchHit]:
    q = query.lower().strip()
    for key, hits in _MOCK_HITS.items():
        if key.lower() in q or q in key.lower():
            return hits[:count]
    return [
        SearchHit(
            title=f"[mock] result for {query}",
            url=f"https://example.com/search?q={query}",
            snippet=f"Mock placeholder. Set BING_SEARCH_API_KEY or GOOGLE_CSE_KEY to enable live search. (today={date.today().isoformat()})",
            domain="example.com",
            publishedAt=date.today().isoformat(),
        )
    ][:count]


@ai_function(
    name="web_search",
    description=(
        "用关键词检索公开网页，返回 top N 条标题/URL/摘要。"
        "市场调研 agent 在不知道目标 URL 时**必须**先调用此工具。"
        "结果中的 url 接着喂给 web_fetch 取正文。"
    ),
)
async def web_search(query: str, count: int = 5) -> WebSearchResult:
    """检索公开网页。

    Args:
        query: 搜索词，中英文均可。要么具体（"消费级 AI 笔记 应用 2025"），要么含品类+维度（"新茶饮市场 份额"）。
        count: 返回结果数，1-10，默认 5。
    """
    count = max(1, min(int(count or 5), 10))
    with tracer.start_as_current_span("web_search") as span:
        span.set_attribute("query", query)
        span.set_attribute("count", count)

        bing_key = os.environ.get("BING_SEARCH_API_KEY")
        google_key = os.environ.get("GOOGLE_CSE_KEY")
        google_cx = os.environ.get("GOOGLE_CSE_CX")
        try:
            if bing_key:
                hits = await _bing_search(query, count, bing_key)
                span.set_attribute("provider", "bing")
                return WebSearchResult(query=query, provider="bing", count=len(hits), results=hits)
            if google_key and google_cx:
                hits = await _google_cse_search(query, count, google_key, google_cx)
                span.set_attribute("provider", "google")
                return WebSearchResult(query=query, provider="google", count=len(hits), results=hits)
        except Exception as exc:
            logger.warning("Live search failed (%s); falling back to mock.", exc)
            span.set_attribute("fallback", "mock")

        hits = _mock_search(query, count)
        span.set_attribute("provider", "mock")
        return WebSearchResult(query=query, provider="mock", count=len(hits), results=hits, cached=True)
