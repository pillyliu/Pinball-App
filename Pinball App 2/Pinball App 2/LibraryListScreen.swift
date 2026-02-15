import SwiftUI

struct LibraryListScreen: View {
    @StateObject private var viewModel = PinballLibraryViewModel()
    @EnvironmentObject private var appNavigation: AppNavigationModel
    @State private var viewportWidth: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isSearchPresented = false
    @State private var navigationPath: [String] = []
    @Namespace private var cardTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(isLargeTablet: isLargeTablet)
    }
    private var readableContentWidth: CGFloat? {
        AppLayout.maxReadableContentWidth(isLargeTablet: isLargeTablet)
    }
    private var gridSpacing: CGFloat { 12 }
    private var isLandscapeViewport: Bool { viewportWidth > viewportHeight }
    private var columnCount: Int { isLandscapeViewport ? 4 : 2 }
    private var contentAvailableWidth: CGFloat {
        max(0, viewportWidth - (contentHorizontalPadding * 2))
    }
    private var estimatedColumnWidth: CGFloat {
        guard columnCount > 0 else { return 0 }
        let totalSpacing = gridSpacing * CGFloat(max(0, columnCount - 1))
        return max(0, (contentAvailableWidth - totalSpacing) / CGFloat(columnCount))
    }
    private var cardImageHeight: CGFloat {
        // Use a shorter viewport than 16:9 so the 16:9 source fills width and crops vertically.
        max(84, estimatedColumnWidth * 0.50)
    }
    private var gridColumns: [GridItem] {
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
                        sortMenuSection
                        bankMenuSection
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
                    PinballGameDetailView(game: game)
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
            scrollableContent
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

    private func gameCard(for game: PinballGame) -> some View {
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

    private func consumeLibraryDeepLink() {
        guard let gameID = appNavigation.libraryGameIDToOpen else { return }
        guard viewModel.games.contains(where: { $0.id == gameID }) else { return }
        navigationPath = [gameID]
        appNavigation.libraryGameIDToOpen = nil
    }
}

#Preview {
    LibraryListScreen()
}
