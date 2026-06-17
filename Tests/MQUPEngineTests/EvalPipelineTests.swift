import Foundation
import MQUPEngine
import XCTest

final class EvalPipelineTests: XCTestCase {
    func testHonestEvalMeetsQualityThresholdsOnSample() throws {
        let root = repoRoot()
        let poiURL = root.appendingPathComponent("data/pois.json")
        let templatesURL = root.appendingPathComponent("eval/query_templates.json")
        guard FileManager.default.fileExists(atPath: poiURL.path),
              FileManager.default.fileExists(atPath: templatesURL.path) else {
            throw XCTSkip("Full eval corpus not available")
        }

        let pois = try POILoader.load(from: poiURL)
        let templates = try EvalHarness.loadTemplates(from: templatesURL)
        let sample = Array(templates.prefix(30))
        let queries = try ConstraintRelevanceLabeler.label(templates: sample, pois: pois)
        let devQueries = queries.filter { !($0.blindHoldout ?? false) }

        let tunedAlpha = try EvalHarness.tuneAlpha(pois: pois, devQueries: devQueries)
        let hybrid = try SearchCoordinator(pois: pois, config: HybridRankerConfiguration(alpha: tunedAlpha))

        let hybridMetrics = try EvalHarness.run(coordinator: hybrid, queries: queries, measureLatency: false)

        XCTAssertGreaterThanOrEqual(hybridMetrics.recallAt10, 0.85)
        XCTAssertGreaterThanOrEqual(hybridMetrics.nDCGAt5, 0.85)
    }

    func testEvalLatencyThreshold() throws {
        let root = repoRoot()
        let pois = try POILoader.load(from: root.appendingPathComponent("data/pois.json"))
        let templates = try EvalHarness.loadTemplates(from: root.appendingPathComponent("eval/query_templates.json"))
        let queries = try ConstraintRelevanceLabeler.label(templates: Array(templates.prefix(20)), pois: pois)

        let hybrid = try SearchCoordinator(pois: pois)
        try EvalHarness.warmUp(hybrid)
        let metrics = try EvalHarness.run(coordinator: hybrid, queries: queries)

        XCTAssertLessThan(metrics.p95LatencyMs, 200.0, "debug p95 latency should stay within a practical local-test budget")
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("data/pois.json").path) {
                return url
            }
        }
        fatalError("Could not locate repo root")
    }
}
