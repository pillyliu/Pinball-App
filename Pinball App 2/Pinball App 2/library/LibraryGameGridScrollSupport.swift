import SwiftUI

struct LibraryGameScrollContent: View {
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
        ScrollView {
            if showGroupedView {
                groupedContent
            } else {
                ungroupedContent
            }
        }
        .contentMargins(.trailing, scrollIndicatorTrailingInset, for: .scrollIndicators)
    }

    private var groupedContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                if index > 0 {
                    AppSectionDivider()
                }

                gameGrid(for: section.games)
            }

            loadMoreFooter
        }
    }

    private var ungroupedContent: some View {
        Group {
            gameGrid(for: visibleGames)
            loadMoreFooter
        }
    }

    private func gameGrid(for games: [PinballGame]) -> some View {
        LibraryGameGrid(
            games: games,
            gridColumns: gridColumns,
            gridSpacing: gridSpacing,
            cardTotalHeight: cardTotalHeight,
            cardInfoHeight: cardInfoHeight,
            reduceMotion: reduceMotion,
            cardTransition: cardTransition,
            onLoadMore: onLoadMore
        )
    }

    private var loadMoreFooter: some View {
        LibraryLoadMoreFooter(
            hasMoreVisibleGames: hasMoreVisibleGames,
            onLoadMore: onLoadMore
        )
    }
}

struct LibraryLoadMoreFooter: View {
    let hasMoreVisibleGames: Bool
    let onLoadMore: (String?) -> Void

    var body: some View {
        Group {
            if hasMoreVisibleGames {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        onLoadMore(nil)
                    }
            }
        }
    }
}
