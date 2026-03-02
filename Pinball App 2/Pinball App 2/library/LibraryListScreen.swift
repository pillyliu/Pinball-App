import SwiftUI

extension LibraryScreen {
    var sourceMenuSection: some View {
        Group {
            if !viewModel.sources.isEmpty {
                Section("Library") {
                    ForEach(viewModel.visibleSources) { source in
                        Button {
                            viewModel.selectSource(source.id)
                        } label: {
                            selectableMenuLabel(source.name, isSelected: viewModel.selectedSource?.id == source.id)
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
                    selectableMenuLabel(viewModel.menuLabel(for: option), isSelected: viewModel.sortOption == option)
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
                        selectableMenuLabel("All banks", isSelected: viewModel.selectedBank == nil)
                    }

                    ForEach(viewModel.bankOptions, id: \.self) { bank in
                        Button {
                            viewModel.selectedBank = bank
                        } label: {
                            selectableMenuLabel("Bank \(bank)", isSelected: viewModel.selectedBank == bank)
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
    func selectableMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    var content: some View {
        if viewModel.games.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isLoading {
                    Text("Loading library...")
                        .foregroundStyle(.secondary)
                } else if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No data loaded.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                    ForEach(viewModel.visibleSortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }

                loadMoreFooter
            }
        }
    }

    func gameCard(for game: PinballGame) -> some View {
        NavigationLink(value: game.id) {
            let card = GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.82))

                    FallbackAsyncImageView(
                        candidates: game.libraryPlayfieldCandidates,
                        emptyMessage: game.playfieldLocalURL == nil ? "No image" : nil,
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
            HStack(alignment: .top, spacing: 6) {
                Text(game.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
                    .lineSpacing(-1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            }
            .frame(height: 40, alignment: .top)
            .clipped()

            HStack(spacing: 4) {
                Text(game.manufacturerYearLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if let variant = game.normalizedVariant {
                    Text(variant)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.5), in: Capsule())
                        .overlay {
                            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.7)
                        }
                        .frame(maxWidth: 84, alignment: .leading)
                        .layoutPriority(0)
                }
            }

            Text(game.locationBankLine.isEmpty ? " " : game.locationBankLine)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
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
