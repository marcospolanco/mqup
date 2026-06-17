# MQUP Guided Walkthrough

This document is meant to sit next to you while you run MQUP. It explains what to click, what to type, what you should see, and what each part of the prototype is proving.

MQUP is a small Maps Search Intelligence prototype. You ask for places in natural language, such as `coffee shops with parking open now`. The app turns that sentence into an intent, searches a local synthetic POI dataset, ranks results with BM25 plus deterministic embeddings, and shows a MapKit/list experience with plain-language match explanations.

The most useful way to understand it is to use one query all the way through, then try the edge cases.

## 1. Start Here

From the repo root:

```bash
xcodegen generate
open MQUP.xcodeproj
```

In Xcode:

1. Select the `MQUP` app target.
2. Set your Development Team if Xcode asks for signing.
3. Choose an iPhone simulator or device.
4. Press Run.

If you only want to verify the engine and metrics without launching iOS:

```bash
./start.sh
```

That builds the Swift package, runs tests, and writes `metrics.json`.

## 2. The First Screen

When the app opens, it runs the default query:

```text
coffee shops with parking open now
```

Read the screen from top to bottom:

| Screen area | What it means |
|-------------|---------------|
| Search field | The natural-language query you are asking MQUP to understand. |
| Primary question | The app's interpretation, usually `Places that match: ...`. This is the first thing to check. |
| Map | Pins for the returned places. The top result is visually distinguished. |
| Result rows | Ranked places. Each row says why it matched in user language. |
| `Why this result?` | Expands a row to show matched and missed constraints. |
| `Go` | Hands the place to Apple Maps using `MKMapItem.openInMaps`. |
| Debug latency | In debug builds, shows total query time in milliseconds. |

The first question to ask yourself is not "Did it find coffee?" It is:

```text
Did MQUP understand every part of my ask?
```

For the default query, the parts are:

- `coffee`
- `parking`
- `open now`

The top rows should satisfy all three.

## 3. Walk The Golden Path

Type this query:

```text
coffee shops with parking open now
```

What should happen:

1. The primary question should read like `Places that match: coffee, parking, open now`.
2. Results should be coffee places.
3. The returned places should include parking.
4. Closed places should not appear, because `open now` is a hard time filter.
5. Each row should show a short explanation, such as `Matched: coffee, open now, parking`.

What this demonstrates:

- `QueryIntentExtractor` recognizes category, attribute, and time language.
- `HybridRanker` hard-filters category and open-now constraints.
- `HybridRanker` blends BM25 and embedding scores.
- `SearchResultsBuilder` turns engine output into user-facing screen text.
- `SearchResultsScreen` renders only the view model.

The main code path is:

```text
SearchCoordinator.submit(query:)
  -> QueryIntentExtractor.extract(text:)
  -> HybridRanker.rank(intent:now:k:)
  -> SearchResultsBuilder.buildSearchResultsView(...)
  -> SearchResultsScreen(viewModel:)
```

When this works, MQUP is doing the core job in the spec: satisfying multiple constraints at once instead of just keyword-matching `coffee`.

## 4. Understand The Result Row

A result row has three jobs.

First, it names the place.

Second, it explains the match in plain language. This is intentionally not a score dump. A user should see `Matched: coffee, parking, open now`, not BM25 values or embedding cosine values.

Third, it lets you inspect partial misses. Tap `Why this result?`. If any constraint was missed, the expanded section should say so with text like:

```text
Did not match: wifi
```

This matters because the product promise is not just "rank something." The product promise is "show me whether this place fits what I asked for."

## 5. Try The Core Scenarios

Use these queries as a guided tour.

| Scenario | Query | What to look for |
|----------|-------|------------------|
| Golden path | `coffee shops with parking open now` | Top results satisfy coffee, parking, and open-now together. |
| Simple query | `pizza` | The extractor maps pizza to food and returns a normal ranked list. |
| Attribute-heavy query | `coffee with parking and outdoor seating and wifi` | Use the row expander to check which attributes each result matched. In the current fixtures this resolves as `golden`, so treat it as a stress test for attributes rather than a guaranteed partial state. |
| Empty result | `sushi at 4am` | The empty state should explain that no place matches all requested constraints and suggest relaxing the time constraint. |
| Ambiguous phrase | `place to work` | This explores coffee/service/retail ambiguity. The fixture now expects `ambiguous`, and rows should show category badges. |

The fixture files in `fixtures/` record the expected state and top IDs for these scripted scenarios.

## 6. How To Think About Constraints

MQUP splits constraints into two behaviors.

Hard constraints remove places before scoring:

- category, such as `coffee`
- temporal constraints, such as `open now`

Soft constraints demote places but can leave them visible:

