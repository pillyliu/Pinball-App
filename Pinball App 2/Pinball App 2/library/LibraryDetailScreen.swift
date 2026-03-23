import SwiftUI

struct LibraryDetailScreen: View {
    let game: PinballGame
    @StateObject private var viewModel: PinballGameInfoViewModel
    @State private var activeVideoID: String?
    @Environment(\.openURL) private var openURL

    init(game: PinballGame) {
        self.game = game
        _viewModel = StateObject(wrappedValue: PinballGameInfoViewModel(pathCandidates: game.gameinfoPathCandidates))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LibraryDetailScreenshotSection(game: game)
                LibraryDetailSummaryCard(game: game)
                LibraryDetailVideosCard(
                    game: game,
                    activeVideoID: $activeVideoID,
                    usesDesktopLandscapeLayout: false,
                    openURL: openURL
                )
                LibraryDetailGameInfoCard(
                    status: viewModel.status,
                    markdownText: viewModel.markdownText
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .appEdgeBackGesture()
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
