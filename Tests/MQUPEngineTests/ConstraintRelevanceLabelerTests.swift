import Foundation
import MQUPEngine
import XCTest

final class ConstraintRelevanceLabelerTests: XCTestCase {
    func testAllLabeledPOIsSatisfyQueryConstraints() throws {
        let root = repoRoot()
        let pois = try POILoader.load(from: root.appendingPathComponent("data/pois.json"))
        let templates = try EvalHarness.loadTemplates(from: root.appendingPathComponent("eval/query_templates.json"))
        let sample = Array(templates.prefix(10))
        let labels = try ConstraintRelevanceLabeler.label(templates: sample, pois: pois)
        let ranker = try HybridRanker(pois: pois)
        let extractor = QueryIntentExtractor()

        for (template, label) in zip(sample, labels) {
            let intent = extractor.extract(text: template.query)
            let now = EvalHarness.parseDate(template.nowISO8601)!
            var candidates = ranker.applyHardFilters(intent: intent, candidates: pois, now: now)
            if !intent.preferredAttributes.isEmpty {
                candidates = candidates.filter { poi in
                    intent.preferredAttributes.allSatisfy { poi.attributes.contains($0) }
                }
            }
            let allowed = Set(candidates.map(\.id))
            for idString in label.relevantPOIIDs {
                guard let id = UUID(uuidString: idString) else {
                    XCTFail("Invalid UUID in labels")
                    continue
                }
                XCTAssertTrue(allowed.contains(id), "Label \(idString) must satisfy constraints for \(template.query)")
            }
        }
    }

    func testLabelsAreDeterministic() throws {
        let root = repoRoot()
        let templates = try EvalHarness.loadTemplates(from: root.appendingPathComponent("eval/query_templates.json"))
        let sample = Array(templates.prefix(5))
        let pois = try POILoader.load(from: root.appendingPathComponent("data/pois.json"))

        let labelsA = try ConstraintRelevanceLabeler.label(templates: sample, pois: pois)
        let labelsB = try ConstraintRelevanceLabeler.label(templates: sample, pois: pois)
        XCTAssertEqual(labelsA.map(\.relevantPOIIDs), labelsB.map(\.relevantPOIIDs))
    }

    func testPreferredAttributesRequiredForGoldRelevance() throws {
        let poiWithParking = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Park Coffee",
            category: "coffee",
            attributes: ["parking"],
            hours: .weekdayBusiness(),
            latitude: 37.32,
            longitude: -122.03,
            description: "Coffee with parking"
        )
        let poiWithoutParking = POI(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            name: "Plain Coffee",
            category: "coffee",
            attributes: [],
            hours: .weekdayBusiness(),
            latitude: 37.33,
            longitude: -122.04,
            description: "Coffee shop"
        )
        let template = EvalQueryTemplate(
            id: "T1",
            query: "coffee with parking open now",
            nowISO8601: "2026-06-16T14:30:00Z",
            blindHoldout: false
        )
        let labeled = try ConstraintRelevanceLabeler.label(
            templates: [template],
            pois: [poiWithParking, poiWithoutParking]
        )
        XCTAssertEqual(labeled[0].relevantPOIIDs, [poiWithParking.id.uuidString.lowercased()])
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
