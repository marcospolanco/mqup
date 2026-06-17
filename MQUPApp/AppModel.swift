import Foundation
import MQUPEngine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var submission: SearchSubmission?
    @Published var queryText = "coffee shops with parking open now"
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var coordinator: SearchCoordinator?

    func bootstrap() {
        guard coordinator == nil else { return }
        do {
            guard let url = Bundle.main.url(forResource: "pois", withExtension: "json")
                ?? Bundle.main.url(forResource: "pois", withExtension: "json", subdirectory: "Resources") else {
                throw POILoaderError.missingFile
            }
            let pois = try POILoader.load(from: url)
            coordinator = try SearchCoordinator(pois: pois)
        } catch {
            errorMessage = "Could not load places data."
        }
    }

    func search(now: Date = Date()) {
        guard let coordinator else {
            errorMessage = "Search is not ready yet."
            return
        }
        isSearching = true
        errorMessage = nil
        do {
            submission = try coordinator.submit(query: queryText, now: now)
        } catch {
            errorMessage = "Something went wrong while searching."
        }
        isSearching = false
    }
}
