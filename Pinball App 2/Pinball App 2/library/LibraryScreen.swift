import SwiftUI

struct LibraryScreen: View {
    @StateObject var viewModel = PinballLibraryViewModel()
    @EnvironmentObject var appNavigation: AppNavigationModel
    @State var viewportWidth: CGFloat = 0
    @State var viewportHeight: CGFloat = 0
    @State var isSearchPresented = false
    @State var navigationPath: [String] = []
    @Namespace var cardTransition
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
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
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            updateViewport(geo.size)
                        }
                        .onChange(of: geo.size) { _, newValue in
                            updateViewport(newValue)
                    }
                }
            )
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !viewModel.games.isEmpty {
                        if layoutMetrics.isCompactWidth {
                            Button {
                                isSearchPresented = true
                            } label: {
                                AppToolbarSearchTriggerLabel()
                            }
                            .buttonStyle(.plain)
                        }

                        Menu {
                            filterMenuSections
                        } label: {
                            AppToolbarFilterTriggerLabel()
                        }
                        .buttonStyle(.plain)
                    }
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
                libraryDetailDestination(for: gameID)
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

    @ViewBuilder
    private func libraryDetailDestination(for gameID: String) -> some View {
        if let game = viewModel.games.first(where: { $0.id == gameID }) {
            LibraryDetailScreen(game: game)
                .appCardZoomTransition(sourceID: gameID, in: cardTransition, reduceMotion: reduceMotion)
                .onAppear {
                    appNavigation.lastViewedLibraryGameID = gameID
                    LibraryActivityLog.log(gameID: gameID, gameName: game.name, kind: .browseGame)
                }
        } else {
            Text("Game not found.")
                .foregroundStyle(.secondary)
        }
    }

}

#Preview {
    LibraryScreen()
}

struct LibraryScreenLayoutMetrics {
    let viewportWidth: CGFloat
    let viewportHeight: CGFloat
    let horizontalSizeClass: UserInterfaceSizeClass?

    var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }

    var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(isLargeTablet: isLargeTablet)
    }

    var readableContentWidth: CGFloat? {
        AppLayout.maxReadableContentWidth(isLargeTablet: isLargeTablet)
    }

    var gridSpacing: CGFloat { 12 }
    var isLandscapeViewport: Bool { viewportWidth > viewportHeight }
    var columnCount: Int { isLandscapeViewport ? 4 : 2 }

    var contentAvailableWidth: CGFloat {
        max(0, viewportWidth - (contentHorizontalPadding * 2))
    }

    var estimatedColumnWidth: CGFloat {
        guard columnCount > 0 else { return 0 }
        let totalSpacing = gridSpacing * CGFloat(max(0, columnCount - 1))
        return max(0, (contentAvailableWidth - totalSpacing) / CGFloat(columnCount))
    }

    var cardTotalHeight: CGFloat {
        max(112, estimatedColumnWidth * 0.75)
    }

    var cardInfoHeight: CGFloat {
        min(88, max(68, cardTotalHeight * 0.58))
    }

    var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: gridSpacing),
            count: columnCount
        )
    }
}
