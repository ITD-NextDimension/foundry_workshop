"""Classify charges tool — 把 line item 描述映射到费用类目（纯本地规则，无外部依赖）。"""

from __future__ import annotations

import json
import logging
from typing import Literal

from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.classify_charges")
tracer = trace.get_tracer("workshop.tools.classify_charges")

Category = Literal["餐饮", "差旅", "办公", "通讯", "培训", "其他"]


class ChargeItem(BaseModel):
    description: str = Field(min_length=1)
    amount: float = Field(ge=0)
    currency: str = "CNY"


class ClassifiedItem(BaseModel):
    description: str
    amount: float
    currency: str
    category: Category


class ClassifyResult(BaseModel):
    classified: list[ClassifiedItem]
    category_distribution: dict[Category, int]


# ---------------------------------------------------------------------------
# Keyword rules — 命中即归类，按字典定义顺序优先匹配。
# 维护建议：常见关键词 → 添加到对应类目；不命中默认 "其他"。
# ---------------------------------------------------------------------------
_RULES: list[tuple[Category, tuple[str, ...]]] = [
    ("餐饮", (
        "咖啡", "拿铁", "美式", "奶茶", "茶饮", "餐", "饭", "面", "粥", "饼", "披萨", "汉堡",
        "蛋糕", "甜品", "提拉米苏", "可乐", "果汁", "啤酒", "酒水", "外卖", "快餐",
        "starbucks", "coffee", "tea", "meal", "lunch", "dinner", "breakfast", "pizza", "burger",
    )),
    ("差旅", (
        "机票", "高铁", "动车", "火车", "出租车", "滴滴", "网约车", "uber", "lyft",
        "酒店", "民宿", "住宿", "宾馆", "客栈", "airbnb", "hotel", "flight", "taxi", "train",
        "停车", "过路费", "高速", "加油",
    )),
    ("办公", (
        "打印", "复印", "墨盒", "纸张", "a4", "文具", "笔记本", "笔", "订书机", "胶带",
        "电脑配件", "鼠标", "键盘", "显示器", "office", "stapler", "printer",
    )),
    ("通讯", (
        "话费", "流量", "宽带", "电信", "联通", "移动", "wifi", "phone bill", "internet",
    )),
    ("培训", (
        "培训", "课程", "学费", "认证", "考试", "books", "教材", "training", "course",
        "certification", "udemy", "coursera",
    )),
]


def _classify_one(description: str) -> Category:
    desc_lower = description.lower()
    for category, keywords in _RULES:
        for kw in keywords:
            if kw.lower() in desc_lower:
                return category
    return "其他"


@ai_function(
    name="classify_charges",
    description=(
        "把 line item 描述批量归类到费用类目: 餐饮/差旅/办公/通讯/培训/其他。"
        "发票解读 agent 在 OCR 拿到 line items 后**必须整批一次性**调用此工具 (不要逐行调)。"
        "输入是 items 数组 (含 description/amount/currency); 输出每项加上 category 字段 + 类目分布统计。"
    ),
)
async def classify_charges(items: list[dict]) -> ClassifyResult:
    """Classify a batch of charge items into expense categories.

    Args:
        items: 每项含 description (str), amount (float), currency (str, 默认 CNY)。
    """
    with tracer.start_as_current_span("classify_charges") as span:
        # Coerce dicts → pydantic (LLM tool-call payloads arrive as raw dicts).
        parsed = [
            x if isinstance(x, ChargeItem) else ChargeItem.model_validate(x)
            for x in items
        ]
        span.set_attribute("input_count", len(parsed))

        classified: list[ClassifiedItem] = []
        dist: dict[Category, int] = {
            "餐饮": 0, "差旅": 0, "办公": 0, "通讯": 0, "培训": 0, "其他": 0
        }
        for it in parsed:
            cat = _classify_one(it.description)
            classified.append(
                ClassifiedItem(
                    description=it.description,
                    amount=it.amount,
                    currency=it.currency,
                    category=cat,
                )
            )
            dist[cat] += 1

        span.set_attribute("category_distribution", json.dumps(dist, ensure_ascii=False))
        return ClassifyResult(classified=classified, category_distribution=dist)
