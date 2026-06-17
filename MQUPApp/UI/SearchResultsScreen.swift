import MapKit
import MQUPEngine
import SwiftUI

struct SearchResultsScreen: View {
    let viewModel: SearchResultsView
    var onResultTap: (UUID) -> Void = { _ in }
    @State private var selectedID: UUID?
    @State private var expandedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.primaryQuestion)
                .font(.headline)
                .padding(.horizontal)

            if viewModel.state == .loading {
                ProgressView("Finding places…")
                    .padding()
            }

            if let empty = viewModel.emptyState {
                VStack(alignment: .leading, spacing: 8) {
                    Text(empty.explanation)
                    if let hint = empty.suggestedRelaxation {
                        Text(hint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }

            mapSection
            listSection

            #if DEBUG
            Text("Latency: \(viewModel.totalLatencyMs) ms")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            #endif
        }
    }

    private var mapSection: some View {
        Map(position: .constant(.region(region))) {
            ForEach(viewModel.mapAnnotations, id: \.id) { annotation in
                Marker(annotation.title, coordinate: annotation.coordinate.clLocationCoordinate2D)
                    .tint(annotation.isPrimary ? .red : .blue)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var listSection: some View {
        List(viewModel.rows, id: \.id, selection: $selectedID) { row in
            ResultRow(
                viewModel: row,
                isExpanded: expandedID == row.id,
                onToggleWhy: {
                    expandedID = expandedID == row.id ? nil : row.id
                },
                onNavigate: {
                    onResultTap(row.id)
                    NavigationLauncher.openInMaps(
                        name: row.name,
                        latitude: row.latitude,
                        longitude: row.longitude
                    )
                }
            )
        }
        .listStyle(.plain)
    }

    private var region: MKCoordinateRegion {
        guard let first = viewModel.mapAnnotations.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.323, longitude: -122.032),
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            )
        }
        return MKCoordinateRegion(
            center: first.coordinate.clLocationCoordinate2D,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    }
}
