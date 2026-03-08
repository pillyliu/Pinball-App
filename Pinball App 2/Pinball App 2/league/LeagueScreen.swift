import SwiftUI

struct LeagueScreen: View {
    @StateObject private var previewModel = LeaguePreviewModel()

    var body: some View {
        NavigationStack {
            LeagueShellContent(previewModel: previewModel) { destination in
                AnyView(destinationView(for: destination))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await previewModel.loadIfNeeded()
        }
    }

    private func destinationView(for destination: LeagueDestination) -> AnyView {
        switch destination {
        case .stats:
            AnyView(
                StatsScreen(embeddedInNavigation: true)
                    .navigationBarTitleDisplayMode(.inline)
            )
        case .standings:
            AnyView(
                StandingsScreen(embeddedInNavigation: true)
                    .navigationBarTitleDisplayMode(.inline)
            )
        case .targets:
            AnyView(
                TargetsScreen(embeddedInNavigation: true)
                    .navigationBarTitleDisplayMode(.inline)
            )
        }
    }

}


#Preview {
    LeagueScreen()
}
