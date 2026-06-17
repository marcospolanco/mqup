# Spec: Maps Query Understanding Prototype (MQUP)

**Status:** READY
**Author:** Marcos Polanco
**Last updated:** 2026-06-16

---

## 1. Overview

### 1.1 What
An on-device iOS prototype that takes natural-language POI queries (e.g., *"coffee shops with parking that are open now"*) and returns ranked results from a local 2,000-POI synthetic SF/Cupertino dataset using a hybrid lexical + semantic retriever. Exposed to Siri and Spotlight via the App Intents framework, with a SwiftUI + MapKit interface and an evaluation harness.

### 1.2 Purpose
Show how compound natural-language POI queries can be served on-device without sending user intent to the cloud, by combining lexical retrieval (BM25) with semantic retrieval (sentence embeddings) under a tunable blend, integrated through App Intents so Siri can invoke the capability natively.

This is a reference implementation for developers learning:
- Hybrid retrieval architectures (BM25 + embeddings)
- Constraint-aware ranking with hard/soft filters
- App Intents and Spotlight integration
- Clean separation between domain logic, presentation, and UI

### 1.3 Target Audience
- **End users**: iPhone users asking natural-language place queries
- **Developers**: Those building on-device search, ranking systems, or Apple platform integrations

---

## 2. Experience Semantics

```markdown
# Experience Semantics: POI Query Understanding

## WHO THEY ARE
Primary persona: iPhone user in transit or planning a short outing
Core job: Find a specific place that satisfies multiple constraints at once
Technical proficiency: Average; expects Siri/Maps to "just understand"

## WHAT THEY BELIEVE THEY ARE DOING
"Asking Maps for the place I want" - NOT "keyword-searching a POI database"

## QUESTIONS THEY WAKE UP ASKING
- Where can I get [X] that also has [Y] and is open [now]?
- Is there a good option that fits all my constraints?
- Did Maps actually understand what I asked for, or did it pattern-match a keyword?

## EMOTIONAL CONTEXT
Mild time pressure (often during commute or trip). Low patience for irrelevant results.
Failure means a wasted detour or abandoning the query and falling back to Google.

## PRIMARY CONCEPTS
- "Places that fit what I asked for"
- "Why this result"
- "Whether all parts of my ask were satisfied"

## SECONDARY CONCEPTS
- BM25 score, embedding score, blend weight
- Intent extraction JSON
- Index internals

## SUCCESS FEELS LIKE
"The first 3 results all match what I asked, including the parts other apps usually ignore."

## FAILURE FEELS LIKE
"It gave me coffee shops but ignored 'with parking' and 'open now.'"

## PRIMARY SCREEN
Results screen: a map with pinned results above a list, each list row showing the place + a one-line "why this matched" explanation.

## PRIMARY ACTION
Tap a result to start navigation. Secondary action: "Why this result?" expander.

## UBIQUITOUS LANGUAGE
| User Term                | Technical Term (never shown) |
|--------------------------|------------------------------|
| Matches what I asked     | Hybrid score above threshold |
| Why this result          | Per-signal score breakdown (lex / sem / constraint) |
| Open now                 | hours.contains(now()) |
| With parking             | attributes.contains("parking") |
| Coffee shops             | category == "coffee" OR semantic_similarity to "coffee shop" > τ |
```

---

## 3. Gherkin Scenarios

### 3.1 Behavioral Gherkin

```gherkin
Feature: Hybrid POI retrieval

Scenario: Compound natural-language query, golden path
  Given a 2000-POI synthetic SF/Cupertino dataset
  And a user query "coffee shops with parking open now"
  When the user submits the query
  Then the top-3 results all have category=="coffee"
  And all top-3 results have "parking" in attributes
  And all top-3 results are open at the current synthetic time
  And nDCG@5 on the labeled eval set is at least 0.10 above BM25-only baseline

Scenario: Single-constraint baseline query
  Given the same dataset
  And a user query "pizza"
  When the user submits the query
  Then results are returned in under 100ms p95
  And Recall@10 on the labeled eval set is at least 0.85

Scenario: App Intents invocation from Siri
  Given the app is installed and entities are donated to Spotlight
  When the user asks Siri "find bakeries near me"
  Then SearchPlacesIntent is invoked with searchQuery="bakeries"
  And the intent returns at least one SpatialVenueEntity
  And the dialog response includes the count of matches

Scenario: Empty result with helpful guidance
  Given a query that cannot be satisfied (e.g., "sushi at 4am")
  When the query is submitted
  Then the result count is zero
  And the UI shows an empty state explaining the constraint that failed
```

### 3.2 Conceptual Gherkin

```gherkin
Scenario: User asks for a multi-constraint result during commute
  Given a commuter is in the car and mildly time-pressured
  When they ask Siri "coffee shops with parking that are open now"
  Then the first 3 results all satisfy all three constraints simultaneously
  And each result row shows a short "why this matched" line in plain language
  And the user is not asked to disambiguate which constraint matters more

Scenario: User receives a result that contradicts one of their constraints
  Given the same user
  When the top result is open but does NOT have parking
  Then the row visually indicates which constraint was satisfied and which was not
  And the result is demoted below any fully-matching result

Scenario: User is curious why a result ranked first
  Given the results screen is showing
  When the user taps "why this result?" on the top item
  Then the system reveals the matched signals in user language (category, attributes, hours)
  And does NOT expose raw BM25 scores, embedding cosine values, or blend weights
```

