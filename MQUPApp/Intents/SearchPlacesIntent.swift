import AppIntents
import CoreSpotlight
import MQUPEngine

struct SpatialVenueEntity: AppEntity, IndexedEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Place")
    static var defaultQuery = SpatialVenueQuery()

    var id: UUID
    var name: String
    var category: String
    var hoursSummary: String
    var attributes: [String]
    var latitude: Double
    var longitude: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(category)")
    }

    init(from poi: POI) {
        id = poi.id
        name = poi.name
        category = poi.category
        hoursSummary = "See hours in app"
        attributes = Array(poi.attributes)
        latitude = poi.latitude
        longitude = poi.longitude
    }
}

struct SpatialVenueQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SpatialVenueEntity] {
        let pois = try await POIService.shared.allPOIs()
        return pois.filter { identifiers.contains($0.id) }.map(SpatialVenueEntity.init)
    }

    func suggestedEntities() async throws -> [SpatialVenueEntity] {
        let pois = try await POIService.shared.allPOIs()
        return pois.prefix(20).map(SpatialVenueEntity.init)
    }
}

struct SearchPlacesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Places"
    static var description = IntentDescription("Find places that match a natural language query.")

    @Parameter(title: "Search Query")
    var searchQuery: String

    @Parameter(title: "Max Results")
    var maxResults: Int?

    func perform() async throws -> some IntentResult & ReturnsValue<[SpatialVenueEntity]> & ProvidesDialog {
        let submission = try await POIService.shared.search(query: searchQuery)
        let dialog = SearchResultsBuilder.buildSiriDialog(from: submission.view)
        let limit = maxResults ?? 5
        let entities = submission.results.prefix(limit).map { SpatialVenueEntity(from: $0.poi) }
        return .result(value: entities, dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct MQUPShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchPlacesIntent(),
            phrases: [
                "Find places in \(.applicationName)",
                "Search for \(\.$searchQuery) in \(.applicationName)",
            ],
            shortTitle: "Search Places",
            systemImageName: "magnifyingglass"
        )
    }
}
