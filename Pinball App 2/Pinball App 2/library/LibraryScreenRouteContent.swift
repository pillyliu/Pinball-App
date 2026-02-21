import SwiftUI

extension LibraryScreen {
    var sourceMenuSection: some View {
        Group {
            if !viewModel.sources.isEmpty {
                Section("Library") {
                    ForEach(viewModel.sources) { source in
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
                    viewModel.sortOption = option
                } label: {
                    selectableMenuLabel(option.menuLabel, isSelected: viewModel.sortOption == option)
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
                }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                    ForEach(viewModel.sortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }
            }
        }
    }

    func gameCard(for game: PinballGame) -> some View {
        NavigationLink(value: game.id) {
            let card = VStack(alignment: .leading, spacing: 0) {
                FallbackAsyncImageView(
                    candidates: game.libraryPlayfieldCandidates,
                    emptyMessage: game.playfieldLocalURL == nil ? "No image" : nil,
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity)
                .frame(height: cardImageHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(height: 44, alignment: .topLeading)

                    Text(game.manufacturerYearLine)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(game.locationBankLine)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .appPanelStyle()
            .contentShape(Rectangle())

            if reduceMotion {
                card
            } else {
                card
                    .matchedTransitionSource(id: game.id, in: cardTransition)
            }
        }
        .id(game.id)
        .buttonStyle(.plain)
    }

    func consumeLibraryDeepLink() {
        guard let gameID = appNavigation.libraryGameIDToOpen else { return }
        guard viewModel.games.contains(where: { $0.id == gameID }) else { return }
        navigationPath = [gameID]
        appNavigation.libraryGameIDToOpen = nil
    }
}