### 3.3 Cognitive outcome catalog

| Cognitive outcome | Fixture id | Notes |
|-------------------|-----------|-------|
| Golden (all constraints satisfied)  | `MQUP-GOLDEN-01` | Coffee + parking + open now, ≥3 matches |
| Partial (one constraint missed)     | `MQUP-PARTIAL-01` | Coffee + parking, no place open now |
| Empty (no matches possible)         | `MQUP-EMPTY-01`   | Sushi at 4am |
| Ambiguous category                  | `MQUP-AMBIG-01`   | "Place to work" (cafe? library? coworking?) |
| Single-token query                  | `MQUP-SIMPLE-01`  | "pizza" |
| Loading                              | `MQUP-LOAD-01`    | Same as golden + simulated 200ms delay |

---

## 4. Architecture

### 4.0 Runtime traceability

```
User → SwiftUI search bar
     → SearchCoordinator.submit(query:)
     → QueryIntentExtractor.extract(text:) -> QueryIntent
     → HybridRanker.rank(intent: QueryIntent, k: 10) -> [RankedResult]
          ├─ HybridRanker.applyHardFilters(intent:candidates:) -> [POI]
          ├─ BM25Index.search(tokens:) -> [LexicalHit]
          ├─ EmbeddingIndex.search(vector:) -> [SemanticHit]
          ├─ HybridRanker.blend(lex:sem:weights:) -> [RankedResult]
          └─ HybridRanker.applySoftDemotion(intent:results:) -> [RankedResult]
     → SearchCoordinator.classifyAmbiguity(results:) -> ResultsState
     → buildSearchResultsView(intent:results:state:now:latencyMs:) -> SearchResultsView
     → SearchResultsScreen(viewModel: SearchResultsView)
     → MapKit pins + List rows
     → tap result → MKMapItem.openInMaps(launchOptions:) -> Apple Maps

Siri/Spotlight path:
SiriAI → SearchPlacesIntent.perform()
       → SearchCoordinator.submit(query:)
       → buildSearchResultsView(...)
       → buildSiriDialog(from: SearchResultsView)
       → IntentResult(dialog:entities:)

Donation path:
SpatialVenueEntity → CSSearchableIndex.default().indexAppEntities(...)
```

### 4.1 Contract Types

| Contract | Purpose | Types |
|----------|---------|-------|
| **Domain contract** | Engine outputs | `QueryIntent`, `RankedResult`, `EvaluationReport`, `LexicalHit`, `SemanticHit` |
| **Presentation contract** | UI view models | `SearchResultsView`, `ResultRowView`, `EmptyStateView`, `buildSearchResultsView(...)` |
| **Render contract** | SwiftUI views | `SearchResultsScreen(viewModel:)`, `ResultRow(viewModel:)` |

The render layer imports presentation types only. No SwiftUI file imports domain types directly. Enforced by architecture test (SEM-011).

### 4.2 Domain Type Schemas

```swift
// Domain/POI.swift
struct POI: Equatable, Identifiable {
    let id: UUID
    let name: String
    let category: String                  // "coffee", "food", "retail", "service"
    let attributes: Set<String>           // "parking", "outdoor_seating", "wifi"
    let hours: WeeklySchedule
    let latitude: Double
    let longitude: Double
    let description: String
}

struct WeeklySchedule: Equatable {
    let hours: [Weekday: [TimeRange]]
    func isOpen(at: Date, calendar: Calendar = .current) -> Bool
}

enum Weekday: Int, CaseIterable { case sun=1, mon, tue, wed, thu, fri, sat }

// Domain/QueryIntent.swift
struct QueryIntent: Equatable {
    let rawText: String
    let categories: [String]
    let requiredAttributes: Set<String>
    let preferredAttributes: Set<String]
    let temporalConstraint: TemporalConstraint?
    let extractorConfidence: Double
}

enum TemporalConstraint: Equatable {
    case openNow
    case openAt(Date)
    case openOn(Weekday)
}

// Domain/RankedResult.swift
struct RankedResult: Equatable {
    let poi: POI
    let blendedScore: Double
    let lexicalScore: Double
    let semanticScore: Double
    let constraintsSatisfied: Set<String>
    let constraintsMissed: Set<String>
}
```

### 4.3 Constraint Enforcement

| Constraint class | Examples | Enforcement |
|------------------|----------|-------------|
| **Hard** | category, temporal (`openNow`) | Pre-filter; excluded from results |
| **Soft** | attributes (parking, wifi) | Score demotion ×0.6 per missing |

Rationale: Hard-filtering all constraints creates zero-result UX. Soft-only lets closed places leak through. See `docs/decisions/002-constraint-split.md`.

### 4.4 Ambiguity Detection

