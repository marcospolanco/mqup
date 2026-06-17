import Foundation
import MQUPEngine

@main
struct MQUPEvalCLI {
    static func main() throws {
        let args = Set(CommandLine.arguments.dropFirst())
        let repoRoot = findRepoRoot()
        let poiURL = repoURL(repoRoot, "data/pois.json")
        let evalURL = repoURL(repoRoot, "eval/queries.json")
        let templatesURL = repoURL(repoRoot, "eval/query_templates.json")
        let metricsURL = repoURL(repoRoot, "metrics.json")

        let pois = try POILoader.load(from: poiURL)

        if args.contains("--sync-fixtures") {
            try syncFixtureStates(pois: pois, repoRoot: repoRoot)
            return
        }

        if args.contains("--label") {
            try runLabeling(pois: pois, templatesURL: templatesURL, outputURL: evalURL)
            return
        }

        if !FileManager.default.fileExists(atPath: evalURL.path) {
            try runLabeling(pois: pois, templatesURL: templatesURL, outputURL: evalURL)
        }

        let queries = try EvalHarness.loadQueries(from: evalURL)
        let devQueries = queries.filter { !($0.blindHoldout ?? false) }

        // Labels are frozen (constraint + BM25). α is tuned on dev only; labels are never re-derived from hybrid.
        let tunedAlpha = try EvalHarness.tuneAlpha(pois: pois, devQueries: devQueries)

        let blindQueries = queries.filter { $0.blindHoldout ?? false }
        let refreshedDev = queries.filter { !($0.blindHoldout ?? false) }
        let hybridCoordinator = try SearchCoordinator(
            pois: pois,
            config: HybridRankerConfiguration(alpha: tunedAlpha)
        )
        let bm25Coordinator = try SearchCoordinator(
            pois: pois,
            config: HybridRankerConfiguration(alpha: 1.0)
        )

        try EvalHarness.warmUp(hybridCoordinator)
        try EvalHarness.warmUp(bm25Coordinator)

        let hybridAll = try EvalHarness.run(coordinator: hybridCoordinator, queries: queries)
        let bm25All = try EvalHarness.run(coordinator: bm25Coordinator, queries: queries)
        let hybridDev = try EvalHarness.run(coordinator: hybridCoordinator, queries: refreshedDev, measureLatency: false)
        let hybridBlind = blindQueries.isEmpty
            ? hybridDev
            : try EvalHarness.run(coordinator: hybridCoordinator, queries: blindQueries, measureLatency: false)

        let metrics: [String: Any] = [
            "tunedAlpha": tunedAlpha,
            "hybrid": metricsDict(hybridAll, alpha: tunedAlpha),
            "bm25_only": metricsDict(bm25All, alpha: 1.0),
            "nDCG_delta": hybridAll.nDCGAt5 - bm25All.nDCGAt5,
            "dev_split": metricsDict(hybridDev, alpha: tunedAlpha),
            "blind_split": metricsDict(hybridBlind, alpha: tunedAlpha),
            "thresholds": [
                "nDCG_delta_target": 0.10,
                "recallAt10_target": 0.85,
                "p95LatencyMs_target": 100.0,
            ],
            "passes": [
                "nDCG_delta": (hybridAll.nDCGAt5 - bm25All.nDCGAt5) >= 0.10,
                "recallAt10": hybridAll.recallAt10 >= 0.85,
                "p95LatencyMs": hybridAll.p95LatencyMs < 100.0,
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: metricsURL)

        let resumeURL = repoURL(repoRoot, "docs/resume-bullet.md")
        try ResumeBulletGenerator.write(
            ResumeBulletGenerator.Input(
                tunedAlpha: tunedAlpha,
                nDCGDelta: hybridAll.nDCGAt5 - bm25All.nDCGAt5,
                recallAt10: hybridAll.recallAt10,
                hybridP95LatencyMs: hybridAll.p95LatencyMs
            ),
            to: resumeURL
        )
        print("Wrote resume bullet to \(resumeURL.path)")
        print("Wrote metrics to \(metricsURL.path)")
        print(String(data: data, encoding: .utf8) ?? "")
    }

    private static func syncFixtureStates(pois: [POI], repoRoot: URL) throws {
        let coordinator = try SearchCoordinator(pois: pois)
        let fixturesDir = repoRoot.appendingPathComponent("fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        for file in files {
            let data = try Data(contentsOf: file)
            var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let query = json["query"] as! String
            let nowISO = json["nowISO8601"] as! String
            let simulateLoading = json["simulateLoading"] as? Bool ?? false
            let now = formatter.date(from: nowISO) ?? Date()
            let submission = try coordinator.submit(query: query, now: now, simulateLoading: simulateLoading)
            json["expectedResultsState"] = fixtureName(submission.view.state)
            json["expectedTop3IDs"] = submission.results.prefix(3).map { $0.poi.id.uuidString.lowercased() }
            let out = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try out.write(to: file)
            print("\(file.lastPathComponent): \(json["expectedResultsState"] ?? "")")
        }
    }

    private static func fixtureName(_ state: ResultsState) -> String {
        switch state {
        case .golden: return "golden"
        case .partial: return "partial"
        case .empty: return "empty"
        case .loading: return "loading"
        case .ambiguous: return "ambiguous"
        }
    }

    private static func runLabeling(pois: [POI], templatesURL: URL, outputURL: URL) throws {
        let templates = try EvalHarness.loadTemplates(from: templatesURL)
        let labeled = try ConstraintRelevanceLabeler.label(templates: templates, pois: pois)
        try EvalHarness.saveQueries(labeled, to: outputURL)
        print("Labeled \(labeled.count) queries (constraint + token overlap, frozen) → \(outputURL.path)")
    }

    private static func metricsDict(_ metrics: EvalMetrics, alpha: Double) -> [String: Any] {
        [
            "nDCGAt5": metrics.nDCGAt5,
            "recallAt10": metrics.recallAt10,
            "p95LatencyMs": metrics.p95LatencyMs,
            "alpha": alpha,
            "queryCount": metrics.queryCount,
        ]
    }

    private static func findRepoRoot() -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<5 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("data/pois.json").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func repoURL(_ root: URL, _ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }
}
