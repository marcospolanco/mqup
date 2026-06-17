import Foundation

public struct SearchSubmission: Sendable {
    public let view: SearchResultsView
    public let results: [RankedResult]
    public let intent: QueryIntent
}

public final class SearchCoordinator: @unchecked Sendable {
    private let ranker: HybridRanker
    private let extractor = QueryIntentExtractor()

    public init(pois: [POI], config: HybridRankerConfiguration = HybridRankerConfiguration()) throws {
        ranker = try HybridRanker(pois: pois, config: config)
    }

    public func submit(
        query: String,
        now: Date = Date(),
        simulateLoading: Bool = false
    ) throws -> SearchSubmission {
        let start = DispatchTime.now()
        if simulateLoading {
            Thread.sleep(forTimeInterval: 0.2)
        }

        let intent = extractor.extract(text: query)
        let results = try ranker.rank(intent: intent, now: now, k: 10)
        let state = classifyResultsState(intent: intent, results: results, simulateLoading: simulateLoading)
        let end = DispatchTime.now()
        let latencyMs = Int(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        let view = SearchResultsBuilder.buildSearchResultsView(
            intent: intent,
            results: results,
            state: state,
            now: now,
            latencyMs: latencyMs
        )
        return SearchSubmission(view: view, results: results, intent: intent)
    }

    public func classifyResultsState(
        intent: QueryIntent,
        results: [RankedResult],
        simulateLoading: Bool
    ) -> ResultsState {
        if simulateLoading {
            return .loading
        }
        if results.isEmpty {
            return .empty
        }
        if classifyAmbiguity(results: results) {
            return .ambiguous
        }
        let top = results.prefix(3)
        let allFullMatch = top.allSatisfy { $0.constraintsMissed.isEmpty }
        if allFullMatch {
            return .golden
        }
        return .partial
    }

    public func classifyAmbiguity(results: [RankedResult]) -> Bool {
        let top = Array(results.prefix(5))
        guard top.count >= 3 else { return false }
        let categories = top.map(\.poi.category)
        let distinct = Set(categories)
        guard distinct.count >= 3 else { return false }
        let counts = Dictionary(grouping: categories, by: { $0 }).mapValues(\.count)
        let maxShare = Double(counts.values.max() ?? 0) / Double(top.count)
        return maxShare <= 0.4
    }
}
