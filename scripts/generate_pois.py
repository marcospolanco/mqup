#!/usr/bin/env python3
"""Deterministic synthetic POI dataset for MQUP (2,000 SF/Cupertino places)."""

from __future__ import annotations

import json
import math
import random
import uuid
from pathlib import Path

DIM = 384
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "pois.json"

CATEGORIES = {
    "coffee": {
        "names": ["Blue Bottle", "Sightglass", "Philz", "Peet's", "Starbucks", "Coupa", "Zola", "Verve"],
        "attrs": ["wifi", "outdoor_seating", "parking", "drive_through"],
    },
    "food": {
        "names": ["Pizza My Heart", "Sushi House", "Taco Bell", "In-N-Out", "Oren's Hummus", "Lazy Dog"],
        "attrs": ["parking", "outdoor_seating", "drive_through"],
    },
    "retail": {
        "names": ["Target", "Whole Foods", "Apple Store", "Best Buy", "Trader Joe's", "Safeway"],
        "attrs": ["parking", "wifi"],
    },
    "service": {
        "names": ["Cupertino Library", "WeWork", "Regus", "24 Hour Fitness", "FedEx Office", "Chase Bank"],
        "attrs": ["wifi", "parking"],
    },
}

DESCRIPTIONS = {
    "coffee": "Neighborhood coffee shop serving espresso drinks and pastries.",
    "food": "Local restaurant with dine-in and takeout options.",
    "retail": "Retail store serving the SF Bay Area community.",
    "service": "Service location with amenities for locals and commuters.",
}


def stable_hash(token: str) -> int:
    h = 5381
    for ch in token:
        h = ((h << 5) + h + ord(ch)) & 0xFFFFFFFFFFFFFFFF
    return h


def embed(text: str) -> list[float]:
    vec = [0.0] * DIM
    lowered = text.lower()
    tokens = [t for t in __import__("re").split(r"[^a-z0-9]+", lowered) if t]
    for token in tokens:
        h = stable_hash(token)
        for _ in range(4):
            idx = h % DIM
            sign = 1.0 if (h & 1) == 0 else -1.0
            vec[idx] += sign
            h = (h * 1103515245 + 12345) & 0xFFFFFFFFFFFFFFFF
    for i in range(max(0, len(lowered) - 2)):
        gram = lowered[i : i + 3]
        h = stable_hash(gram)
        for _ in range(4):
            idx = h % DIM
            sign = 1.0 if (h & 1) == 0 else -1.0
            vec[idx] += sign
            h = (h * 1103515245 + 12345) & 0xFFFFFFFFFFFFFFFF
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


def weekly_hours(rng: random.Random, late_night: bool = False) -> dict[str, list[dict[str, int]]]:
    if late_night:
        open_h, close_h = 0, 23
    else:
        open_h, close_h = 7, 21
    day = {"openHour": open_h, "openMinute": 0, "closeHour": close_h, "closeMinute": 0}
    return {str(d): [day] for d in range(1, 8)}


def generate_poi(rng: random.Random, index: int, category: str, force: dict | None = None) -> dict:
    meta = CATEGORIES[category]
    name_base = meta["names"][index % len(meta["names"])]
    name = f"{name_base} #{index + 1}"
    attrs = set(rng.sample(meta["attrs"], k=rng.randint(1, min(3, len(meta["attrs"])))))
    if force:
        if "attributes" in force:
            attrs = set(force["attributes"])
        if "name" in force:
            name = force["name"]
    # SF / Cupertino bounding box
    lat = 37.30 + rng.random() * 0.25
    lon = -122.15 + rng.random() * 0.20
    late = force.get("late_night", False) if force else False
    desc = DESCRIPTIONS[category]
    if "parking" in attrs:
        desc += " Offers parking."
    if category == "coffee":
        desc += " Specialty coffee and tea."
    text = f"{name} {category} {desc}"
    return {
        "id": str(uuid.UUID(int=index + 1)),
        "name": name,
        "category": category,
        "attributes": sorted(attrs),
        "hours": weekly_hours(rng, late_night=late),
        "latitude": round(lat, 6),
        "longitude": round(lon, 6),
        "description": desc,
        "embedding": embed(text),
    }


def main() -> None:
    rng = random.Random(42)
    pois: list[dict] = []
    per_category = 500

    # Seed golden-path anchors with known ids
    golden_specs = [
        {"category": "coffee", "attributes": ["parking", "wifi"], "name": "Golden Cup SF", "late_night": False},
        {"category": "coffee", "attributes": ["parking", "outdoor_seating"], "name": "Parking Perk Cafe", "late_night": False},
        {"category": "coffee", "attributes": ["parking"], "name": "Commuter Coffee", "late_night": False},
    ]
    for i, spec in enumerate(golden_specs):
        poi = generate_poi(rng, i, spec["category"], force=spec)
        poi["id"] = str(uuid.UUID(int=i + 1))
        pois.append(poi)

    idx = len(pois)
    for category in CATEGORIES:
        count = per_category - (len(golden_specs) if category == "coffee" else 0)
        start = idx if category != "coffee" else len(golden_specs)
        for j in range(count):
            pois.append(generate_poi(rng, idx, category))
            idx += 1

    # Ensure enough open coffee + parking for eval
    for poi in pois:
        if poi["category"] == "coffee" and "parking" in poi["attributes"]:
            poi["hours"] = weekly_hours(rng, late_night=False)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(pois, indent=2))
    print(f"Wrote {len(pois)} POIs to {OUT}")


if __name__ == "__main__":
    main()
