import SwiftUI

extension LibraryScreen {
    private var scrollIndicatorTrailingInset: CGFloat {
        4 - layoutMetrics.contentHorizontalPadding
    }

    var filterMenuSections: some View {
        LibraryFilterMenuSections(
            sources: viewModel.sources,
            visibleSources: viewModel.visibleSources,
            selectedSourceID: viewModel.selectedSource?.id,
            sortOptions: viewModel.sortOptions,
            selectedSortOption: viewModel.sortOption,
            menuLabel: viewModel.menuLabel(for:),
            supportsBankFilter: viewModel.supportsBankFilter,
            bankOptions: viewModel.bankOptions,
            selectedBank: viewModel.selectedBank,
            onSelectSource: viewModel.selectSource,
            onSelectSort: viewModel.selectSortOption,
            onSelectBank: { bank in
                viewModel.selectedBank = bank
            }
        )
    }

    @ViewBuilder
    var content: some View {
        LibraryListContent(
            games: viewModel.games,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            showGroupedView: viewModel.showGroupedView,
            sections: viewModel.sections,
            visibleGames: viewModel.visibleSortedFilteredGames,
            hasMoreVisibleGames: viewModel.hasMoreVisibleGames,
            gridColumns: layoutMetrics.gridColumns,
            gridSpacing: layoutMetrics.gridSpacing,
            cardTotalHeight: layoutMetrics.cardTotalHeight,
            cardInfoHeight: layoutMetrics.cardInfoHeight,
            scrollIndicatorTrailingInset: scrollIndicatorTrailingInset,
            reduceMotion: reduceMotion,
            cardTransition: cardTransition,
            onLoadMore: viewModel.loadMoreGamesIfNeeded(currentGameID:)
        )
    }
}
