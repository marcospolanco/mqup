import Foundation
import MQUPEngine
import XCTest

final class BuilderTests: XCTestCase {
    func testFixturesProduceExpectedStates() throws {
        let pois = try POILoader.load(from: repoRoot().appendingPathComponent("data/pois.json"))
        let coordinator = try SearchCoordinator(pois: pois)
        let fixturesDir = repoRoot().appendingPathComponent("fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        for file in files {
            let data = try Data(contentsOf: file)
            let fixture = try JSONDecoder().decode(Fixture.self, from: data)
            let now = ISO8601DateFormatter().date(from: fixture.nowISO8601)!
            let submission = try coordinator.submit(
                query: fixture.query,
                now: now,
                simulateLoading: fixture.simulateLoading
            )
            XCTAssertEqual(
                submission.view.state.fixtureName,
                fixture.expectedResultsState,
                "Fixture \(fixture.id) state mismatch"
            )
        }
    }

    func testSiriDialogSharesVocabulary() throws {
        let pois = try POILoader.load(from: repoRoot().appendingPathComponent("data/pois.json"))
        let coordinator = try SearchCoordinator(pois: pois)
        let submission = try coordinator.submit(query: "coffee shops with parking open now")
        let dialog = SearchResultsBuilder.buildSiriDialog(from: submission.view)
        XCTAssertTrue(dialog.contains("Places that match") || dialog.contains("I found") || dialog.contains("coffee"))
        XCTAssertFalse(dialog.lowercased().contains("bm25"))
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("fixtures").path) {
                return url
            }
        }
        fatalError("Could not locate repo root")
    }

    private struct Fixture: Decodable {
        let id: String
        let query: String
        let nowISO8601: String
        let expectedResultsState: String
        let simulateLoading: Bool
    }
}

private extension ResultsState {
    var fixtureName: String {
        switch self {
        case .golden: return "golden"
        case .partial: return "partial"
        case .empty: return "empty"
        case .loading: return "loading"
        case .ambiguous: return "ambiguous"
        }
    }
}
