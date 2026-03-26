import SwiftUI
import Combine

struct LeagueScreen: View {
    @StateObject private var previewModel = LeaguePreviewModel()

    var body: some View {
        NavigationStack {
            AppScreen {
                LeagueShellContent(previewModel: previewModel) { destination in
                    AnyView(LeagueDestinationView(destination: destination))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await previewModel.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pinballLeaguePreviewNeedsRefresh)) { _ in
            Task { await previewModel.reload() }
        }
    }
}


#Preview {
    LeagueScreen()
}
