# Embedding model

## Committed path (MVP)

| Component | Implementation |
|-----------|----------------|
| **POI vectors** | Precomputed in `data/pois.json` via `scripts/generate_pois.py` (deterministic hash embedding, 384-dim) |
| **Query vectors** | `TextEmbedder.embed(_:)` at runtime - same algorithm as POI generation |
| **Search** | Pre-normalized vectors; top-K partial selection (no full corpus sort) |

This is **not** MiniLM inference. It is a deterministic stand-in that keeps POI and query vectors in the same space for demo and eval reproducibility without bundling a Core ML model.

## Why not Core ML MiniLM in v1?

The original spec called for Core ML conversion of `all-MiniLM-L6-v2`. That path is **staged, not skipped**:

1. **Same embedding dimension (384)** and precomputed POI vectors slot directly into `EmbeddingIndex`.
2. **Query path swap** is isolated to `TextEmbedder.embed` -> Core ML `MLModel` prediction.
3. **Eval harness** (`MQUPEval`) provides before/after comparison on the same 150-query set.

**Rationale:** The retrieval architecture and eval loop were shipped first with a deterministic embedding oracle so BM25 vs hybrid and constraint behavior could be validated independently of model conversion risk. Core ML MiniLM is a drop-in replacement at the query embedding boundary; POI vectors can be regenerated from the same script with `--model minilm`.

## Production path (v2)

- **Model:** `sentence-transformers/all-MiniLM-L6-v2`
- **Conversion:** Core ML (`scripts/convert_model.py` - TODO)
- **A/B:** Run `MQUPEval` with hash vs MiniLM; report delta on blind hold-out

## Deferred

- Apple `NLContextualEmbedding` (iOS 18+) - see spec
