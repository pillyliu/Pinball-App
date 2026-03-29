import SwiftUI

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

struct LibraryViewportObserver: View {
    let onViewportChange: (CGSize) -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    onViewportChange(geo.size)
                }
                .onChange(of: geo.size) { _, newValue in
                    onViewportChange(newValue)
                }
        }
    }
}

struct LibraryScreenDetailDestination: View {
    let gameID: String
    let games: [PinballGame]
    let cardTransition: Namespace.ID
    let reduceMotion: Bool
    let onGameAppear: (PinballGame) -> Void

    private var game: PinballGame? {
        games.first(where: { $0.id == gameID })
    }

    var body: some View {
        Group {
            if let game {
                LibraryDetailScreen(game: game)
                    .appCardZoomTransition(sourceID: gameID, in: cardTransition, reduceMotion: reduceMotion)
                    .onAppear {
                        onGameAppear(game)
                    }
            } else {
                Text("Game not found.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LibraryScreenToolbarControls<MenuContent: View>: ToolbarContent {
    let hasGames: Bool
    let isCompactWidth: Bool
    @Binding var isSearchPresented: Bool
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if hasGames {
                if isCompactWidth {
                    Button {
                        isSearchPresented = true
                    } label: {
                        AppToolbarSearchTriggerLabel()
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    menuContent()
                } label: {
                    AppToolbarFilterTriggerLabel()
                }
                .buttonStyle(.plain)
            }
        }
    }
}
