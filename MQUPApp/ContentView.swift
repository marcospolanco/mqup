import SwiftUI
import MQUPEngine

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if let error = appModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                }
                if let viewModel = appModel.submission?.view {
                    SearchResultsScreen(viewModel: viewModel, onResultTap: appModel.donateResult)
                } else {
                    ContentUnavailableView(
                        "Find places that fit",
                        systemImage: "magnifyingglass",
                        description: Text("Describe what you want — coffee, parking, open now.")
                    )
                }
            }
            .navigationTitle("MQUP")
            .onAppear {
                appModel.bootstrap()
                if appModel.submission == nil {
                    appModel.search()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Ask for a place…", text: $appModel.queryText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { appModel.search() }
            Button("Search") { appModel.search() }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.isSearching)
        }
        .padding()
    }
}
