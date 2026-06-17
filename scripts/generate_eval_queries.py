#!/usr/bin/env python3
"""Generate eval/query_templates.json (150 queries; 30 blind hold-out)."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "eval" / "query_templates.json"
NOW = "2026-06-16T14:30:00Z"

# Blind hold-out: fixed before any ranker tuning (spec §8.7.2).
BLIND_TEMPLATES = [
    "coffee shops with parking open now",
    "quiet cafe with wifi",
    "late night food open now",
    "place to work with wifi",
    "retail store with parking",
    "library open now",
    "coworking space with parking",
    "bakery open now",
    "pizza with outdoor seating",
    "sushi restaurant open now",
    "coffee with drive through",
    "grocery with parking open now",
    "food with parking near me",
    "service location with wifi",
    "cafe with outdoor seating open now",
    "coffee shop open now",
    "retail with wifi open now",
    "food open now",
    "coffee with parking and wifi",
    "place to work open now",
    "coffee shops with outdoor seating",
    "food with wifi",
    "retail open now",
    "coffee with parking",
    "service with parking open now",
    "bakery with parking",
    "pizza open now",
    "coffee shops with wifi open now",
    "grocery with wifi",
    "coworking with wifi open now",
]

DEV_TEMPLATES = [
    "coffee shops with parking open now",
    "pizza",
    "coffee with wifi",
    "find bakeries near me",
    "place to work",
    "grocery with parking",
    "library open now",
    "coworking space",
    "retail store with wifi",
    "coffee with outdoor seating",
    "food with parking",
    "coffee open now",
    "sushi at 4am",
]


def main() -> None:
    templates = []
    idx = 1

    for query in BLIND_TEMPLATES:
        templates.append(
            {
                "id": f"Q{idx:03d}",
                "query": query,
                "nowISO8601": NOW,
                "blindHoldout": True,
            }
        )
        idx += 1

    while len(templates) < 150:
        query = DEV_TEMPLATES[(len(templates) - len(BLIND_TEMPLATES)) % len(DEV_TEMPLATES)]
        templates.append(
            {
                "id": f"Q{idx:03d}",
                "query": query,
                "nowISO8601": NOW,
                "blindHoldout": False,
            }
        )
        idx += 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(templates, indent=2))
    print(f"Wrote {len(templates)} templates ({len(BLIND_TEMPLATES)} blind) to {OUT}")


if __name__ == "__main__":
    main()
