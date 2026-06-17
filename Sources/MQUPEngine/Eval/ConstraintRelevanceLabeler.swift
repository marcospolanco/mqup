import Foundation

/// Labels eval queries independently of the hybrid ranker under test.
///
/// Relevance is defined by constraint satisfaction (category, temporal, preferred attributes)
/// with tie-breaking by query–POI token overlap — not BM25, not hybrid scores.
/// Labels are frozen before α tuning and never re-derived from retrieval output.
public enum ConstraintRelevanceLabeler {
    public static func label(
        templates: [EvalQueryTemplate],
        pois: [POI],
        labelK: Int = 10
    ) throws -> [EvalQuery] {
        let ranker = try HybridRanker(pois: pois, config: HybridRankerConfiguration(alpha: 1.0))
        let extractor = QueryIntentExtractor()

        return templates.map { template in
            let now = EvalHarness.parseDate(template.nowISO8601) ?? Date()
            let intent = extractor.extract(text: template.query)
            var candidates = ranker.applyHardFilters(intent: intent, candidates: pois, now: now)

            if !intent.preferredAttributes.isEmpty {
                candidates = candidates.filter { poi in
                    intent.preferredAttributes.allSatisfy { poi.attributes.contains($0) }
                }
            }

            let tokens = QueryIntentExtractor.searchTokens(from: intent)
            let ranked = candidates.sorted { lhs, rhs in
                let left = tokenOverlapScore(poi: lhs, tokens: tokens)
                let right = tokenOverlapScore(poi: rhs, tokens: tokens)
                if left != right { return left > right }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            let relevant = ranked.prefix(labelK).map { $0.id.uuidString.lowercased() }

            return EvalQuery(
                id: template.id,
                query: template.query,
                relevantPOIIDs: Array(relevant),
                nowISO8601: template.nowISO8601,
                blindHoldout: template.blindHoldout
            )
        }
    }

    static func tokenOverlapScore(poi: POI, tokens: [String]) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let haystack = "\(poi.name) \(poi.description) \(poi.category)".lowercased()
        return tokens.reduce(0) { score, token in
            score + (haystack.contains(token) ? 1 : 0)
        }
    }
}
