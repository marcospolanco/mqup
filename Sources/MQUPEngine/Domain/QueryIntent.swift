import Foundation

public struct QueryIntent: Equatable, Sendable {
    public let rawText: String
    public let categories: [String]
    public let requiredAttributes: Set<String>
    public let preferredAttributes: Set<String>
    public let temporalConstraint: TemporalConstraint?
    public let extractorConfidence: Double

    public init(
        rawText: String,
        categories: [String],
        requiredAttributes: Set<String>,
        preferredAttributes: Set<String>,
        temporalConstraint: TemporalConstraint?,
        extractorConfidence: Double
    ) {
        self.rawText = rawText
        self.categories = categories
        self.requiredAttributes = requiredAttributes
        self.preferredAttributes = preferredAttributes
        self.temporalConstraint = temporalConstraint
        self.extractorConfidence = extractorConfidence
    }
}

public enum TemporalConstraint: Equatable, Sendable {
    case openNow
    case openAt(Date)
    case openOn(Weekday)
}
