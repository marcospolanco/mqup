import Foundation

public struct EvalQuery: Codable, Sendable {
    public let id: String
    public let query: String
    public let relevantPOIIDs: [String]
    public let nowISO8601: String?
    public let blindHoldout: Bool?

    public init(
        id: String,
        query: String,
        relevantPOIIDs: [String],
        nowISO8601: String?,
        blindHoldout: Bool? = nil
    ) {
        self.id = id
        self.query = query
        self.relevantPOIIDs = relevantPOIIDs
        self.nowISO8601 = nowISO8601
        self.blindHoldout = blindHoldout
    }
}

public struct EvalQueryTemplate: Codable, Sendable {
    public let id: String
    public let query: String
    public let nowISO8601: String
    public let blindHoldout: Bool

    public init(id: String, query: String, nowISO8601: String, blindHoldout: Bool) {
        self.id = id
        self.query = query
        self.nowISO8601 = nowISO8601
        self.blindHoldout = blindHoldout
    }
}

public struct EvalMetrics: Sendable {
    public let nDCGAt5: Double
    public let recallAt10: Double
    public let p95LatencyMs: Double
    public let hybridAlpha: Double
    public let queryCount: Int
}

public enum EvalHarness {
    public static func loadQueries(from url: URL) throws -> [EvalQuery] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([EvalQuery].self, from: data)
    }

    public static func loadTemplates(from url: URL) throws -> [EvalQueryTemplate] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([EvalQueryTemplate].self, from: data)
    }

    public static func saveQueries(_ queries: [EvalQuery], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(queries).write(to: url)
    }

    public static func warmUp(_ coordinator: SearchCoordinator) throws {
        for _ in 0..<5 {
            _ = try coordinator.submit(query: "coffee", now: Date())
        }
    }

    public static func tuneAlpha(
        pois: [POI],
        devQueries: [EvalQuery],
        candidates: [Double] = [0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65]
    ) throws -> Double {
        var bestAlpha = HybridRankerConfiguration.defaultAlpha
        var bestDelta = -Double.infinity

        for alpha in candidates {
            let hybrid = try SearchCoordinator(pois: pois, config: HybridRankerConfiguration(alpha: alpha))
            let bm25 = try SearchCoordinator(pois: pois, config: HybridRankerConfiguration(alpha: 1.0))
            let hybridMetrics = try run(coordinator: hybrid, queries: devQueries, measureLatency: false)
            let bm25Metrics = try run(coordinator: bm25, queries: devQueries, measureLatency: false)
            let delta = hybridMetrics.nDCGAt5 - bm25Metrics.nDCGAt5
            if delta > bestDelta {
                bestDelta = delta
                bestAlpha = alpha
            }
        }
        return bestAlpha
    }

    public static func run(
        coordinator: SearchCoordinator,
        queries: [EvalQuery],
        k: Int = 10,
        measureLatency: Bool = true
    ) throws -> EvalMetrics {
        var ndcgScores: [Double] = []
        var recallScores: [Double] = []
        var latencies: [Double] = []

        for item in queries {
            let now = parseDate(item.nowISO8601) ?? Date()
            let start = DispatchTime.now()
            let submission = try coordinator.submit(query: item.query, now: now)
            if measureLatency {
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                latencies.append(elapsed)
            }

            let retrieved = submission.results.prefix(k).map { $0.poi.id.uuidString.lowercased() }
            let relevant = Set(item.relevantPOIIDs.map { $0.lowercased() })
            recallScores.append(recallAtK(retrieved: retrieved, relevant: relevant, k: k))
            ndcgScores.append(nDCGAtK(retrieved: retrieved, relevant: relevant, k: 5))
        }

        latencies.sort()
        let p95Index = latencies.isEmpty ? 0 : min(latencies.count - 1, Int(Double(latencies.count - 1) * 0.95))
        return EvalMetrics(
            nDCGAt5: ndcgScores.isEmpty ? 0 : ndcgScores.reduce(0, +) / Double(ndcgScores.count),
            recallAt10: recallScores.isEmpty ? 0 : recallScores.reduce(0, +) / Double(recallScores.count),
            p95LatencyMs: latencies.isEmpty ? 0 : latencies[p95Index],
            hybridAlpha: HybridRankerConfiguration.defaultAlpha,
            queryCount: queries.count
        )
    }

    public static func parseDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)
    }

    public static func recallAtK(retrieved: [String], relevant: Set<String>, k: Int) -> Double {
        guard !relevant.isEmpty else { return 1.0 }
        let top = Set(retrieved.prefix(k))
        let hits = top.intersection(relevant).count
        return Double(hits) / Double(relevant.count)
    }

    public static func nDCGAtK(retrieved: [String], relevant: Set<String>, k: Int) -> Double {
        let top = Array(retrieved.prefix(k))
        var dcg = 0.0
        for (index, id) in top.enumerated() {
            if relevant.contains(id) {
                dcg += 1.0 / log2(Double(index + 2))
            }
        }
        let idealHits = min(relevant.count, k)
        var idcg = 0.0
        for index in 0..<idealHits {
            idcg += 1.0 / log2(Double(index + 2))
        }
        guard idcg > 0 else { return 0 }
        return dcg / idcg
    }
}
