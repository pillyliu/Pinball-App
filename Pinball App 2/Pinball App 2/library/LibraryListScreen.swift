import SwiftUI

extension LibraryScreen {
    private var scrollIndicatorTrailingInset: CGFloat {
        4 - contentHorizontalPadding
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
            gridColumns: gridColumns,
            gridSpacing: gridSpacing,
            cardTotalHeight: cardTotalHeight,
            cardInfoHeight: cardInfoHeight,
            scrollIndicatorTrailingInset: scrollIndicatorTrailingInset,
            reduceMotion: reduceMotion,
            cardTransition: cardTransition,
            onLoadMore: viewModel.loadMoreGamesIfNeeded(currentGameID:)
        )
    }

    func consumeLibraryDeepLink() {
        guard let gameID = appNavigation.libraryGameIDToOpen else { return }
        guard viewModel.games.contains(where: { $0.id == gameID }) else { return }
        navigationPath = [gameID]
        appNavigation.libraryGameIDToOpen = nil
    }
}

private struct LibraryFilterMenuSections: View {
    let sources: [PinballLibrarySource]
    let visibleSources: [PinballLibrarySource]
    let selectedSourceID: String?
    let sortOptions: [PinballLibrarySortOption]
    let selectedSortOption: PinballLibrarySortOption
    let menuLabel: (PinballLibrarySortOption) -> String
    let supportsBankFilter: Bool
    let bankOptions: [Int]
    let selectedBank: Int?
    let onSelectSource: (String) -> Void
    let onSelectSort: (PinballLibrarySortOption) -> Void
    let onSelectBank: (Int?) -> Void

    var body: some View {
        Group {
            LibrarySourceMenuSection(
                sources: sources,
                visibleSources: visibleSources,
                selectedSourceID: selectedSourceID,
                onSelectSource: onSelectSource
            )
            LibrarySortMenuSection(
                sortOptions: sortOptions,
                selectedSortOption: selectedSortOption,
                menuLabel: menuLabel,
                onSelectSort: onSelectSort
            )
            LibraryBankMenuSection(
                supportsBankFilter: supportsBankFilter,
                bankOptions: bankOptions,
                selectedBank: selectedBank,
                onSelectBank: onSelectBank
            )
        }
    }
}

private struct LibrarySourceMenuSection: View {
    let sources: [PinballLibrarySource]
    let visibleSources: [PinballLibrarySource]
    let selectedSourceID: String?
    let onSelectSource: (String) -> Void

    var body: some View {
        Group {
            if !sources.isEmpty {
                Section("Library") {
                    ForEach(visibleSources) { source in
                        Button {
                            onSelectSource(source.id)
                        } label: {
                            AppSelectableMenuRow(text: source.name, isSelected: selectedSourceID == source.id)
                        }
                    }
                }
            }
        }
    }
}

private struct LibrarySortMenuSection: View {
    let sortOptions: [PinballLibrarySortOption]
    let selectedSortOption: PinballLibrarySortOption
    let menuLabel: (PinballLibrarySortOption) -> String
    let onSelectSort: (PinballLibrarySortOption) -> Void

    var body: some View {
        Section("Sort") {
            ForEach(sortOptions) { option in
                Button {
                    onSelectSort(option)
                } label: {
                    AppSelectableMenuRow(text: menuLabel(option), isSelected: selectedSortOption == option)
                }
            }
        }
    }
}

private struct LibraryBankMenuSection: View {
    let supportsBankFilter: Bool
    let bankOptions: [Int]
    let selectedBank: Int?
    let onSelectBank: (Int?) -> Void

    var body: some View {
        Group {
            if supportsBankFilter {
                Section("Bank") {
                    Button {
                        onSelectBank(nil)
                    } label: {
                        AppSelectableMenuRow(text: "All banks", isSelected: selectedBank == nil)
                    }

                    ForEach(bankOptions, id: \.self) { bank in
                        Button {
                            onSelectBank(bank)
                        } label: {
                            AppSelectableMenuRow(text: "Bank \(bank)", isSelected: selectedBank == bank)
                        }
                    }
                }
            }
        }
    }
}

