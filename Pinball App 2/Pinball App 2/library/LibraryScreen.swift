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
    var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    var isCompactWidth: Bool { horizontalSizeClass == .compact }
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
    var cardImageHeight: CGFloat {
        // Use a shorter viewport than 16:9 so the 16:9 source fills width and crops vertically.
        max(84, estimatedColumnWidth * 0.50)
    }
    var gridColumns: [GridItem] {
        return Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: gridSpacing), count: columnCount)
    }
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

                content
                    .appReadableWidth(maxWidth: readableContentWidth)
                    .padding(.horizontal, contentHorizontalPadding)
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            viewportWidth = geo.size.width
                            viewportHeight = geo.size.height
                        }
                        .onChange(of: geo.size) { _, newValue in
                            viewportWidth = newValue.width
                            viewportHeight = newValue.height
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
                    if isCompactWidth {
                        Button {
                            isSearchPresented = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }

                    Menu {
                        filterMenuSections
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await viewModel.loadIfNeeded()
                consumeLibraryDeepLink()
            }
            .onChange(of: appNavigation.libraryGameIDToOpen) { _, _ in
                consumeLibraryDeepLink()
            }
            .onChange(of: viewModel.games.count) { _, _ in
                consumeLibraryDeepLink()
            }
            .navigationDestination(for: String.self) { gameID in
                if let game = viewModel.games.first(where: { $0.id == gameID }) {
                    LibraryDetailScreen(game: game)
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
    }

}

#Preview {
    LibraryScreen()
}
