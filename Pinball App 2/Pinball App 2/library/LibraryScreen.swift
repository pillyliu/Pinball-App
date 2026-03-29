import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject var appNavigation: AppNavigationModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject var viewModel = PinballLibraryViewModel()
    @State var viewportWidth: CGFloat = 0
    @State var viewportHeight: CGFloat = 0
    @State var isSearchPresented = false
    @State var navigationPath: [String] = []
    @Namespace var cardTransition

    var layoutMetrics: LibraryScreenLayoutMetrics {
        LibraryScreenLayoutMetrics(
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AppScreen(dismissesKeyboardOnTap: false) {
                content
                    .appReadableWidth(maxWidth: layoutMetrics.readableContentWidth)
                    .padding(.horizontal, layoutMetrics.contentHorizontalPadding)
            }
            .background(LibraryViewportObserver(onViewportChange: updateViewport))
            .searchable(
                text: $viewModel.query,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: "Search games"
            )
            .onAppear {
                isSearchPresented = false
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                LibraryScreenToolbarControls(
                    hasGames: !viewModel.games.isEmpty,
                    isCompactWidth: layoutMetrics.isCompactWidth,
                    isSearchPresented: $isSearchPresented
                ) {
                    filterMenuSections
                }
            }
            .task {
                await handleInitialLoad()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pinballLibrarySourcesDidChange)) { _ in
                Task {
                    await handleSourceChange()
                }
            }
            .onChange(of: appNavigation.libraryGameIDToOpen) { _, _ in
                consumeLibraryDeepLinkIfPossible()
            }
            .onChange(of: viewModel.games.count) { _, _ in
                consumeLibraryDeepLinkIfPossible()
            }
            .navigationDestination(for: String.self) { gameID in
                LibraryScreenDetailDestination(
                    gameID: gameID,
                    games: viewModel.games,
                    cardTransition: cardTransition,
                    reduceMotion: reduceMotion,
                    onGameAppear: handleDetailGameAppear
                )
            }
        }
    }

    private func updateViewport(_ size: CGSize) {
        viewportWidth = size.width
        viewportHeight = size.height
    }

    private func handleInitialLoad() async {
        await viewModel.loadIfNeeded()
        consumeLibraryDeepLinkIfPossible()
    }

    private func handleSourceChange() async {
        await viewModel.refresh()
        consumeLibraryDeepLinkIfPossible()
    }

    private func consumeLibraryDeepLinkIfPossible() {
        guard let gameID = appNavigation.libraryGameIDToOpen else { return }
        guard viewModel.games.contains(where: { $0.id == gameID }) else { return }
        navigationPath = [gameID]
        appNavigation.libraryGameIDToOpen = nil
    }

    private func handleDetailGameAppear(_ game: PinballGame) {
        appNavigation.lastViewedLibraryGameID = game.id
        LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .browseGame)
    }
}

#Preview {
    LibraryScreen()
}