private struct LibraryListContent: View {
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
            } else if showGroupedView {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            if index > 0 {
                                AppSectionDivider()
                            }

                            LibraryGameGrid(
                                games: section.games,
                                gridColumns: gridColumns,
                                gridSpacing: gridSpacing,
                                cardTotalHeight: cardTotalHeight,
                                cardInfoHeight: cardInfoHeight,
                                reduceMotion: reduceMotion,
                                cardTransition: cardTransition,
                                onLoadMore: onLoadMore
                            )
                        }

                        LibraryLoadMoreFooter(
                            hasMoreVisibleGames: hasMoreVisibleGames,
                            onLoadMore: onLoadMore
                        )
                    }
                }
                .contentMargins(.trailing, scrollIndicatorTrailingInset, for: .scrollIndicators)
            } else {
                ScrollView {
                    LibraryGameGrid(
                        games: visibleGames,
                        gridColumns: gridColumns,
                        gridSpacing: gridSpacing,
                        cardTotalHeight: cardTotalHeight,
                        cardInfoHeight: cardInfoHeight,
                        reduceMotion: reduceMotion,
                        cardTransition: cardTransition,
                        onLoadMore: onLoadMore
                    )

                    LibraryLoadMoreFooter(
                        hasMoreVisibleGames: hasMoreVisibleGames,
                        onLoadMore: onLoadMore
                    )
                }
                .contentMargins(.trailing, scrollIndicatorTrailingInset, for: .scrollIndicators)
            }
        }
    }
}

private struct LibraryEmptyState: View {
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

private struct LibraryGameGrid: View {
    let games: [PinballGame]
    let gridColumns: [GridItem]
    let gridSpacing: CGFloat
    let cardTotalHeight: CGFloat
    let cardInfoHeight: CGFloat
    let reduceMotion: Bool
    let cardTransition: Namespace.ID
    let onLoadMore: (String?) -> Void

    var body: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
            ForEach(games) { game in
                LibraryGameCard(
                    game: game,
                    cardTotalHeight: cardTotalHeight,
                    cardInfoHeight: cardInfoHeight,
                    reduceMotion: reduceMotion,
                    cardTransition: cardTransition,
                    onLoadMore: onLoadMore
                )
            }
        }
    }
}

private struct LibraryGameCard: View {
    let game: PinballGame
    let cardTotalHeight: CGFloat
    let cardInfoHeight: CGFloat
    let reduceMotion: Bool
    let cardTransition: Namespace.ID
    let onLoadMore: (String?) -> Void

    var body: some View {
        NavigationLink(value: game.id) {
            let card = GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.82))

                    FallbackAsyncImageView(
                        candidates: game.cardArtworkCandidates,
                        emptyMessage: game.cardArtworkCandidates.isEmpty ? "No image" : nil,
                        contentMode: .fill,
                        fillAlignment: .center,
                        layoutMode: .widthFillTopCropBottom
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.0), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 0.18),
                            .init(color: Color.black.opacity(0.50), location: 0.40),
                            .init(color: Color.black.opacity(0.70), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    LibraryCardOverlay(
                        game: game,
                        cardInfoHeight: cardInfoHeight
                    )
                    .frame(width: proxy.size.width, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardTotalHeight)
            .appPanelStyle()
            .contentShape(Rectangle())

            if reduceMotion {
                card
            } else {
                card
                    .matchedTransitionSource(id: game.id, in: cardTransition)
            }
        }
        .onAppear {
            onLoadMore(game.id)
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryCardOverlay: View {
    let game: PinballGame
    let cardInfoHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LibraryCardInlineTitleLabel(
                title: game.name,
                variant: game.normalizedVariant
            )
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)

            AppOverlaySubtitle(game.manufacturerYearCardLine)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            AppOverlaySubtitle(game.locationBankLine.isEmpty ? " " : game.locationBankLine, emphasis: 0.9)
                .lineLimit(1)
                .opacity(game.locationBankLine.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, minHeight: cardInfoHeight, maxHeight: cardInfoHeight, alignment: .topLeading)
    }
}

private struct LibraryLoadMoreFooter: View {
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

private struct LibraryCardInlineTitleLabel: UIViewRepresentable {
    let title: String
    let variant: String?

    private var resolvedVariant: String? {
        let trimmed = variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func makeUIView(context: Context) -> AppInlineTitleWithVariantUILabel {
        let label = AppInlineTitleWithVariantUILabel()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: AppInlineTitleWithVariantUILabel, context: Context) {
        uiView.configure(
            title: title,
            variant: resolvedVariant,
            lineLimit: 2,
            style: .overlay
        )
        uiView.accessibilityLabel = resolvedVariant.map { "\(title), \($0)" } ?? title
    }
}
