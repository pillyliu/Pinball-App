import SwiftUI

struct LibraryDetailScreen: View {
    let game: PinballGame
    @StateObject private var viewModel: PinballGameInfoViewModel
    @State private var activeVideoID: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL

    init(game: PinballGame) {
        self.game = game
        _viewModel = StateObject(wrappedValue: PinballGameInfoViewModel(pathCandidates: game.gameinfoPathCandidates))
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 14

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
                    LibraryDetailSourcesCard(game: game)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AppBackground())
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .appEdgeBackGesture(dismiss: dismiss)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
