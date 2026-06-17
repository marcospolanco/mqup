# Failure-and-fix iteration

Documented ranking errors with before/after metrics. Expand during Day 3 of the build window.

## 1. Closed POI ranked above open POI (temporal leak)

**Query:** `coffee shops with parking open now`

**Wrong result:** Top result was a high-BM25 coffee shop that was closed at the synthetic eval timestamp.

**Diagnosis:** Temporal constraint was soft-demoted instead of hard-filtered.

**Fix:** Moved `openNow` to hard pre-filter in `HybridRanker.applyHardFilters`.

**Metrics:** nDCG@5 on temporal queries +0.04; no regression on non-temporal subset.

---

## 2. Keyword-heavy POI outranked semantic match (α too high)

**Query:** `place to work`

**Wrong result:** Retail POI with "work" in description beat coworking/library matches.

**Diagnosis:** α=0.7 overweighted BM25 token overlap on description field.

**Fix:** Tuned α on 120-query dev split (final α=0.40); added category interleaving for multi-category intents.

**Metrics:** nDCG@5 on ambiguous queries +0.03.

---

## 3. Missing parking not visible in partial state

**Query:** `coffee with parking and outdoor seating`

**Wrong result:** Top row had parking but not outdoor seating; UI showed golden styling.

**Diagnosis:** `constraintsMissed` listed only category misses for multi-category intents; attribute misses not surfaced.

**Fix:** Attribute misses always populate `constraintsMissed`; builder shows partial badge.

**Metrics:** Builder fixtures `MQUP-PARTIAL-01` passes; no full-eval regression.

---

## 4. Eval label misalignment (fixed 2026-06-16)

**Query:** Templates with `#0` suffixes and static category labels.

**Wrong result:** Recall@10 ≈ 2%; nDCG delta +0.034; p95 145ms (debug).

**Diagnosis:** Labels listed 20 category UUIDs unrelated to ranker top-10; debug build inflation; α not tuned.

**Fix:** `ConstraintRelevanceLabeler` — constraint satisfaction + token-overlap gold labels, frozen before α tuning (no hybrid oracle, no re-label after tune).

**Metrics:** Honest labels: Recall@10 ~0.12, nDCG delta ~+0.01 (see `metrics.json`). Previous oracle labels inflated recall to ~1.0.

---

## 5. Resume bullet drift (fixed 2026-06-16)

**Wrong result:** `docs/resume-bullet.md` cited α=0.55 and BM25-only latency while `metrics.json` reported α=0.40 and hybrid p95.

**Diagnosis:** Manual doc edits after re-tuning; no single source of truth.

**Fix:** `ResumeBulletGenerator` — `MQUPEval` regenerates `docs/resume-bullet.md` from measured output every run.

**Metrics:** N/A (documentation integrity).

---

## 6. Spotlight donation unwired (fixed 2026-06-16)

**Wrong result:** `POIService.donateEntities` existed but was never called; `SpatialVenueQuery` lacked `entities(matching:)`.

**Fix:** Donate on bootstrap, after search, and on result tap; added `EntityStringQuery` matching backed by ranker.

---

## 7. Ambiguity shortcut violated spec (fixed 2026-06-16)

**Wrong result:** Multi-category intents marked ambiguous without 40% max-share check.

**Fix:** Removed early shortcut in `classifyResultsState`; only `classifyAmbiguity` applies.

---

## 8. Architecture test too narrow (fixed 2026-06-16)

**Fix:** `ArchitectureTests` scans UI files for forbidden domain tokens (word-boundary), not just impossible imports.

---

## 9. Fixture tests skipped top-3 IDs (fixed 2026-06-16)

**Fix:** `BuilderTests` asserts `expectedTop3IDs` when present in fixtures.
