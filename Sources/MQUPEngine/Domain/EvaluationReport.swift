import Foundation

public struct EvaluationReport: Equatable, Sendable {
    public let nDCGAt5: Double
    public let recallAt10: Double
    public let p95LatencyMs: Double
    public let hybridAlpha: Double
    public let queryCount: Int

    public init(
        nDCGAt5: Double,
        recallAt10: Double,
        p95LatencyMs: Double,
        hybridAlpha: Double,
        queryCount: Int = 0
    ) {
        self.nDCGAt5 = nDCGAt5
        self.recallAt10 = recallAt10
        self.p95LatencyMs = p95LatencyMs
        self.hybridAlpha = hybridAlpha
        self.queryCount = queryCount
    }

    public init(metrics: EvalMetrics, alpha: Double) {
        self.init(
            nDCGAt5: metrics.nDCGAt5,
            recallAt10: metrics.recallAt10,
            p95LatencyMs: metrics.p95LatencyMs,
            hybridAlpha: alpha,
            queryCount: metrics.queryCount
        )
    }
}
