# Attributions

MQUP incorporates and builds upon the following works:

## Models & Embeddings

- **all-MiniLM-L6-v2** — Sentence embedding model by [sentence-transformers](https://www.sbert.net/)
  - License: Apache 2.0
  - Used for: 384-dimensional sentence embeddings (Core ML conversion staged for v2)
  - See: `models/README.md`

## Database

- **SQLite FTS5** — Full-text search extension
  - Public domain
  - Used for: BM25 lexical retrieval with configurable k1, b parameters

## Platform Frameworks

- **SwiftUI** — Apple's declarative UI framework
- **MapKit** — Apple's mapping and annotation framework
- **App Intents** — Apple's intent system for Siri/Spotlight integration
- **CoreSpotlight** — Apple's indexing framework

## Data

Synthetic POI dataset is generated deterministically from scripts in `scripts/`. No real-world data or user PII is included.

## License

MQUP itself is licensed under the MIT License. See [LICENSE](LICENSE) for details.
