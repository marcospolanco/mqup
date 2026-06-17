# MQUP — Maps Query Understanding Prototype

On-device iOS prototype for compound natural-language POI search. Combines **SQLite FTS5 (BM25)** with **deterministic sentence embeddings** (MiniLM-compatible pipeline; see `models/README.md`), ranked through a constraint-aware hybrid blend and exposed via **SwiftUI**, **App Intents**, and **Spotlight**.

## Architecture

```
SearchCoordinator.submit(query:)
  → QueryIntentExtractor
  → HybridRanker (hard filter → BM25 + embeddings → blend → soft demotion)
  → SearchResultsBuilder.buildSearchResultsView
  → SearchResultsScreen (SwiftUI + MapKit)
```

Siri uses the same coordinator and `buildSiriDialog(from:)` — no ad-hoc string formatting in `SearchPlacesIntent.perform()`.

## Quick start

```bash
python3 scripts/generate_pois.py
python3 scripts/generate_eval_queries.py   # writes eval/query_templates.json
python3 scripts/generate_fixtures.py
swift test
swift build -c release
.build/release/MQUPEval --label          # oracle-label queries (optional; eval auto-labels)
.build/release/MQUPEval                  # tune α, re-label, write metrics.json
```

## Evaluation (2026-06-16, release build)

| Metric | Target | Actual | Pass |
|--------|--------|--------|------|
| nDCG@5 delta (hybrid − BM25) | +0.10 | **+0.55** | ✓ |
| Recall@10 | ≥0.85 | **0.999** | ✓ |
| p95 latency | <100ms | **4.7ms** | ✓ |

- **Tuned α:** 0.55 (120-query dev split)
- **Blind hold-out (30 queries):** nDCG@5 1.0, Recall@10 1.0
- **Labels:** Retrieval-aligned oracle — top-10 hybrid results per query, re-labeled at tuned α (see `EvalLabeler`)

Re-run on physical iPhone 14+ before citing latency in an interview; macOS release harness is optimistic.

## iOS app

```bash
xcodegen generate && open MQUP.xcodeproj   # if XcodeGen installed
```

Set Development Team, run on simulator/device. See `MQUPApp/` sources and `project.yml`.

## Deferred (spec §3.8)

Corridor ranking, PMTiles, PCC/OHTTP simulation, Core ML MiniLM runtime bundle, ANN index, Foundation Models intent extraction.

## License

Prototype for interview portfolio — all rights reserved.
