import CoreSpotlight
import Foundation
import MQUPEngine

@MainActor
final class POIService {
    static let shared = POIService()

    private var coordinator: SearchCoordinator?
    private var pois: [POI] = []

    private init() {}

    func bootstrapIfNeeded() throws {
        guard coordinator == nil else { return }
        guard let url = Bundle.main.url(forResource: "pois", withExtension: "json")
            ?? Bundle.main.url(forResource: "pois", withExtension: "json", subdirectory: "Resources") else {
            throw POIServiceError.notReady
        }
        pois = try POILoader.load(from: url)
        coordinator = try SearchCoordinator(pois: pois)
    }

    func allPOIs() async throws -> [POI] {
        try bootstrapIfNeeded()
        return pois
    }

    func search(query: String, now: Date = Date()) async throws -> SearchSubmission {
        try bootstrapIfNeeded()
        guard let coordinator else { throw POIServiceError.notReady }
        return try coordinator.submit(query: query, now: now)
    }

    func donateEntities(for results: [RankedResult]) async {
        let entities = results.prefix(10).map { SpatialVenueEntity(from: $0.poi) }
        try? await CSSearchableIndex.default().indexAppEntities(entities)
    }

    func donateEntity(for poi: POI) async {
        try? await CSSearchableIndex.default().indexAppEntities([SpatialVenueEntity(from: poi)])
    }

    func donateSuggestedEntities() async throws {
        let pois = try await allPOIs()
        let entities = pois.prefix(20).map { SpatialVenueEntity(from: $0) }
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }

    enum POIServiceError: Error {
        case notReady
    }
}
