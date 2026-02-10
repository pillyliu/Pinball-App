import SwiftUI

struct LibraryListScreen: View {
    @StateObject private var viewModel = PinballLibraryViewModel()
    @State private var controlsHeight: CGFloat = 96
    @State private var viewportWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }
    private let landscapeControlHeight: CGFloat = 40
    private var cardsTopBuffer: CGFloat {
        if isLandscapePhone {
            return max(14, controlsHeight - 30)
        }
        if isLargeTablet {
            return max(38, controlsHeight + 12)
        }
        return max(24, controlsHeight - 4)
    }
    private var scrollBottomClearance: CGFloat {
        isLandscapePhone ? 70 : 100
    }
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

                ZStack(alignment: .top) {
                    content
                        .appReadableWidth(maxWidth: readableContentWidth)
                        .padding(.horizontal, contentHorizontalPadding)
                        .ignoresSafeArea(edges: .bottom)

                    GeometryReader { geo in
                        let safeTop = geo.safeAreaInsets.top
                        let fadeHeight = isLandscapePhone
                            ? max(52, safeTop + 30)
                            : max(128, controlsHeight + safeTop + 22)

                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.black.opacity(0.62), location: 0.0),
                                .init(color: Color.black.opacity(0.62), location: 0.08),
                                .init(color: Color.black.opacity(0.32), location: 0.50),
                                .init(color: Color.black.opacity(0.17), location: 0.8),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: fadeHeight, alignment: .top)
                        .ignoresSafeArea(edges: [.top, .horizontal])
                        .allowsHitTesting(false)
                    }
                    .zIndex(0.5)

                    VStack(spacing: 8) {
                        controls
                            .appReadableWidth(maxWidth: readableContentWidth)
                            .padding(.horizontal, contentHorizontalPadding)
                            .padding(.top, 6)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: LibraryControlsHeightKey.self, value: geo.size.height)
                                }
                            )

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appReadableWidth(maxWidth: readableContentWidth)
                                .padding(.horizontal, contentHorizontalPadding)
                        }
                    }
                    .zIndex(1)
                }
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
            .toolbar(.hidden, for: .navigationBar)
            .onPreferenceChange(LibraryControlsHeightKey.self) { newValue in
                guard newValue > 0 else { return }
                controlsHeight = newValue
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var controls: some View {
        Group {
            if isLandscapePhone {
                GeometryReader { geo in
                    let spacing: CGFloat = 8
                    let total = max(0, geo.size.width - (spacing * 2))
                    let minBankWidth: CGFloat = 82
                    let minSortWidth: CGFloat = 130
                    let idealSortWidth: CGFloat = 190 // keep "Sort: Alphabetical" fully visible
                    // Nudge search wider so the search/sort gap sits on the screen center.
                    let centeredSearchWidth = (total * 0.5) + (spacing * 0.5)
                    let searchWidth = max(130, centeredSearchWidth)
                    let sortMaxAllowed = max(minSortWidth, total - searchWidth - minBankWidth)
                    let sortWidth = min(idealSortWidth, sortMaxAllowed)
                    let bankWidth = max(minBankWidth, total - searchWidth - sortWidth)

                    HStack(spacing: spacing) {
                        searchField
                            .frame(width: searchWidth)
                            .frame(height: landscapeControlHeight)
                        sortMenu
                            .frame(width: sortWidth)
                            .frame(height: landscapeControlHeight)
                        bankMenu
                            .frame(width: bankWidth)
                            .frame(height: landscapeControlHeight)
                    }
                }
                .frame(height: landscapeControlHeight)
            } else {
                VStack(spacing: 10) {
                    searchField
                    HStack(spacing: 8) {
                        sortMenu
                        bankMenu
                    }
                }
            }
        }
    }

    private var searchField: some View {
        TextField(
            "",
            text: $viewModel.query,
            prompt: Text("Search games...")
                .foregroundStyle(Color(white: 0.72))
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .font(isLargeTablet ? .body : .subheadline)
        .foregroundStyle(Color(white: 0.96))
        .padding(.horizontal, isLandscapePhone ? 11 : 12)
        .padding(.vertical, isLandscapePhone ? 6 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isLandscapePhone ? landscapeControlHeight : nil)
        .appGlassControlStyle()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(PinballLibrarySortOption.allCases) { option in
                Button(option.menuLabel) { viewModel.sortOption = option }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedSortLabel)
                    .font(isLandscapePhone || isLargeTablet ? .subheadline : .caption2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(isLandscapePhone || isLargeTablet ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isLandscapePhone ? 11 : 10)
            .padding(.vertical, isLandscapePhone ? 6 : 6)
            .frame(height: isLandscapePhone ? landscapeControlHeight : nil)
            .appGlassControlStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.white)
        .disabled(viewModel.games.isEmpty)
    }

    private var bankMenu: some View {
        Menu {
            Button("All banks") { viewModel.selectedBank = nil }
            ForEach(viewModel.bankOptions, id: \.self) { bank in
                Button("Bank \(bank)") { viewModel.selectedBank = bank }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedBankLabel)
                    .font(isLandscapePhone || isLargeTablet ? .subheadline : .caption2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(isLandscapePhone || isLargeTablet ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isLandscapePhone ? 11 : 10)
            .padding(.vertical, isLandscapePhone ? 6 : 6)
            .frame(height: isLandscapePhone ? landscapeControlHeight : nil)
            .appGlassControlStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.white)
        .disabled(viewModel.games.isEmpty)
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
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if viewModel.showGroupedView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { idx, section in
                        if idx > 0 {
                            Divider()
                                .overlay(Color.white)
                                .padding(.vertical, 10)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinCardWidth), spacing: 12)], spacing: 12) {
                            ForEach(section.games) { game in
                                gameCard(for: game)
                            }
                        }
                    }
                }
                .padding(.top, cardsTopBuffer)
                .padding(.bottom, scrollBottomClearance)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinCardWidth), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.sortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }
                .padding(.top, cardsTopBuffer)
                .padding(.bottom, scrollBottomClearance)
            }
        }
    }

    private func gameCard(for game: PinballGame) -> some View {
        NavigationLink {
            PinballGameDetailView(game: game)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                FallbackAsyncImageView(
                    candidates: game.libraryPlayfieldCandidates,
                    emptyMessage: game.playfieldLocalURL == nil ? "No image" : nil
                )
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name)
                        .font(isLargeTablet ? .title3 : .headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(height: isLargeTablet ? 52 : 44, alignment: .topLeading)

                    Text(game.manufacturerYearLine)
                        .font(isLargeTablet ? .footnote : .caption)
                        .foregroundStyle(Color(white: 0.7))
                        .lineLimit(1)

                    Text(game.locationBankLine)
                        .font(isLargeTablet ? .footnote : .caption)
                        .foregroundStyle(Color(white: 0.78))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .appPanelStyle()
            .contentShape(Rectangle())
        }
        .id(game.id)
        .buttonStyle(.plain)
    }
}

private struct LibraryControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 96
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    LibraryListScreen()
}
