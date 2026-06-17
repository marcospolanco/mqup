# Decision 001: No ANN index

At 2,000 POIs, brute-force cosine over 384-dim vectors completes in sub-millisecond on device. HNSW/FAISS adds operational complexity without measurable demo benefit.

## Status

DEFERRED post-MVP.

## Revisit when

Corpus exceeds ~50k POIs or p95 embedding search exceeds 10ms in profiling.