- `parking`
- `outdoor seating`
- `wifi`
- `drive through`

Why this split exists:

If every attribute were a hard filter, many realistic queries would collapse to an empty screen. If every constraint were soft, closed places could appear for `open now`, which feels worse to a user. The current design says time and category are strict, while amenities can be ranked and explained.

There is one implementation detail worth knowing: `HybridRanker.applyHardFilters` can also enforce `requiredAttributes`, but the current extractor puts normal attribute words into `preferredAttributes`, so user queries like `with parking` follow the soft-demotion path.

## 7. Empty Results

Type:

```text
sushi at 4am
```

What to look for:

1. No map/list results.
2. A plain explanation like `No places match all of: food, open now`.
3. A suggestion like `Try without 'open now'`.

This is the prototype's recovery behavior. It should not expose technical language like BM25, embedding, alpha, ranker, or cosine. Empty states should help the user decide what to loosen.

## 8. Navigation Handoff

Tap `Go` on a result row.

MQUP should open Apple Maps for that POI using the row's latitude and longitude. This is intentionally a handoff. MQUP is demonstrating search understanding, not route planning or navigation.

The relevant UI call is in `MQUPApp/UI/SearchResultsScreen.swift`, which calls `NavigationLauncher.openInMaps(...)`.

## 9. Siri And Spotlight: What Exists Today

The code includes an App Intent:

```text
SearchPlacesIntent
```

The intent calls the same search service as the app and builds its spoken response with:

```text
SearchResultsBuilder.buildSiriDialog(from:)
```

That is the right architecture: Siri and the UI share the same interpretation and vocabulary.

Current implementation:

`SpatialVenueQuery` supports identifier lookup, suggested entities, and string matching through `entities(matching:)`. `POIService` donates suggested entities on app bootstrap, donates search results after each query, and donates the selected result before handing off to Apple Maps.

Use Shortcuts to invoke `SearchPlacesIntent` directly. The code path is wired; a recorded Hey Siri demo or device-level Spotlight query capture is still useful if you want external proof for an interview.

## 10. Reading The Code While You Use The App

When something on screen surprises you, follow this map.

| Question | Start here |
|----------|------------|
| Why did the app understand this query that way? | `Sources/MQUPEngine/Retrieval/QueryIntentExtractor.swift` |
| Why is this result included or excluded? | `Sources/MQUPEngine/Retrieval/HybridRanker.swift` |
| Why is this result above another? | `blend(...)` and `applySoftDemotion(...)` in `HybridRanker.swift` |
| Why does the top banner say that? | `Sources/MQUPEngine/Presentation/SearchResultsBuilder.swift` |
| Why does the row say `Matched: ...`? | `whyThisMatched(...)` in `SearchResultsBuilder.swift` |
| Why does the screen render that way? | `MQUPApp/UI/SearchResultsScreen.swift` and `MQUPApp/UI/ResultRow.swift` |
| What does Siri say? | `buildSiriDialog(from:)` in `SearchResultsBuilder.swift` |

This split is one of the main engineering points of the project. Search logic, presentation language, and SwiftUI rendering are separate enough that you can inspect them independently.

## 11. Metrics Without Fooling Yourself

Run:

```bash
./start.sh
```

Then open:

```text
metrics.json
```

The metrics file reports nDCG@5, Recall@10, p95 latency, and tuned alpha. Treat these as useful prototype instrumentation, not production-grade relevance proof.

Important caveats:

- Latency is measured by the macOS release harness, not an iPhone device.
- The embedding implementation is a deterministic 384-dimensional stand-in, not Core ML MiniLM.
- Eval labels are constraint-based and frozen before alpha tuning. They are still synthetic, not human-labeled production relevance judgments.

The honest interview framing is:

```text
I built the architecture and harness to make ranking measurable. For this synthetic corpus, labels are prototype-aligned; for production, I would use human or behavior-derived relevance labels and keep a true blind holdout.
```

## 12. A Five-Minute Demo Script

Use this when you want to explain MQUP to someone else.

1. Open the app and show the default query: `coffee shops with parking open now`.
2. Point at the primary question and say: "This is the app's interpretation of the ask."
3. Point at the top rows and say: "The first results satisfy category, amenity, and open-now together."
4. Expand `Why this result?` and show matched constraints.
5. Run `sushi at 4am` and show the empty state.
6. Run `pizza` and show the simpler baseline query.
7. Open the code path from `SearchCoordinator` to `HybridRanker` to `SearchResultsBuilder`.
8. Be explicit about caveats: deterministic embeddings, macOS latency numbers, and synthetic relevance labels.

That is the clearest story: MQUP is not a full Maps clone. It is a compact demonstration of natural-language POI query understanding, constraint-aware ranking, user-language result explanation, and an evaluation loop.
