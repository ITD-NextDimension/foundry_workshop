"""Refund quote calculator.

Contoso 退款政策 v3.2:
  - Enterprise: pro-rata within 30 days, max 50% of contract value
  - Business:   pro-rata within 14 days, max 25%
  - Free:       no refund

Usage:
    python quote.py --tier Enterprise --amount 100000 --contract-end 2026-12-01 --today 2026-05-14
Output: JSON {maxRefund, policyVersion, capped, explanation}
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime

POLICY_VERSION = "v3.2"

POLICY = {
    "Enterprise": {"window_days": 30, "cap_pct": 0.50},
    "Business":   {"window_days": 14, "cap_pct": 0.25},
    "Free":       {"window_days": 0,  "cap_pct": 0.00},
}


def _parse_date(s: str) -> date:
    return datetime.strptime(s, "%Y-%m-%d").date()


def quote(tier: str, amount: float, contract_end: str | None, today: str | None) -> dict:
    if tier not in POLICY:
        return {
            "maxRefund": 0,
            "policyVersion": POLICY_VERSION,
            "capped": False,
            "explanation": f"Unknown tier '{tier}'. No refund computed.",
        }

    rule = POLICY[tier]

    if rule["cap_pct"] == 0:
        return {
            "maxRefund": 0,
            "policyVersion": POLICY_VERSION,
            "capped": False,
            "explanation": f"Tier '{tier}' has no refund per policy.",
        }

    cap = amount * rule["cap_pct"]

    if contract_end and today:
        today_d = _parse_date(today)
        end_d = _parse_date(contract_end)
        if (end_d - today_d).days < 0:
            return {
                "maxRefund": 0,
                "policyVersion": POLICY_VERSION,
                "capped": False,
                "explanation": f"Contract ended {contract_end}, outside refund window.",
            }

    max_refund = round(cap, 2)
    return {
        "maxRefund": max_refund,
        "policyVersion": POLICY_VERSION,
        "capped": amount > max_refund,
        "explanation": (
            f"Tier '{tier}' allows up to {int(rule['cap_pct'] * 100)}% within "
            f"{rule['window_days']} days; on requested {amount:.2f} → cap {max_refund:.2f}."
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Compute refund quote per Contoso policy v3.2")
    parser.add_argument("--tier", required=True, choices=list(POLICY.keys()))
    parser.add_argument("--amount", required=True, type=float, help="Requested or contract amount")
    parser.add_argument("--contract-end", default=None, help="YYYY-MM-DD")
    parser.add_argument("--today", default=None, help="YYYY-MM-DD (defaults to today)")
    args = parser.parse_args(argv)

    today = args.today or date.today().isoformat()

    result = quote(args.tier, args.amount, args.contract_end, today)
    json.dump(result, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
