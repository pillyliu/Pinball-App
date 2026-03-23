import SwiftUI

private enum PracticeGameSearchTab: String, CaseIterable, Identifiable {
    case search = "Search"
    case recent = "Recent"

    var id: String { rawValue }
}

struct PracticeGameSearchSheet: View {
    let games: [PinballGame]
    let isLoadingGames: Bool
    let onLoadGames: () async -> Void
    let onSelectGame: (String) -> Void

    @State private var selectedTab: PracticeGameSearchTab = .search
    @State private var filters = PracticeGameSearchFilters()
    @State private var isAdvancedExpanded = false
    @State private var recentGameIDs: [String] = PracticeGameSearchRecentStore.load()
    @State private var searchIndex = PracticeGameSearchIndex.empty

    private var searchIndexRevision: String {
        games.map { game in
            [
                game.canonicalPracticeKey,
                game.sourceId,
                game.name,
                game.manufacturer ?? "",
                game.year.map(String.init) ?? "",
                game.opdbID ?? "",
                game.opdbMachineID ?? ""
            ]
            .joined(separator: "|")
        }
        .joined(separator: "\n")
    }

    private var filteredManufacturerSuggestions: [String] {
        searchIndex.manufacturerSuggestions(for: filters.manufacturerQuery)
    }

    private var hasSearchFilters: Bool {
        filters.hasFilters
    }

    private var filteredResults: [PracticeGameSearchResult] {
        searchIndex.filteredResults(using: filters)
    }

    private var recentResults: [PracticeGameSearchResult] {
        searchIndex.recentResults(for: recentGameIDs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Mode", selection: $selectedTab) {
                    ForEach(PracticeGameSearchTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .appSegmentedControlStyle()

                switch selectedTab {
                case .search:
                    searchTabContent
                case .recent:
                    recentTabContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .navigationTitle("Find Game")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await onLoadGames()
        }
        .task(id: searchIndexRevision) {
            rebuildSearchIndex()
        }
    }

    private var searchTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                AppNativeClearTextField(
                    placeholder: "Game name",
                    text: $filters.nameQuery,
                    autocapitalization: .words,
                    autocorrectionDisabled: true
                )

                DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            AppNativeClearTextField(
                                placeholder: "Manufacturer",
                                text: $filters.manufacturerQuery,
                                autocapitalization: .words,
                                autocorrectionDisabled: true
                            )

                            if !filteredManufacturerSuggestions.isEmpty &&
                                !filteredManufacturerSuggestions.contains(where: {
                                    $0.caseInsensitiveCompare(filters.manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                                }) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(filteredManufacturerSuggestions, id: \.self) { suggestion in
                                            Button(suggestion) {
                                                filters.manufacturerQuery = suggestion
                                            }
                                            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        AppNativeClearTextField(
                            placeholder: "Year",
                            text: $filters.yearQuery,
                            keyboardType: .numberPad
                        )

                        Menu {
                            Button("Any type") {
                                filters.selectedType = nil
                            }

                            ForEach(PracticeGameTypeFilter.allCases) { option in
                                Button(option.label) {
                                    filters.selectedType = option
                                }
                            }
                        } label: {
                            AppCompactFilterLabel(text: filters.selectedType?.label ?? "Any type")
                        }
                        .buttonStyle(.plain)

                        if hasSearchFilters {
                            Button("Clear filters") {
                                filters = PracticeGameSearchFilters()
                            }
                            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Advanced Filters")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(12)
            .appPanelStyle()

            if isLoadingGames && searchIndex.results.isEmpty {
                AppPanelStatusCard(
                    text: "Loading all OPDB games…",
                    showsProgress: true
                )
            } else if hasSearchFilters {
                AppSectionTitle(text: "\(filteredResults.count) Result\(filteredResults.count == 1 ? "" : "s")")
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredResults) { result in
                        searchResultButton(result)
                    }
                }
            } else {
                AppPanelEmptyCard(text: "Search by name or abbreviation. Open Advanced Filters for manufacturer, year, and game type.")
            }
        }
    }

    private var recentTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if recentResults.isEmpty {
                AppPanelEmptyCard(text: "Games opened from search will show up here.")
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(recentResults) { result in
                        searchResultButton(result)
                    }
                }
            }
        }
    }

    private func searchResultButton(_ result: PracticeGameSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.displayName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk)
                .multilineTextAlignment(.leading)

            Text(resultMetaLine(for: result))
                .font(.subheadline)
                .foregroundStyle(AppTheme.brandChalk)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
        .contentShape(RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous))
        .onTapGesture {
            recentGameIDs = PracticeGameSearchRecentStore.remember(result.canonicalGameID)
            onSelectGame(result.canonicalGameID)
        }
    }

    private func resultMetaLine(for result: PracticeGameSearchResult) -> String {
        searchIndex.metaLine(for: result)
    }

    private func rebuildSearchIndex() {
        searchIndex = PracticeGameSearchIndex(games: games)
    }
}
