import MQUPEngine
import XCTest

final class AmbiguityClassifierTests: XCTestCase {
    private var coordinator: SearchCoordinator!

    override func setUpWithError() throws {
        let dummy = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            name: "Dummy",
            category: "coffee",
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.32,
            longitude: -122.03,
            description: "dummy"
        )
        coordinator = try SearchCoordinator(pois: [dummy])
    }

    func testDominantCategoryIsNotAmbiguous() throws {
        let coffee = makePOI(id: 1, category: "coffee")
        let food = makePOI(id: 2, category: "food")
        let retail = makePOI(id: 3, category: "retail")
        let dominated = [
            ranked(coffee, 1.0),
            ranked(coffee, 0.95),
            ranked(coffee, 0.9),
            ranked(food, 0.5),
            ranked(retail, 0.4),
        ]
        XCTAssertFalse(coordinator.classifyAmbiguity(results: dominated))
    }

    func testBalancedMultiCategoryTopFiveIsAmbiguous() throws {
        let coffee = makePOI(id: 1, category: "coffee")
        let food = makePOI(id: 2, category: "food")
        let retail = makePOI(id: 3, category: "retail")
        let service = makePOI(id: 4, category: "service")
        let balanced = [
            ranked(coffee, 1.0),
            ranked(food, 0.95),
            ranked(retail, 0.9),
            ranked(service, 0.85),
            ranked(coffee, 0.8),
        ]
        XCTAssertTrue(coordinator.classifyAmbiguity(results: balanced))
    }

    func testClassifyResultsStateUsesOnlyMaxShareRule() throws {
        let intent = QueryIntent(
            rawText: "place to work",
            categories: ["coffee", "service", "retail"],
            requiredAttributes: [],
            preferredAttributes: [],
            temporalConstraint: nil,
            extractorConfidence: 0.9
        )
        let coffee = makePOI(id: 1, category: "coffee")
        let food = makePOI(id: 2, category: "food")
        let retail = makePOI(id: 3, category: "retail")
        let service = makePOI(id: 4, category: "service")
        let dominated = [
            ranked(coffee, 1.0),
            ranked(coffee, 0.95),
            ranked(coffee, 0.9),
            ranked(food, 0.5),
            ranked(retail, 0.4),
        ]
        let state = coordinator.classifyResultsState(intent: intent, results: dominated, simulateLoading: false)
        XCTAssertNotEqual(state, .ambiguous)
    }

    private func makePOI(id: Int, category: String) -> POI {
        POI(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", id))!,
            name: category,
            category: category,
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.32,
            longitude: -122.03,
            description: category
        )
    }

    private func ranked(_ poi: POI, _ score: Double) -> RankedResult {
        RankedResult(
            poi: poi,
            blendedScore: score,
            lexicalScore: score,
            semanticScore: score
        )
    }
}
