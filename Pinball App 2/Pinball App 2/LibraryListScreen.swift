import SwiftUI

struct LibraryListScreen: View {
    @StateObject private var viewModel = PinballLibraryViewModel()
    @State private var viewportWidth: CGFloat = 0
    @State private var isSearchPresented = false
    @Namespace private var cardTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }
    private var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(verticalSizeClass: verticalSizeClass, isLargeTablet: isLargeTablet)
    }
    private var readableContentWidth: CGFloat? {
        AppLayout.maxReadableContentWidth(isLargeTablet: isLargeTablet)
    }
    private var gridMinCardWidth: CGFloat {
        if isLargeTablet { return 220 }
        return 170
    }
    private var lastVisibleGameID: String? {
        viewModel.sortedFilteredGames.last?.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                content
                    .appReadableWidth(maxWidth: readableContentWidth)
                    .padding(.horizontal, contentHorizontalPadding)
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newValue in
                            viewportWidth = newValue
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
                        sortMenuSection
                        bankMenuSection
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var sortMenuSection: some View {
        Section("Sort") {
            ForEach(PinballLibrarySortOption.allCases) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    selectableMenuLabel(option.menuLabel, isSelected: viewModel.sortOption == option)
                }
            }
        }
    }

    private var bankMenuSection: some View {
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

    @ViewBuilder
    private func selectableMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private var content: some View {
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
            ScrollViewReader { proxy in
                scrollableContent
                    .onChange(of: isLandscapePhone) { wasLandscape, isLandscape in
                        guard wasLandscape, !isLandscape else { return }
                        guard let lastVisibleGameID else { return }
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastVisibleGameID, anchor: .bottom)
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if viewModel.showGroupedView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { idx, section in
                        if idx > 0 {
                            AppSectionDivider()
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinCardWidth), spacing: 12)], spacing: 12) {
                            ForEach(section.games) { game in
                                gameCard(for: game)
                            }
                        }
                    }
                }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinCardWidth), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.sortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }
            }
        }
    }

    private func gameCard(for game: PinballGame) -> some View {
        NavigationLink {
            if reduceMotion {
                PinballGameDetailView(game: game)
            } else {
                PinballGameDetailView(game: game)
                    .navigationTransition(.zoom(sourceID: game.id, in: cardTransition))
            }
        } label: {
            let card = VStack(alignment: .leading, spacing: 0) {
                FallbackAsyncImageView(
                    candidates: game.libraryPlayfieldCandidates,
                    emptyMessage: game.playfieldLocalURL == nil ? "No image" : nil
                )
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name)
                        .font(isLargeTablet ? .title3 : .headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(height: isLargeTablet ? 52 : 44, alignment: .topLeading)

                    Text(game.manufacturerYearLine)
                        .font(isLargeTablet ? .footnote : .caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(game.locationBankLine)
                        .font(isLargeTablet ? .footnote : .caption)
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
}

#Preview {
    LibraryListScreen()
}
