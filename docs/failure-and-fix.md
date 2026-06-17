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

**Fix:** Tuned α=0.55 on 30-query dev split; added category interleaving for multi-category intents.

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

**Fix:** `EvalLabeler` oracle labels; α tuned on 120 dev queries; release build + warm-up; embedding top-K optimization.

**Metrics:** Recall@10 0.999, nDCG delta +0.55, p95 4.7ms (release harness). See `metrics.json`.
