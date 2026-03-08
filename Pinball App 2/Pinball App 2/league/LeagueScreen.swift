import SwiftUI

struct LeagueScreen: View {
    @StateObject private var previewModel = LeaguePreviewModel()

    var body: some View {
        NavigationStack {
            LeagueShellContent(previewModel: previewModel) { destination in
                AnyView(LeagueDestinationView(destination: destination))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await previewModel.loadIfNeeded()
        }
    }
}


#Preview {
    LeagueScreen()
}
