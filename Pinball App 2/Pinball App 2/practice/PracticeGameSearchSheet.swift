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
    @State private var nameQuery: String = ""
    @State private var manufacturerQuery: String = ""
    @State private var yearQuery: String = ""
    @State private var selectedType: PracticeGameTypeFilter?
    @State private var isAdvancedExpanded = false
    @State private var recentGameIDs: [String] = PracticeGameSearchRecentStore.load()
    @State private var indexedResults: [PracticeGameSearchResult] = []
    @State private var indexedManufacturers: [String] = []

    private var manufacturerOptions: [String] {
        indexedManufacturers
    }

    private var filteredManufacturerSuggestions: [String] {
        practiceSearchManufacturerSuggestions(options: manufacturerOptions, query: manufacturerQuery)
    }

    private var hasSearchFilters: Bool {
        !nameQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !yearQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedType != nil
    }

    private var filteredResults: [PracticeGameSearchResult] {
        filteredPracticeSearchResults(
            results: indexedResults,
            nameQuery: nameQuery,
            manufacturerQuery: manufacturerQuery,
            yearQuery: yearQuery,
            selectedType: selectedType
        )
    }

    private var recentResults: [PracticeGameSearchResult] {
        let lookup = Dictionary(uniqueKeysWithValues: indexedResults.map { ($0.canonicalGameID, $0) })
        return recentGameIDs.compactMap { lookup[$0] }
    }

    var body: some View {
        ZStack {
            AppBackground()

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
        }
        .navigationTitle("Find Game")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await onLoadGames()
        }
        .task(id: games.count) {
            rebuildSearchIndex()
        }
    }

    private var searchTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Game name", text: $nameQuery)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Manufacturer", text: $manufacturerQuery)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .appControlStyle()

                            if !filteredManufacturerSuggestions.isEmpty &&
                                !filteredManufacturerSuggestions.contains(where: {
                                    $0.caseInsensitiveCompare(manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                                }) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(filteredManufacturerSuggestions, id: \.self) { suggestion in
                                            Button(suggestion) {
                                                manufacturerQuery = suggestion
                                            }
                                            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        TextField("Year", text: $yearQuery)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        Menu {
                            Button("Any type") {
                                selectedType = nil
                            }

                            ForEach(PracticeGameTypeFilter.allCases) { option in
                                Button(option.label) {
                                    selectedType = option
                                }
                            }
                        } label: {
                            AppCompactFilterLabel(text: selectedType?.label ?? "Any type")
                        }
                        .buttonStyle(.plain)

                        if hasSearchFilters {
                            Button("Clear filters") {
                                nameQuery = ""
                                manufacturerQuery = ""
                                yearQuery = ""
                                selectedType = nil
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

            if isLoadingGames && indexedResults.isEmpty {
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
            PracticeGameSearchRecentStore.remember(result.canonicalGameID)
            recentGameIDs = PracticeGameSearchRecentStore.load()
            onSelectGame(result.canonicalGameID)
        }
    }

    private func resultMetaLine(for result: PracticeGameSearchResult) -> String {
        practiceSearchMetaLine(for: result)
    }

    private func rebuildSearchIndex() {
        indexedResults = buildPracticeSearchResults(games)
        indexedManufacturers = Array(Set(indexedResults.compactMap(\.manufacturer)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
