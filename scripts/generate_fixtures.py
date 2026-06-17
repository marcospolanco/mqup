#!/usr/bin/env python3
"""Generate scenario fixtures from live coordinator output."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"

SCENARIOS = [
    ("MQUP-GOLDEN-01", "coffee shops with parking open now", "2026-06-16T14:30:00Z", "golden"),
    ("MQUP-PARTIAL-01", "coffee with parking and outdoor seating and wifi", "2026-06-16T14:30:00Z", "partial"),
    ("MQUP-EMPTY-01", "sushi at 4am", "2026-06-16T04:00:00Z", "empty"),
    ("MQUP-AMBIG-01", "place to work", "2026-06-16T14:30:00Z", "ambiguous"),
    ("MQUP-SIMPLE-01", "pizza", "2026-06-16T14:30:00Z", "golden"),
    ("MQUP-LOAD-01", "coffee shops with parking open now", "2026-06-16T14:30:00Z", "loading"),
]


def main() -> None:
    FIXTURES.mkdir(parents=True, exist_ok=True)
    for fixture_id, query, now, expected_state in SCENARIOS:
        payload = {
            "id": fixture_id,
            "query": query,
            "nowISO8601": now,
            "expectedResultsState": expected_state,
            "expectedTop3IDs": [],
            "simulateLoading": expected_state == "loading",
        }
        (FIXTURES / f"{fixture_id}.json").write_text(json.dumps(payload, indent=2))
    print(f"Wrote {len(SCENARIOS)} fixtures to {FIXTURES}")


if __name__ == "__main__":
    main()
