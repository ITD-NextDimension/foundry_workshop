"""Web fetch tool — 拉取一个 URL 的可读正文 (mock + 真调用).

真实模式: httpx GET + 简单 HTML 抽取 (去 script/style，截断长度);
mock 模式: 已知 URL 命中本地样本；否则返回占位符。
"""
from __future__ import annotations

import logging
import os
import re
from datetime import date

import httpx
from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.web_fetch")
tracer = trace.get_tracer("workshop.tools.web_fetch")


class FetchResult(BaseModel):
    url: str
    title: str = ""
    text: str = ""
    statusCode: int | None = None
    bytes: int = 0
    truncated: bool = False
    fetchedAt: str = ""
    cached: bool = Field(default=False, description="True 表示命中本地 mock")


_MOCK_PAGES: dict[str, FetchResult] = {
    "https://example-research.com/ai-notes-2025": FetchResult(
        url="https://example-research.com/ai-notes-2025",
        title="The State of AI Note-Taking Apps in 2025",
        text=(
            "Consumer AI note-taking is led by Notion AI (estimated 18M paid seats), "
            "Obsidian (1.5M Sync subscribers), and Mem (undisclosed). Notion grew ~24% YoY "
            "on AI-assist features rolled out in 2024. Obsidian remains community-led with no VC. "
            "Mem pivoted to enterprise in late 2024."
        ),
        statusCode=200,
        bytes=512,
        truncated=False,
        cached=True,
    ),
    "https://example-research.com/cn-tea-2024": FetchResult(
        url="https://example-research.com/cn-tea-2024",
        title="2024 新茶饮赛道白皮书",
        text=(
            "中国新茶饮市场 2024 年规模约 ¥3,547 亿元，同比增长 23%。蜜雪冰城以约 32% 的门店占有率居首，"
            "古茗 / 茶百道 / 沪上阿姨 / 喜茶 紧随其后。下沉市场仍是增长主引擎，2024 年 60% 新开门店位于三线及以下城市。"
        ),
        statusCode=200,
        bytes=640,
        truncated=False,
        cached=True,
    ),
}


_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")
_TITLE_RE = re.compile(r"<title[^>]*>([^<]+)</title>", re.IGNORECASE)
_SCRIPT_RE = re.compile(r"<(script|style|noscript)[^>]*>.*?</\1>", re.IGNORECASE | re.DOTALL)


def _extract_text(html: str, max_chars: int) -> tuple[str, str, bool]:
    title_match = _TITLE_RE.search(html)
    title = (title_match.group(1).strip() if title_match else "")[:300]
    body = _SCRIPT_RE.sub(" ", html)
    body = _TAG_RE.sub(" ", body)
    body = _WS_RE.sub(" ", body).strip()
    truncated = len(body) > max_chars
    return title, body[:max_chars], truncated


@ai_function(
    name="web_fetch",
    description=(
        "拉取一个公开 URL 的可读正文 (去 HTML 标签、限长)，用于在 web_search 命中后获取细节。"
        "返回 title + text + statusCode；过长内容会被截断并设 truncated=true。"
    ),
)
async def web_fetch(url: str, max_chars: int = 4000, timeout: float = 10.0) -> FetchResult:
    """抓取 URL 正文。

    Args:
        url: 要抓的页面 URL，必须 http(s)。
        max_chars: 正文最大保留字符，默认 4000。
        timeout: 网络超时秒数，默认 10。
    """
    today = date.today().isoformat()
    with tracer.start_as_current_span("web_fetch") as span:
        span.set_attribute("url", url)
        span.set_attribute("max_chars", max_chars)

        if not (url.startswith("http://") or url.startswith("https://")):
            raise ValueError(f"web_fetch only supports http(s); got: {url}")

        if os.environ.get("WORKSHOP_WEB_FETCH_FORCE_MOCK") == "1" or url in _MOCK_PAGES:
            r = _MOCK_PAGES.get(url)
            if r is None:
                r = FetchResult(
                    url=url,
                    title="[mock]",
                    text=f"Mock placeholder for {url}. Set WORKSHOP_WEB_FETCH_FORCE_MOCK=0 to enable live fetch.",
                    statusCode=200,
                    bytes=0,
                    truncated=False,
                )
            r = r.model_copy(update={"fetchedAt": today, "cached": True})
            span.set_attribute("source", "mock")
            return r

        try:
            async with httpx.AsyncClient(
                timeout=timeout,
                follow_redirects=True,
                headers={"User-Agent": "foundry-workshop-research-agent/1.0"},
            ) as client:
                resp = await client.get(url)
            title, text, truncated = _extract_text(resp.text, max_chars)
            span.set_attribute("source", "live")
            span.set_attribute("statusCode", resp.status_code)
            return FetchResult(
                url=url,
                title=title,
                text=text,
                statusCode=resp.status_code,
                bytes=len(resp.content),
                truncated=truncated,
                fetchedAt=today,
            )
        except Exception as exc:
            logger.warning("web_fetch failed (%s); returning error stub.", exc)
            span.set_attribute("error", str(exc)[:200])
            return FetchResult(
                url=url,
                title="",
                text=f"[fetch error] {type(exc).__name__}: {exc}",
                statusCode=None,
                bytes=0,
                truncated=False,
                fetchedAt=today,
            )
