import Foundation
import MQUPEngine
import XCTest

final class HybridRankerTests: XCTestCase {
    private var pois: [POI] = []

    override func setUpWithError() throws {
        let url = testResourceURL("sample_pois.json")
        pois = try POILoader.load(from: url)
    }

    func testBM25ReturnsOrderedResults() throws {
        let index = try BM25Index(pois: pois)
        let hits = try index.search(tokens: ["coffee"], limit: 20)
        XCTAssertGreaterThanOrEqual(hits.count, 1)
        if hits.count >= 2 {
            for i in 1..<hits.count {
                XCTAssertGreaterThanOrEqual(hits[i - 1].score, hits[i].score)
            }
        }
    }

    func testEmbeddingCosineSymmetric() {
        let vector = TextEmbedder.embed("coffee shop parking")
        let sim = TextEmbedder.cosineSimilarity(vector, vector)
        XCTAssertEqual(sim, 1.0, accuracy: 1e-6)
    }

    func testHybridBlendEndpoints() throws {
        let pois = pois
        let bm25Only = try HybridRanker(pois: pois, config: HybridRankerConfiguration(alpha: 1.0))
        let embedOnly = try HybridRanker(pois: pois, config: HybridRankerConfiguration(alpha: 0.0))
        let intent = QueryIntentExtractor().extract(text: "coffee")
        let now = ISO8601DateFormatter().date(from: "2026-06-16T14:30:00Z")!
        let bm25Results = try bm25Only.rank(intent: intent, now: now, k: 5)
        let embedResults = try embedOnly.rank(intent: intent, now: now, k: 5)
        XCTAssertFalse(bm25Results.isEmpty)
        XCTAssertFalse(embedResults.isEmpty)
    }

    func testIntentExtractionCompoundQuery() {
        let intent = QueryIntentExtractor().extract(text: "coffee shops with parking open now")
        XCTAssertEqual(intent.categories, ["coffee"])
        XCTAssertTrue(intent.preferredAttributes.contains("parking"))
        XCTAssertEqual(intent.temporalConstraint, .openNow)
    }

    func testHardFilterRemovesClosedPOIs() throws {
        let ranker = try HybridRanker(pois: pois)
        let intent = QueryIntentExtractor().extract(text: "coffee open now")
        let lateNight = ISO8601DateFormatter().date(from: "2026-06-16T03:30:00Z")!
        let results = try ranker.rank(intent: intent, now: lateNight, k: 20)
        for result in results {
            XCTAssertTrue(result.poi.hours.isOpen(at: lateNight))
        }
    }

    func testSoftDemotionForMissingParking() throws {
        let ranker = try HybridRanker(pois: pois)
        let intent = QueryIntentExtractor().extract(text: "coffee with parking")
        let now = ISO8601DateFormatter().date(from: "2026-06-16T14:30:00Z")!
        let withParking = pois.filter { $0.category == "coffee" && $0.attributes.contains("parking") }
        let withoutParking = pois.filter { $0.category == "coffee" && !$0.attributes.contains("parking") }
        guard let a = withParking.first, let b = withoutParking.first else {
            throw XCTSkip("Need both parking and non-parking coffee POIs")
        }
        let blended = ranker.blend(
            lexical: [
                LexicalHit(poiID: a.id, score: 1.0),
                LexicalHit(poiID: b.id, score: 1.0),
            ],
            semantic: [
                SemanticHit(poiID: a.id, score: 1.0),
                SemanticHit(poiID: b.id, score: 1.0),
            ],
            candidateIDs: [a.id, b.id]
        )
        let demoted = ranker.applySoftDemotion(intent: intent, results: blended)
        let scoreA = demoted.first { $0.poi.id == a.id }!.blendedScore
        let scoreB = demoted.first { $0.poi.id == b.id }!.blendedScore
        XCTAssertGreaterThan(scoreA, scoreB)
        XCTAssertEqual(scoreB / scoreA, 0.6, accuracy: 0.02)
    }

    func testAmbiguityDetection() throws {
        let coordinator = try SearchCoordinator(pois: [pois[0]])
        let coffee = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Coffee",
            category: "coffee",
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.32,
            longitude: -122.03,
            description: "Coffee"
        )
        let food = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Food",
            category: "food",
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.33,
            longitude: -122.04,
            description: "Food"
        )
        let retail = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Retail",
            category: "retail",
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.34,
            longitude: -122.05,
            description: "Retail"
        )
        let service = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "Service",
            category: "service",
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.35,
            longitude: -122.06,
            description: "Service"
        )
        let mixed = [
            RankedResult(poi: coffee, blendedScore: 1, lexicalScore: 1, semanticScore: 1),
            RankedResult(poi: food, blendedScore: 0.9, lexicalScore: 0.9, semanticScore: 0.9),
            RankedResult(poi: retail, blendedScore: 0.8, lexicalScore: 0.8, semanticScore: 0.8),
            RankedResult(poi: service, blendedScore: 0.7, lexicalScore: 0.7, semanticScore: 0.7),
            RankedResult(poi: coffee, blendedScore: 0.6, lexicalScore: 0.6, semanticScore: 0.6),
        ]
        XCTAssertTrue(coordinator.classifyAmbiguity(results: mixed))
    }

    private func testResourceURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name.replacingOccurrences(of: ".json", with: ""), withExtension: "json")!
    }
}
