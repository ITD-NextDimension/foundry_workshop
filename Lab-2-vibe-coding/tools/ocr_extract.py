"""OCR tool — 从发票图片/PDF URL 抽取文本块。

Backend:
- 真实: Azure Computer Vision Read API (env AZURE_VISION_KEY + AZURE_VISION_ENDPOINT)
- Mock: 固定一张餐饮发票示例（星巴克, 3 行, 总价 ¥87.50），学员无 key 也能跑通。
"""

from __future__ import annotations

import logging
import os
from typing import Literal

import httpx
from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.ocr_extract")
tracer = trace.get_tracer("workshop.tools.ocr_extract")

Source = Literal["mock", "azure"]
Lang = Literal["auto", "zh", "en"]


class OcrBlock(BaseModel):
    bbox: tuple[int, int, int, int] = Field(description="(x, y, width, height) 像素坐标")
    text: str
    confidence: float = Field(ge=0.0, le=1.0)


class OcrResult(BaseModel):
    text: str = Field(description="所有 blocks 文本拼接 (按阅读顺序)")
    blocks: list[OcrBlock]
    pages: int = Field(ge=1)
    source: Source
    cached: bool = Field(default=False, description="True 表示走了 mock")


# ---------------------------------------------------------------------------
# Mock fallback — 固定一张星巴克餐饮发票示例
# ---------------------------------------------------------------------------
_MOCK_BLOCKS: list[OcrBlock] = [
    OcrBlock(bbox=(50, 30, 320, 28), text="星巴克咖啡 (上海陆家嘴店)", confidence=0.97),
    OcrBlock(bbox=(50, 70, 240, 22), text="发票号: INV-2026-0518-001", confidence=0.95),
    OcrBlock(bbox=(50, 100, 200, 22), text="日期: 2026-05-18", confidence=0.96),
    OcrBlock(bbox=(50, 150, 180, 22), text="拿铁咖啡 x1   ¥35.00", confidence=0.94),
    OcrBlock(bbox=(50, 180, 180, 22), text="美式咖啡 x1   ¥30.00", confidence=0.93),
    OcrBlock(bbox=(50, 210, 220, 22), text="提拉米苏 x1   ¥22.50", confidence=0.92),
    OcrBlock(bbox=(50, 260, 200, 26), text="合计: ¥87.50", confidence=0.96),
    OcrBlock(bbox=(50, 290, 220, 22), text="币种: CNY", confidence=0.95),
]
_MOCK_TEXT = "\n".join(b.text for b in _MOCK_BLOCKS)


async def _azure_read(source_url: str, lang: str, timeout: float = 30.0) -> OcrResult:
    """Call Azure Computer Vision Read API (3.2 GA).

    Raises on any HTTP / parse failure; caller catches + falls back to mock.
    """
    key = os.environ["AZURE_VISION_KEY"]
    endpoint = os.environ["AZURE_VISION_ENDPOINT"].rstrip("/")
    submit_url = f"{endpoint}/vision/v3.2/read/analyze"
    if lang != "auto":
        submit_url += f"?language={lang}"
    headers = {"Ocp-Apim-Subscription-Key": key, "Content-Type": "application/json"}

    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.post(submit_url, headers=headers, json={"url": source_url})
        resp.raise_for_status()
        op_url = resp.headers.get("Operation-Location")
        if not op_url:
            raise RuntimeError("Azure CV: missing Operation-Location header")
        # Poll up to ~30s
        for _ in range(15):
            r = await client.get(op_url, headers={"Ocp-Apim-Subscription-Key": key})
            r.raise_for_status()
            data = r.json()
            status = data.get("status")
            if status == "succeeded":
                return _parse_azure_read(data)
            if status == "failed":
                raise RuntimeError(f"Azure CV Read failed: {data}")
            # sleep done via httpx — use asyncio
            import asyncio
            await asyncio.sleep(2.0)
    raise TimeoutError("Azure CV Read polled >30s without 'succeeded'")


def _parse_azure_read(data: dict) -> OcrResult:
    blocks: list[OcrBlock] = []
    pages = data.get("analyzeResult", {}).get("readResults", [])
    for page in pages:
        for line in page.get("lines", []):
            bb = line.get("boundingBox", [0, 0, 0, 0, 0, 0, 0, 0])
            # 8-tuple → (x, y, w, h) 近似
            if len(bb) >= 8:
                x, y = int(bb[0]), int(bb[1])
                w = int(bb[2] - bb[0])
                h = int(bb[7] - bb[1])
            else:
                x = y = w = h = 0
            text_val = line.get("text", "")
            words = line.get("words", [])
            conf = (
                sum(w.get("confidence", 0.0) for w in words) / max(len(words), 1)
                if words else 0.85
            )
            blocks.append(OcrBlock(bbox=(x, y, w, h), text=text_val, confidence=conf))
    return OcrResult(
        text="\n".join(b.text for b in blocks),
        blocks=blocks,
        pages=len(pages),
        source="azure",
    )


@ai_function(
    name="ocr_extract",
    description=(
        "从图片或 PDF URL 抽取文本块。发票解读 agent 在用户给出 source_url 时**必须**第一步调用此工具。"
        "返回逐块的 (bbox, text, confidence) 列表 + 拼接后的完整文本 + 页数 + source (mock/azure)。"
        "无 AZURE_VISION_KEY 时自动走 mock，返回固定一张星巴克餐饮发票示例。"
    ),
)
async def ocr_extract(source_url: str, lang: Lang = "auto") -> OcrResult:
    """OCR an invoice image/PDF and return text blocks.

    Args:
        source_url: 发票图片或 PDF 的可公开访问 URL。
        lang: "auto" | "zh" | "en"。"auto" 让 Azure CV 自动检测。
    """
    with tracer.start_as_current_span("ocr_extract") as span:
        # Avoid logging full URLs that might contain SAS tokens / PII.
        span.set_attribute("lang", lang)
        span.set_attribute("source_url_host", _safe_host(source_url))

        force_mock = os.environ.get("WORKSHOP_OCR_EXTRACT_FORCE_MOCK") == "1"
        has_key = os.environ.get("AZURE_VISION_KEY") and os.environ.get("AZURE_VISION_ENDPOINT")

        if has_key and not force_mock:
            try:
                result = await _azure_read(source_url, lang)
                span.set_attribute("source", "azure")
                span.set_attribute("block_count", len(result.blocks))
                span.set_attribute("pages", result.pages)
                return result
            except Exception as exc:
                logger.warning("Azure CV Read failed (%s); falling back to mock.", exc)
                span.set_attribute("fallback", str(exc)[:160])

        # Mock fallback
        result = OcrResult(
            text=_MOCK_TEXT,
            blocks=_MOCK_BLOCKS,
            pages=1,
            source="mock",
            cached=True,
        )
        span.set_attribute("source", "mock")
        span.set_attribute("block_count", len(result.blocks))
        span.set_attribute("pages", result.pages)
        return result


def _safe_host(url: str) -> str:
    try:
        from urllib.parse import urlparse
        return urlparse(url).netloc.lower()
    except Exception:
        return "?"
