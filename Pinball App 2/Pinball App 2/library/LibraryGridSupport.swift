import SwiftUI

struct LibraryListContent: View {
    let games: [PinballGame]
    let isLoading: Bool
    let errorMessage: String?
    let showGroupedView: Bool
    let sections: [PinballGroupSection]
    let visibleGames: [PinballGame]
    let hasMoreVisibleGames: Bool
    let gridColumns: [GridItem]
    let gridSpacing: CGFloat
    let cardTotalHeight: CGFloat
    let cardInfoHeight: CGFloat
    let scrollIndicatorTrailingInset: CGFloat
    let reduceMotion: Bool
    let cardTransition: Namespace.ID
    let onLoadMore: (String?) -> Void

    var body: some View {
        Group {
            if games.isEmpty {
                LibraryEmptyState(
                    isLoading: isLoading,
                    errorMessage: errorMessage
                )
            } else {
                LibraryGameScrollContent(
                    showGroupedView: showGroupedView,
                    sections: sections,
                    visibleGames: visibleGames,
                    hasMoreVisibleGames: hasMoreVisibleGames,
                    gridColumns: gridColumns,
                    gridSpacing: gridSpacing,
                    cardTotalHeight: cardTotalHeight,
                    cardInfoHeight: cardInfoHeight,
                    scrollIndicatorTrailingInset: scrollIndicatorTrailingInset,
                    reduceMotion: reduceMotion,
                    cardTransition: cardTransition,
                    onLoadMore: onLoadMore
                )
            }
        }
    }
}

struct LibraryEmptyState: View {
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                AppFullscreenStatusOverlay(
                    text: "Loading library…",
                    showsProgress: true
                )
            } else if let errorMessage, !errorMessage.isEmpty {
                AppPanelStatusCard(
                    text: errorMessage,
                    isError: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                AppPanelEmptyCard(text: "No data loaded.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