Returns `.ambiguous` when:
- Top-5 results span 3+ distinct categories, AND
- No single category exceeds 40% of top-5

---

## 5. Implementation Plan

### 5.1 Phase 1 - Data & Infrastructure

- 2,000 synthetic POIs (SF/Cupertino) in `data/pois.json`
- SQLite FTS5 for BM25 (k1=1.2, b=0.75)
- Evaluation harness skeleton (30 queries → 150)
- CI: tests + eval on every push

### 5.2 Phase 2 - Retrieval Engines

- Embedding model: deterministic 384-dim vectors (Core ML MiniLM staged, see `models/README.md`)
- `EmbeddingIndex`: brute-force cosine
- `HybridRanker`: α-blend, tuned on dev split
- `QueryIntentExtractor`: rules-based (category, time, attributes)

### 5.3 Phase 3 - Iteration

- Expand eval set to 150 queries
- Document 3-5 failure cases in `docs/failure-and-fix.md`:
  - Query, wrong result, diagnosis, fix, before/after metrics

### 5.4 Phase 4 - Integration

- `SpatialVenueEntity`, `SearchPlacesIntent`
- `entities(for matching:)` backed by ranker
- Spotlight donation on launch + result tap
- Navigation handoff via `MKMapItem.openInMaps`

### 5.5 Phase 5 - Presentation

- `SearchResultsView`, `ResultRowView`, `EmptyStateView`
- `buildSearchResultsView()` builder
- `buildSiriDialog()` for Siri
- SwiftUI renderer (SEM-011 enforced)

### 5.6 Deferred

| Capability | Rationale |
|------------|-----------|
| Corridor ranking | Navigation Services domain |
| PMTiles | MapKit sufficient |
| PCC simulation | Beyond scope |
| Foundation Models intent | Rules-based committed |
| NLContextualEmbedding | iOS 18+ only |
| ANN index | 2K vectors too small |

---

## 6. Entry Gates

- [x] All acceptance criteria explicit
- [x] Each capability has verification method
- [x] No TBD/TODO placeholders
- [x] Dependencies listed (iOS 17+, Swift 5.9, Xcode 15.4+)
- [x] File paths specified
- [x] Data models defined
- [x] Integration points identified
- [x] Runtime traceability complete
- [x] Presentation contract defined

---

## 7. Test Plan

### 7.1 Unit Tests

| Test ID | Module | Assertion |
|---------|--------|-----------|
| MQUP-U-001 | `BM25Index` | Monotonically decreasing scores |
| MQUP-U-002 | `EmbeddingIndex` | Cosine symmetric, sim(v,v)=1.0 |
| MQUP-U-003 | `HybridRanker` | α=1.0 = BM25-only, α=0.0 = embedding-only |
| MQUP-U-004 | `QueryIntentExtractor` | "coffee shops with parking open now" → category, attributes, temporal |
| MQUP-U-005 | `Builder` | Fixtures produce expected states |
| MQUP-U-006 | `HybridRanker` | Hard filter removes closed POIs |
| MQUP-U-007 | `HybridRanker` | Soft demotion ×0.6 for missing attributes |
| MQUP-U-008 | `SearchCoordinator` | Ambiguity: 3+ categories, none >40% |

### 7.2 Integration Tests

| Test ID | Assertion |
|---------|-----------|
| MQUP-I-001 | Golden path returns top-3 satisfying all constraints |
| MQUP-I-002 | App Intents returns ≥1 entity |
| MQUP-I-003 | Spotlight donation queryable |
| MQUP-I-004 | UI doesn't import domain types (SEM-011) |

### 7.3 Evaluation Tests

| Test ID | Metric | Criterion |
|---------|--------|-----------|
| MQUP-E-001 | nDCG@5 | Hybrid ≥ BM25 + 0.10 |
| MQUP-E-002 | Recall@10 | ≥ 0.85 |
| MQUP-E-003 | p95 latency | < 100ms |
| MQUP-E-004 | No regression | Failure-and-fix doesn't regress non-target queries |

---

## 8. Quality Gates

### 8.1 Implementation
- [ ] No TODOs on golden path
- [ ] Hybrid retrieval verified (BM25 + embedding)
- [ ] Failure-and-fix documented

### 8.2 Acceptance
- [ ] All tests pass
- [ ] Eval thresholds met or documented
- [ ] Limitations in README

### 8.3 Dependencies
- [ ] No new deps beyond spec
- [ ] Core ML docs in place

### 8.4 Cross-Reference
- [ ] README matches capabilities
- [ ] No deferred claimed complete

---

## 9. Risk Analysis

| Risk | Mitigation |
|------|------------|
| Synthetic data doesn't reflect real world | Document; commit to real-data eval |
| Eval queries biased toward system | Blind hold-out set |
| Scope creep | DEFERRED list is contract |
| Latency exceeds 100ms | Profile; 2K brute-force is fast |
| Presentation drift (UI imports domain) | SEM-011 test in CI |

---

## 10. Deferred Technical Debt

No geospatial index (S2/R-tree); no ANN; no on-device LLM; no cloud escalation; no corridor mode. See `docs/decisions/`.
