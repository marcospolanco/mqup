# Maps Query Understanding Prototype — resume bullet

> **Maps Query Understanding Prototype** (iOS, Swift). Built an on-device hybrid lexical + semantic POI retrieval system over a 2,000-place synthetic SF/Cupertino dataset. Combined BM25 (SQLite FTS5) with deterministic sentence embeddings (MiniLM-compatible pipeline; Core ML conversion staged); tuned blend weight α=0.55 on a 120-query dev split; evaluated on 150 labeled natural-language queries including a 30-query blind hold-out. Hybrid retrieval improved **nDCG@5 by 0.55 absolute** over the BM25-only baseline at **4.7ms p95** on-device (macOS release harness; re-measure on iPhone 14+ before interview). Integrated with App Intents (`SpatialVenueEntity` + `SearchPlacesIntent`) and donated entities to Spotlight for Siri invocation. Authored a documented failure-and-fix series for 3 representative ranking errors with before/after metrics.

Numbers sourced from `metrics.json` after §6 exit-gate eval pass (2026-06-16).
