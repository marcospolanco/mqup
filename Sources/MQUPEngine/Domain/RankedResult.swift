import Foundation

public struct RankedResult: Equatable, Sendable {
    public let poi: POI
    public let blendedScore: Double
    public let lexicalScore: Double
    public let semanticScore: Double
    public let constraintsSatisfied: Set<String>
    public let constraintsMissed: Set<String>

    public init(
        poi: POI,
        blendedScore: Double,
        lexicalScore: Double,
        semanticScore: Double,
        constraintsSatisfied: Set<String> = [],
        constraintsMissed: Set<String> = []
    ) {
        self.poi = poi
        self.blendedScore = blendedScore
        self.lexicalScore = lexicalScore
        self.semanticScore = semanticScore
        self.constraintsSatisfied = constraintsSatisfied
        self.constraintsMissed = constraintsMissed
    }
}

public struct LexicalHit: Equatable, Sendable {
    public let poiID: UUID
    public let score: Double

    public init(poiID: UUID, score: Double) {
        self.poiID = poiID
        self.score = score
    }
}

public struct SemanticHit: Equatable, Sendable {
    public let poiID: UUID
    public let score: Double

    public init(poiID: UUID, score: Double) {
        self.poiID = poiID
        self.score = score
    }
}
