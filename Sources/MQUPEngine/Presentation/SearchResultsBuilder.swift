import Foundation

public enum SearchResultsBuilder {
    public static func buildSearchResultsView(
        intent: QueryIntent,
        results: [RankedResult],
        state: ResultsState,
        now: Date,
        latencyMs: Int
    ) -> SearchResultsView {
        let effectiveState = state == .loading ? .loading : state
        let primaryQuestion = primaryQuestionText(intent: intent, state: effectiveState)
        let showBadges = effectiveState == .ambiguous

        let rows = results.enumerated().map { index, result in
            ResultRowView(
                id: result.poi.id,
                name: result.poi.name,
                category: result.poi.category,
                whyThisMatched: whyThisMatched(result: result),
                constraintsSatisfied: result.constraintsSatisfied.sorted(),
                constraintsMissed: result.constraintsMissed.sorted(),
                deviationMeters: nil,
                showCategoryBadge: showBadges,
                latitude: result.poi.latitude,
                longitude: result.poi.longitude
            )
        }

        let annotations = results.enumerated().map { index, result in
            MapAnnotationView(
                id: result.poi.id,
                coordinate: CoordinateView(latitude: result.poi.latitude, longitude: result.poi.longitude),
                title: result.poi.name,
                isPrimary: index == 0
            )
        }

        let emptyState: EmptyStateView?
        if effectiveState == .empty {
            emptyState = EmptyStateView(
                explanation: emptyExplanation(intent: intent),
                suggestedRelaxation: suggestedRelaxation(intent: intent)
            )
        } else {
            emptyState = nil
        }

        return SearchResultsView(
            primaryQuestion: primaryQuestion,
            state: effectiveState,
            rows: rows,
            mapAnnotations: annotations,
            emptyState: emptyState,
            totalLatencyMs: latencyMs
        )
    }

    public static func buildSiriDialog(from view: SearchResultsView) -> String {
        switch view.state {
        case .empty:
            return view.emptyState?.explanation ?? "I couldn't find any matching places."
        case .loading:
            return "Searching for places that match your request."
        case .ambiguous, .golden, .partial:
            let count = view.rows.count
            if count == 0 {
                return "I couldn't find any matching places."
            }
            if count == 1 {
                return "\(view.primaryQuestion) I found \(view.rows[0].name)."
            }
            return "\(view.primaryQuestion) I found \(count) places."
        }
    }

    private static func primaryQuestionText(intent: QueryIntent, state: ResultsState) -> String {
        if state == .ambiguous {
            return "Showing places that might fit"
        }
        let parts = intentParts(intent: intent)
        if parts.isEmpty {
            return "Places near you"
        }
        return "Places that match: \(parts.joined(separator: ", "))"
    }

    private static func intentParts(intent: QueryIntent) -> [String] {
        var parts: [String] = []
        for category in intent.categories {
            parts.append(categoryDisplay(category))
        }
        for attribute in intent.preferredAttributes.union(intent.requiredAttributes) {
            parts.append(attribute.replacingOccurrences(of: "_", with: " "))
        }
        if intent.temporalConstraint != nil {
            parts.append("open now")
        }
        return parts
    }

    private static func whyThisMatched(result: RankedResult) -> String {
        if result.constraintsSatisfied.isEmpty {
            return "Matched your search"
        }
        let joined = result.constraintsSatisfied.sorted().joined(separator: ", ")
        return "Matched: \(joined)"
    }

    private static func emptyExplanation(intent: QueryIntent) -> String {
        let parts = intentParts(intent: intent)
        if parts.isEmpty {
            return "No places match your search."
        }
        return "No places match all of: \(parts.joined(separator: ", "))."
    }

    private static func suggestedRelaxation(intent: QueryIntent) -> String? {
        if intent.temporalConstraint != nil {
            return "Try without 'open now'"
        }
        if !intent.preferredAttributes.isEmpty {
            let attribute = intent.preferredAttributes.sorted().first?
                .replacingOccurrences(of: "_", with: " ")
            return "Try without '\(attribute ?? "that filter")'"
        }
        return nil
    }

    private static func categoryDisplay(_ category: String) -> String {
        switch category {
        case "coffee": return "coffee"
        case "food": return "food"
        case "retail": return "retail"
        case "service": return "service"
        default: return category
        }
    }
}
