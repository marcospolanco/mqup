import Foundation

public struct QueryIntentExtractor: Sendable {
    private static let categoryLexicon: [String: String] = [
        "coffee": "coffee",
        "coffee shop": "coffee",
        "coffee shops": "coffee",
        "cafe": "coffee",
        "café": "coffee",
        "espresso": "coffee",
        "pizza": "food",
        "pizzeria": "food",
        "sushi": "food",
        "restaurant": "food",
        "food": "food",
        "bakery": "food",
        "bakeries": "food",
        "grocery": "retail",
        "retail store": "retail",
        "retail": "retail",
        "library": "service",
        "coworking": "service",
        "service location": "service",
        "gym": "service",
        "service": "service",
        "quiet cafe": "coffee",
        "late night food": "food",
        "sushi restaurant": "food",
    ]

    private static let attributeLexicon: [String: String] = [
        "parking": "parking",
        "outdoor seating": "outdoor_seating",
        "outdoor_seating": "outdoor_seating",
        "wifi": "wifi",
        "wi-fi": "wifi",
        "drive through": "drive_through",
        "drive-through": "drive_through",
        "drive thru": "drive_through",
    ]

    public init() {}

    public func extract(text: String) -> QueryIntent {
        let lowered = text.lowercased()
        var categories: [String] = []
        for (phrase, category) in Self.categoryLexicon.sorted(by: { $0.key.count > $1.key.count }) {
            if lowered.contains(phrase), !categories.contains(category) {
                categories.append(category)
            }
        }

        if lowered.contains("place to work") {
            categories = ["coffee", "service", "retail"]
        } else if lowered.contains("coffee shop") || lowered.contains("coffee shops") || lowered.contains("cafe") {
            if !categories.contains("coffee") {
                categories.append("coffee")
            }
        }

        var preferred = Set<String>()
        let required = Set<String>()
        for (phrase, attribute) in Self.attributeLexicon {
            if lowered.contains(phrase) {
                preferred.insert(attribute)
            }
        }

        var temporal: TemporalConstraint?
        if lowered.contains("open now") || lowered.contains("open right now") {
            temporal = .openNow
        } else if lowered.contains("late night") {
            temporal = .openNow
        } else if lowered.contains("4am") || lowered.contains("4 am") {
            var components = DateComponents()
            components.hour = 4
            components.minute = 0
            temporal = .openAt(Calendar.current.date(from: components) ?? Date())
        }

        if categories.isEmpty {
            let tokens = Self.searchTokens(from: lowered)
            if let first = tokens.first, let mapped = Self.categoryLexicon[first] {
                categories = [mapped]
            }
        }

        let confidence: Double
        if categories.isEmpty {
            confidence = 0.35
        } else if preferred.isEmpty && temporal == nil {
            confidence = 0.75
        } else {
            confidence = 0.9
        }

        return QueryIntent(
            rawText: text,
            categories: categories,
            requiredAttributes: required,
            preferredAttributes: preferred,
            temporalConstraint: temporal,
            extractorConfidence: confidence
        )
    }

    public static func searchTokens(from intent: QueryIntent) -> [String] {
        searchTokens(from: intent.rawText)
    }

    public static func searchTokens(from text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }
}
