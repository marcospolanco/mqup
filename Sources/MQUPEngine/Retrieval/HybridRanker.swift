import Foundation

public struct HybridRankerConfiguration: Sendable {
    public static let defaultAlpha: Double = 0.45

    public var alpha: Double
    public var softDemotionFactor: Double

    public init(alpha: Double = HybridRankerConfiguration.defaultAlpha, softDemotionFactor: Double = 0.6) {
        self.alpha = alpha
        self.softDemotionFactor = softDemotionFactor
    }
}

public final class HybridRanker: Sendable {
    private let pois: [POI]
    private let poiByID: [UUID: POI]
    private let bm25: BM25Index
    private let embeddings: EmbeddingIndex
    private let config: HybridRankerConfiguration

    public init(pois: [POI], config: HybridRankerConfiguration = HybridRankerConfiguration()) throws {
        self.pois = pois
        self.poiByID = Dictionary(uniqueKeysWithValues: pois.map { ($0.id, $0) })
        self.bm25 = try BM25Index(pois: pois)
        self.embeddings = EmbeddingIndex(pois: pois)
        self.config = config
    }

    public func rank(intent: QueryIntent, now: Date, k: Int = 10) throws -> [RankedResult] {
        let candidates = applyHardFilters(intent: intent, candidates: pois, now: now)
        guard !candidates.isEmpty else { return [] }

        let candidateIDs = Set(candidates.map(\.id))
        let tokens = QueryIntentExtractor.searchTokens(from: intent)
        let lexicalHits = try bm25.search(tokens: tokens, limit: 200)
            .filter { candidateIDs.contains($0.poiID) }
        let queryVector = embeddings.embedQuery(intent.rawText)
        let semanticHits = embeddings.search(vector: queryVector, limit: 200)
            .filter { candidateIDs.contains($0.poiID) }

        var blendIDs = Set(lexicalHits.prefix(80).map(\.poiID))
        blendIDs.formUnion(semanticHits.prefix(80).map(\.poiID))
        if blendIDs.isEmpty {
            blendIDs = candidateIDs
        } else {
            blendIDs = blendIDs.intersection(candidateIDs)
        }

        var blended = blend(lexical: lexicalHits, semantic: semanticHits, candidateIDs: blendIDs)
        blended = applySoftDemotion(intent: intent, results: blended)
        blended.sort { $0.blendedScore > $1.blendedScore }
        if intent.categories.count >= 3 {
            blended = interleaveByCategory(blended, categories: intent.categories)
        }

        return Array(blended.prefix(k)).map { result in
            annotateConstraints(intent: intent, result: result, now: now)
        }
    }

    public func applyHardFilters(intent: QueryIntent, candidates: [POI], now: Date) -> [POI] {
        candidates.filter { poi in
            if !intent.categories.isEmpty {
                guard intent.categories.contains(poi.category) else { return false }
            }
            if case .openNow = intent.temporalConstraint {
                guard poi.hours.isOpen(at: now) else { return false }
            }
            if case let .openAt(date) = intent.temporalConstraint {
                guard poi.hours.isOpen(at: date) else { return false }
            }
            if case let .openOn(day) = intent.temporalConstraint {
                guard poi.hours.hours[day] != nil else { return false }
            }
            for attribute in intent.requiredAttributes {
                guard poi.attributes.contains(attribute) else { return false }
            }
            return true
        }
    }

    public func blend(
        lexical: [LexicalHit],
        semantic: [SemanticHit],
        candidateIDs: Set<UUID>
    ) -> [RankedResult] {
        let lexScores = normalizedScores(lexical.map { ($0.poiID, $0.score) })
        let semScores = normalizedScores(semantic.map { ($0.poiID, $0.score) })
        let rawLex = Dictionary(uniqueKeysWithValues: lexical.map { ($0.poiID, $0.score) })
        let rawSem = Dictionary(uniqueKeysWithValues: semantic.map { ($0.poiID, $0.score) })

        return candidateIDs.compactMap { id in
            guard let poi = poiByID[id] else { return nil }
            let lex = lexScores[id] ?? 0
            let sem = semScores[id] ?? 0
            let blended = config.alpha * lex + (1 - config.alpha) * sem
            return RankedResult(
                poi: poi,
                blendedScore: blended,
                lexicalScore: rawLex[id] ?? 0,
                semanticScore: rawSem[id] ?? 0,
                constraintsSatisfied: [],
                constraintsMissed: []
            )
        }
    }

    public func applySoftDemotion(intent: QueryIntent, results: [RankedResult]) -> [RankedResult] {
        guard !intent.preferredAttributes.isEmpty else { return results }
        return results.map { result in
            var score = result.blendedScore
            for attribute in intent.preferredAttributes where !result.poi.attributes.contains(attribute) {
                score *= config.softDemotionFactor
            }
            return RankedResult(
                poi: result.poi,
                blendedScore: score,
                lexicalScore: result.lexicalScore,
                semanticScore: result.semanticScore,
                constraintsSatisfied: result.constraintsSatisfied,
                constraintsMissed: result.constraintsMissed
            )
        }
    }

    private func interleaveByCategory(_ results: [RankedResult], categories: [String]) -> [RankedResult] {
        var buckets = Dictionary(uniqueKeysWithValues: categories.map { ($0, [RankedResult]()) })
        for result in results {
            buckets[result.poi.category, default: []].append(result)
        }
        var output: [RankedResult] = []
        var remaining = results.count
        while remaining > 0 {
            var progressed = false
            for category in categories {
                guard var bucket = buckets[category], !bucket.isEmpty else { continue }
                output.append(bucket.removeFirst())
                buckets[category] = bucket
                remaining -= 1
                progressed = true
            }
            if !progressed { break }
        }
        return output
    }

    private func normalizedScores(_ pairs: [(UUID, Double)]) -> [UUID: Double] {
        guard let minScore = pairs.map(\.1).min(), let maxScore = pairs.map(\.1).max() else {
            return [:]
        }
        let range = maxScore - minScore
        var output: [UUID: Double] = [:]
        for (id, score) in pairs {
            if range == 0 {
                output[id] = 1
            } else {
                output[id] = (score - minScore) / range
            }
        }
        return output
    }

    private func annotateConstraints(intent: QueryIntent, result: RankedResult, now: Date) -> RankedResult {
        var satisfied = Set<String>()
        var missed = Set<String>()

        for category in intent.categories {
            if intent.categories.count == 1 {
                if result.poi.category == category {
                    satisfied.insert(displayName(for: category))
                } else {
                    missed.insert(displayName(for: category))
                }
            } else if result.poi.category == category {
                satisfied.insert(displayName(for: category))
            }
        }

        for attribute in intent.requiredAttributes.union(intent.preferredAttributes) {
            let label = displayName(for: attribute)
            if result.poi.attributes.contains(attribute) {
                satisfied.insert(label)
            } else {
                missed.insert(label)
            }
        }

        if intent.temporalConstraint != nil {
            let open = result.poi.hours.isOpen(at: now)
            if open {
                satisfied.insert("open now")
            } else {
                missed.insert("open now")
            }
        }

        return RankedResult(
            poi: result.poi,
            blendedScore: result.blendedScore,
            lexicalScore: result.lexicalScore,
            semanticScore: result.semanticScore,
            constraintsSatisfied: satisfied,
            constraintsMissed: missed
        )
    }

    private func displayName(for token: String) -> String {
        token.replacingOccurrences(of: "_", with: " ")
    }
}
