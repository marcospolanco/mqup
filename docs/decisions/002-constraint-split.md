# Decision 002: Hard vs soft constraint split

| Class | Examples | Enforcement |
|-------|----------|-------------|
| Hard | category, `openNow` | Pre-filter before scoring |
| Soft | parking, wifi, outdoor seating | Score × 0.6 per missing attribute |

Hard-filtering all constraints produces brittle empty results on synthetic data. Soft-only lets closed POIs leak through - worse UX than missing parking.

## Status

Implemented in `HybridRanker`.

## First failure-and-fix case study

See `docs/failure-and-fix.md` §1 (closed POI ranked above open POI before temporal hard filter).
