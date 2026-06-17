import CoreLocation
import Foundation

public enum ResultsState: Equatable, Sendable {
    case golden
    case partial
    case empty
    case loading
    case ambiguous
}

public struct SearchResultsView: Equatable, Sendable {
    public let primaryQuestion: String
    public let state: ResultsState
    public let rows: [ResultRowView]
    public let mapAnnotations: [MapAnnotationView]
    public let emptyState: EmptyStateView?
    public let totalLatencyMs: Int

    public init(
        primaryQuestion: String,
        state: ResultsState,
        rows: [ResultRowView],
        mapAnnotations: [MapAnnotationView],
        emptyState: EmptyStateView?,
        totalLatencyMs: Int
    ) {
        self.primaryQuestion = primaryQuestion
        self.state = state
        self.rows = rows
        self.mapAnnotations = mapAnnotations
        self.emptyState = emptyState
        self.totalLatencyMs = totalLatencyMs
    }
}

public struct ResultRowView: Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let category: String
    public let whyThisMatched: String
    public let constraintsSatisfied: [String]
    public let constraintsMissed: [String]
    public let deviationMeters: Int?
    public let showCategoryBadge: Bool
    public let latitude: Double
    public let longitude: Double

    public init(
        id: UUID,
        name: String,
        category: String,
        whyThisMatched: String,
        constraintsSatisfied: [String],
        constraintsMissed: [String],
        deviationMeters: Int?,
        showCategoryBadge: Bool,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.whyThisMatched = whyThisMatched
        self.constraintsSatisfied = constraintsSatisfied
        self.constraintsMissed = constraintsMissed
        self.deviationMeters = deviationMeters
        self.showCategoryBadge = showCategoryBadge
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct MapAnnotationView: Equatable, Sendable {
    public let id: UUID
    public let coordinate: CoordinateView
    public let title: String
    public let isPrimary: Bool

    public init(id: UUID, coordinate: CoordinateView, title: String, isPrimary: Bool) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.isPrimary = isPrimary
    }
}

public struct CoordinateView: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct EmptyStateView: Equatable, Sendable {
    public let explanation: String
    public let suggestedRelaxation: String?

    public init(explanation: String, suggestedRelaxation: String?) {
        self.explanation = explanation
        self.suggestedRelaxation = suggestedRelaxation
    }
}

#if canImport(MapKit)
import MapKit

extension CoordinateView {
    public var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
#endif
