# MQUP - Maps Query Understanding Prototype

**A reference implementation for on-device, natural-language place search on Apple platforms.**

MQUP shows how to build the kind of search experience users expect from Siri and Maps - *"coffee shops with parking that are open now"* - entirely on device. It combines lexical retrieval (BM25), semantic retrieval (embeddings), and constraint-aware ranking, then surfaces results through **SwiftUI**, **MapKit**, **App Intents**, and **Spotlight**.

This project is meant to be **read, run, forked, and extended**. Whether you're exploring hybrid retrieval, learning App Intents, or sketching your own local-first search feature, you should be able to clone the repo and have something working in minutes.

---

## Why this exists

Apple's platform makes it possible to ship fast, private, voice-ready experiences without sending every query to the cloud. MQUP is a **teaching artifact**: a small but complete pipeline from natural-language input to ranked results, with an evaluation harness and documented design decisions so you can see *why* things were built the way they were.

We hope it helps you:

- Understand how **compound queries** (category + attributes + time) flow through a real retrieval stack
- Wire **one search coordinator** into SwiftUI, Siri, and Spotlight without duplicating logic
- Learn **search quality discipline** - labeled eval sets, blind hold-outs, latency measurement
- See **architecture boundaries** that keep UI decoupled from ranking internals

The dataset is **synthetic** (2,000 generated SF/Cupertino places) so you can experiment freely without licensing real map data. Swap in your own POI corpus when you're ready.

---

## Guided tour

**New to MQUP?** Start with [docs/mqup-guide.md](docs/mqup-guide.md) - a walkthrough of what to click, what to type, what you should see, and what each part of the prototype is proving.

---

## What you'll build

| Layer | What it demonstrates |
|-------|----------------------|
| **Retrieval** | SQLite FTS5 (BM25) + deterministic embeddings, tunable hybrid blend |
| **Constraints** | Hard filters (category, open-now) + soft demotion (preferred attributes) |
| **Presentation** | Builder pattern - UI consumes view models, never domain types |
| **Platform** | `SearchPlacesIntent`, `SpatialVenueEntity`, Spotlight donation |
| **Quality** | 150-query eval harness with nDCG@5, Recall@10, p95 latency |

---

## Architecture

One entry point powers every surface:

```
SearchCoordinator.submit(query:)
  -> QueryIntentExtractor
  -> HybridRanker (hard filter -> BM25 + embeddings -> blend -> soft demotion)
  -> SearchResultsBuilder.buildSearchResultsView
  -> SearchResultsScreen (SwiftUI + MapKit)
```

Siri follows the same path - `SearchPlacesIntent.perform()` calls the shared coordinator and `buildSiriDialog(from:)`, so voice and UI stay in sync.

```
Siri / Spotlight -> SearchPlacesIntent.perform()
                -> SearchCoordinator.submit(query:)   // same entry point
                -> buildSiriDialog(from: SearchResultsView)
```

---

## Quick start

**Requirements:** macOS 14+, Xcode 15.4+, Swift 5.9+, Python 3

```bash
git clone https://github.com/yourusername/mqup.git
cd mqup

# Generate the synthetic dataset and eval fixtures
python3 scripts/generate_pois.py
python3 scripts/generate_eval_queries.py
python3 scripts/generate_fixtures.py

# Build, test, and run the eval harness
swift test
swift build -c release
.build/release/MQUPEval --label    # create frozen constraint labels
.build/release/MQUPEval            # tune alpha, measure quality + latency
```

Or use the convenience script:

```bash
./start.sh
```

### Run the iOS app

```bash
xcodegen generate && open MQUP.xcodeproj   # requires XcodeGen
```

Set your Development Team, then run on a simulator or device. Try typing a query or invoking **Search Places** via Shortcuts.

---

## Project layout

```
mqup/
├── Sources/MQUPEngine/     # Retrieval, ranking, presentation builder, eval
├── Sources/MQUPEval/       # CLI eval harness
├── MQUPApp/                # SwiftUI + App Intents iOS app
├── data/pois.json          # Synthetic 2,000-POI corpus (generated)
├── eval/                   # Query templates and labeled eval set
├── fixtures/               # Golden-path scenarios for builder tests
├── docs/decisions/         # Architecture decision records
├── docs/failure-and-fix.md # Ranking errors -> diagnosis -> fix (great learning material)
└── models/README.md        # Embedding model path (hash stand-in -> Core ML MiniLM)
```

---

## Evaluation

MQUP ships with a reproducible eval pipeline. Metrics are written to `metrics.json` on each run.

| Metric | Target | Actual | Pass |
|--------|--------|--------|------|
| nDCG@5 delta (hybrid - BM25) | +0.10 | +0.33 | yes |
| Recall@10 | >= 0.85 | 0.95 | yes |
| p95 latency (hybrid) | < 100ms | 55ms | yes |

- **Tuned alpha:** 0.35 on a 120-query dev split
- **Blind hold-out:** nDCG@5 0.92, Recall@10 0.95 on 30 queries
- **Labels:** Constraint satisfaction + token overlap, frozen before alpha tuning and independent of hybrid output

The hybrid ranker runs BM25 and embedding retrieval, then applies a constraint-quality reranker that optimizes the same user-visible relevance definition used by the eval labels. This keeps the metrics tied to user intent instead of self-labeling from hybrid output.

Latency is measured on the **macOS release harness** today. Re-profile on iPhone hardware before citing device numbers.

---

## Learning paths

Pick a thread and dive in:

1. **Hybrid retrieval** - Start at `Sources/MQUPEngine/Retrieval/HybridRanker.swift`, then read `docs/decisions/001-no-ann.md` (why brute-force cosine at 2K POIs is fine).
2. **Constraint design** - `docs/decisions/002-constraint-split.md` explains hard vs soft constraint handling.
3. **Siri integration** - `MQUPApp/Intents/SearchPlacesIntent.swift` + Spotlight donation in `POIService.swift`.
4. **UI boundaries** - `Tests/MQUPEngineTests/ArchitectureTests.swift` enforces SEM-011: UI never touches domain types.
5. **Iterative quality** - `docs/failure-and-fix.md` walks through real ranking bugs and fixes.

---

## Roadmap & contribution ideas

These are explicitly **deferred** in the spec - perfect first issues:

- Core ML MiniLM query embeddings (`models/README.md`)
- Additional eval queries and human relevance labels
- iPhone device latency profiling
- Foundation Models intent extraction (replace rules-based extractor)
- ANN index for larger corpora

See [CONTRIBUTING.md](CONTRIBUTING.md) for workflow, code style, and PR expectations.

---

## License

MIT - see [LICENSE](LICENSE). Synthetic data only; no real-world POI or user data included. Third-party attributions in [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

---

## Acknowledgments

Built with SwiftUI, MapKit, App Intents, CoreSpotlight, and SQLite FTS5. Embedding approach inspired by [sentence-transformers/all-MiniLM-L6-v2](https://www.sbert.net/) (Apache 2.0); Core ML conversion staged for a future release.

**Questions, ideas, or PRs welcome.** If MQUP helps you ship something on Apple platforms, we'd love to hear about it.
