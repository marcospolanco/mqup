import MQUPEngine
import SwiftUI

struct ResultRow: View {
    let viewModel: ResultRowView
    let isExpanded: Bool
    let onToggleWhy: () -> Void
    let onNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.name)
                        .font(.headline)
                    if viewModel.showCategoryBadge {
                        Text(viewModel.category.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text(viewModel.whyThisMatched)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Go", action: onNavigate)
                    .buttonStyle(.borderedProminent)
            }

            if !viewModel.constraintsMissed.isEmpty {
                Text("Missing: \(viewModel.constraintsMissed.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button(isExpanded ? "Hide why this result" : "Why this result?", action: onToggleWhy)
                .font(.caption)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matched: \(viewModel.constraintsSatisfied.joined(separator: ", "))")
                    if !viewModel.constraintsMissed.isEmpty {
                        Text("Did not match: \(viewModel.constraintsMissed.joined(separator: ", "))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
