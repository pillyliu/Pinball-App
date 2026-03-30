import SwiftUI
import CoreLocation

struct AddManufacturerScreen: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedBucket: ManufacturerBucket = .modern

    private var filteredManufacturers: [PinballCatalogManufacturerOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bucketed = manufacturersForSelectedBucket
        if trimmed.isEmpty {
            return bucketed
        }
        return bucketed.filter { manufacturer in
            manufacturer.name.lowercased().contains(trimmed)
        }
    }

    private var manufacturersForSelectedBucket: [PinballCatalogManufacturerOption] {
        viewModel.manufacturers.filteredForBucket(selectedBucket)
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        AppCardSubheading(text: "Bucket")

                        Menu {
                            ForEach(ManufacturerBucket.allCases) { bucket in
                                Button {
                                    selectedBucket = bucket
                                } label: {
                                    AppSelectableMenuRow(text: bucket.label, isSelected: selectedBucket == bucket)
                                }
                            }
                        } label: {
                            AppCompactDropdownLabel(text: selectedBucket.label)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .appPanelStyle()

                    if filteredManufacturers.isEmpty {
                        AppPanelEmptyCard(text: "No manufacturers found for that search.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredManufacturers.enumerated()), id: \.element.id) { index, manufacturer in
                                Button {
                                    viewModel.addManufacturer(manufacturer)
                                    dismiss()
                                } label: {
                                    SettingsImportResultRow(
                                        title: manufacturer.name,
                                        subtitle: manufacturerSubtitle(manufacturer),
                                        accessorySystemName: "plus.circle.fill",
                                        showsHighlightBadge: manufacturer.isModern,
                                        highlightBadgeText: "Modern"
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < filteredManufacturers.count - 1 {
                                    AppTableRowDivider()
                                }
                            }
                        }
                        .padding(12)
                        .appPanelStyle()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .searchable(text: $query, prompt: "Search manufacturers")
        .navigationTitle("Add Manufacturer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func manufacturerSubtitle(_ manufacturer: PinballCatalogManufacturerOption) -> String {
        manufacturer.gameCount == 1 ? "1 game" : "\(manufacturer.gameCount) games"
    }
}

struct AddVenueScreen: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings-add-venue-min-game-count") private var minimumGameCount = 5
    @State private var locationRequester = VenueLocationRequester()
    @State private var query: String = ""
    @State private var radiusMiles: Int = 25
    @State private var searchResults: [PinballLibraryVenueSearchResult] = []
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var lastSearchContext: String = ""

    private var filteredResults: [PinballLibraryVenueSearchResult] {
        searchResults.filter { $0.machineCount >= minimumGameCount }
    }

    private var emptyResultsMessage: String? {
        guard hasSearched else { return nil }
        if searchResults.isEmpty {
            return "No venues found for that search."
        }
        if filteredResults.isEmpty {
            return minimumGameCount == 1
                ? "No venues found with at least 1 game."
                : "No venues found with at least \(minimumGameCount) games."
        }
        return nil
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveSearchContext: String {
        lastSearchContext.isEmpty ? trimmedQuery : lastSearchContext
    }

    private var venueSearchStatus: SettingsImportStatusContent? {
        if isLocating {
            return SettingsImportStatusContent(text: "Getting current location…", showsProgress: true)
        }
        if isSearching {
            return SettingsImportStatusContent(text: "Searching Pinball Map…", showsProgress: true)
        }
        if let errorMessage {
            return SettingsImportStatusContent(text: errorMessage, isError: true)
        }
        return nil
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsVenueSearchControlsCard(
                        query: $query,
                        radiusMiles: $radiusMiles,
                        minimumGameCount: $minimumGameCount,
                        isSearching: isSearching,
                        isLocating: isLocating,
                        status: venueSearchStatus,
                        onSearch: {
                            Task { await runSearch() }
                        },
                        onUseCurrentLocation: {
                            Task { await runCurrentLocationSearch() }
                        }
                    )

                    if let emptyResultsMessage {
                        AppPanelEmptyCard(text: emptyResultsMessage)
                    }

                    if !filteredResults.isEmpty {
                        SettingsVenueSearchResultsPanel(
                            results: filteredResults,
                            subtitle: venueSubtitle,
                            onImport: { venue in
                                Task { await importVenue(venue) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("Add Venue")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runSearch() async {
        guard !trimmedQuery.isEmpty else { return }
        await performVenueSearch(context: trimmedQuery) {
            try await PinballMapClient.searchVenues(query: trimmedQuery, radiusMiles: radiusMiles)
        }
    }

    private func runCurrentLocationSearch() async {
        isLocating = true
        do {
            let coordinate = try await locationRequester.requestCurrentLocation()
            isLocating = false
            await performVenueSearch(context: "Current location") {
                try await PinballMapClient.searchVenues(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    radiusMiles: radiusMiles
                )
            }
        } catch {
            isLocating = false
            errorMessage = error.localizedDescription
        }
    }

    private func performVenueSearch(
        context: String,
        action: () async throws -> [PinballLibraryVenueSearchResult]
    ) async {
        hasSearched = true
        lastSearchContext = context
        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await action()
            errorMessage = nil
        } catch {
            searchResults = []
            errorMessage = error.localizedDescription
        }
    }

    private func importVenue(_ venue: PinballLibraryVenueSearchResult) async {
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: venueLocationID(venue))
            viewModel.importVenue(
                result: venue,
                machineIDs: machineIDs,
                searchQuery: effectiveSearchContext,
                radiusMiles: radiusMiles
            )
            dismiss()
        } catch {
            errorMessage = "Venue import failed: \(error.localizedDescription)"
        }
    }

    private func venueLocationID(_ venue: PinballLibraryVenueSearchResult) -> String {
        venue.id.replacingOccurrences(of: "venue--pm-", with: "")
    }

    private func venueSubtitle(_ venue: PinballLibraryVenueSearchResult) -> String {
        var parts: [String] = []
        if let city = venue.city, let state = venue.state {
            parts.append("\(city), \(state)")
        }
        if let distanceMiles = venue.distanceMiles {
            parts.append(String(format: "%.1f mi", distanceMiles))
        }
        parts.append(venue.machineCount == 1 ? "1 game" : "\(venue.machineCount) games")
        return parts.joined(separator: " • ")
    }
}

struct AddTournamentScreen: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var rawTournamentID: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var tournamentID: String? {
        extractTournamentID(from: rawTournamentID)
    }

    private var canImportTournament: Bool {
        !isImporting && tournamentID != nil
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsTournamentImportCard(
                        rawTournamentID: $rawTournamentID,
                        isImporting: isImporting,
                        errorMessage: errorMessage,
                        canImportTournament: canImportTournament,
                        onImport: {
                            Task { await importTournament() }
                        }
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("Add Tournament")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func importTournament() async {
        guard let tournamentID else { return }
        isImporting = true
        defer { isImporting = false }
        errorMessage = nil

        do {
            let tournament = try await loadTournament(id: tournamentID)
            viewModel.importTournament(result: tournament)
            dismiss()
        } catch {
            errorMessage = tournamentImportError(for: error)
        }
    }

    private func loadTournament(id: String) async throws -> MatchPlayTournamentImportResult {
        let tournament = try await MatchPlayClient.fetchTournament(id: id)
        guard !tournament.machineIDs.isEmpty else {
            throw TournamentImportError.noLinkedArenas
        }
        return tournament
    }

    private func tournamentImportError(for error: Error) -> String {
        if let tournamentImportError = error as? TournamentImportError {
            return tournamentImportError.errorDescription ?? "Tournament import failed."
        }
        return "Tournament import failed: \(error.localizedDescription)"
    }
}
