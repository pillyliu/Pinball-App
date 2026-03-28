import SwiftUI

extension LibraryScreen {
    private var scrollIndicatorTrailingInset: CGFloat {
        4 - contentHorizontalPadding
    }

    var sourceMenuSection: some View {
        Group {
            if !viewModel.sources.isEmpty {
                Section("Library") {
                    ForEach(viewModel.visibleSources) { source in
                        Button {
                            viewModel.selectSource(source.id)
                        } label: {
                            AppSelectableMenuRow(text: source.name, isSelected: viewModel.selectedSource?.id == source.id)
                        }
                    }
                }
            }
        }
    }

    var sortMenuSection: some View {
        Section("Sort") {
            ForEach(viewModel.sortOptions) { option in
                Button {
                    viewModel.selectSortOption(option)
                } label: {
                    AppSelectableMenuRow(text: viewModel.menuLabel(for: option), isSelected: viewModel.sortOption == option)
                }
            }
        }
    }

    var bankMenuSection: some View {
        Group {
            if viewModel.supportsBankFilter {
                Section("Bank") {
                    Button {
                        viewModel.selectedBank = nil
                    } label: {
                        AppSelectableMenuRow(text: "All banks", isSelected: viewModel.selectedBank == nil)
                    }

                    ForEach(viewModel.bankOptions, id: \.self) { bank in
                        Button {
                            viewModel.selectedBank = bank
                        } label: {
                            AppSelectableMenuRow(text: "Bank \(bank)", isSelected: viewModel.selectedBank == bank)
                        }
                    }
                }
            }
        }
    }

    var filterMenuSections: some View {
        Group {
            sourceMenuSection
            sortMenuSection
            bankMenuSection
        }
    }

    @ViewBuilder
    var content: some View {
        if viewModel.games.isEmpty {
            if viewModel.isLoading {
                AppFullscreenStatusOverlay(
                    text: "Loading library…",
                    showsProgress: true
                )
            } else {
                Group {
                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        AppPanelStatusCard(
                            text: errorMessage,
                            isError: true
                        )
                    } else {
                        AppPanelEmptyCard(text: "No data loaded.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            scrollableContent
        }
    }

    @ViewBuilder
    var scrollableContent: some View {
        if viewModel.showGroupedView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { idx, section in
                        if idx > 0 {
                            AppSectionDivider()
                        }

                        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                            ForEach(section.games) { game in
                                gameCard(for: game)
                            }
                        }
                    }

                    loadMoreFooter
                }
            }
            .contentMargins(.trailing, scrollIndicatorTrailingInset, for: .scrollIndicators)
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                    ForEach(viewModel.visibleSortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }

                loadMoreFooter
            }
            .contentMargins(.trailing, scrollIndicatorTrailingInset, for: .scrollIndicators)
        }
    }

    func gameCard(for game: PinballGame) -> some View {
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

                    libraryCardOverlay(for: game)
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
            viewModel.loadMoreGamesIfNeeded(currentGameID: game.id)
        }
        .buttonStyle(.plain)
    }

    private func libraryCardOverlay(for game: PinballGame) -> some View {
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

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.hasMoreVisibleGames {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    viewModel.loadMoreGamesIfNeeded(currentGameID: nil)
                }
        }
    }

    func consumeLibraryDeepLink() {
        guard let gameID = appNavigation.libraryGameIDToOpen else { return }
        guard viewModel.games.contains(where: { $0.id == gameID }) else { return }
        navigationPath = [gameID]
        appNavigation.libraryGameIDToOpen = nil
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
