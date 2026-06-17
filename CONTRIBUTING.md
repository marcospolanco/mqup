# Contributing to MQUP

MQUP is a reference implementation for on-device search on Apple platforms. Contributions are welcome!

## Quick Start for Contributors

```bash
# Clone and build
git clone https://github.com/yourusername/mqup.git
cd mqup
swift build

# Run tests
swift test

# Generate data (if missing)
python3 scripts/generate_pois.py
python3 scripts/generate_eval_queries.py
python3 scripts/generate_fixtures.py

# Run evaluation
swift run MQUPEval
```

## What We're Looking For

- **Bug fixes** — Tests, eval, or correctness issues
- **Performance improvements** — Latency, retrieval quality
- **Documentation** — Clarity, examples, architecture explanation
- **Additional eval queries** — Realistic natural-language patterns

## Development Workflow

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run `swift test` and `swift run MQUPEval` — ensure metrics don't regress
6. Submit a PR

## Code Style

- Follow Swift API design guidelines
- No SwiftUI imports in domain modules (enforced by `ArchitectureTests`)
- User-facing strings must go through `SearchResultsBuilder` — no hardcoded copy in UI

## Adding Eval Queries

Edit `eval/query_templates.json` with new query templates. Run:

```bash
python3 scripts/generate_eval_queries.py
swift run MQUPEval
```

Verify metrics don't regress before submitting.

## iOS App Development

Requires Xcode 15+ and either:
- **XcodeGen** (recommended): `xcodegen generate && open MQUP.xcodeproj`
- **Manual Xcode setup** (see README)

Set your Development Team in project settings before building.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
