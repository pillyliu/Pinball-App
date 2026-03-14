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
        ZStack {
            AppBackground()

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

enum ManufacturerBucket: String, CaseIterable, Identifiable {
    case modern
    case classic
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .modern:
            return "Modern"
        case .classic:
            return "Classic"
        case .other:
            return "Other"
        }
    }
}

extension Array where Element == PinballCatalogManufacturerOption {
    func filteredForBucket(_ bucket: ManufacturerBucket) -> [PinballCatalogManufacturerOption] {
        let classicTopIDs = self
            .filter { !$0.isModern }
            .sorted {
                if $0.gameCount != $1.gameCount { return $0.gameCount > $1.gameCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(20)
            .map(\.id)
        let classicSet = Set(classicTopIDs)

        switch bucket {
        case .modern:
            return filter { $0.isModern }
        case .classic:
            return filter { classicSet.contains($0.id) }
                .sorted {
                    if $0.gameCount != $1.gameCount { return $0.gameCount > $1.gameCount }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        case .other:
            return filter { !$0.isModern && !classicSet.contains($0.id) }
        }
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

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsProviderCaption(prefix: "Search powered by ", linkText: "Pinball Map", urlString: "https://www.pinballmap.com")

                        HStack(alignment: .center, spacing: 8) {
                            TextField("City or ZIP code", text: $query)
                                .submitLabel(.search)
                                .onSubmit {
                                    Task { await runSearch() }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .appControlStyle()
                                .frame(maxWidth: .infinity)

                            Button {
                                Task { await runCurrentLocationSearch() }
                            } label: {
                                Group {
                                    if isLocating {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "scope")
                                            .font(.title3)
                                    }
                                }
                                .frame(width: 36, height: 36)
                            }
                            .buttonStyle(AppCompactIconActionButtonStyle())
                            .disabled(isSearching || isLocating)
                            .accessibilityLabel("Use current location")
                        }

                        Menu {
                            ForEach([10, 25, 50, 100], id: \.self) { miles in
                                Button {
                                    radiusMiles = miles
                                } label: {
                                    AppSelectableMenuRow(
                                        text: "\(miles) miles",
                                        isSelected: radiusMiles == miles
                                    )
                                }
                            }
                        } label: {
                            AppCompactStackedMenuLabel(
                                title: "Distance",
                                value: "\(radiusMiles) miles"
                            )
                        }
                        .buttonStyle(.plain)

                        Stepper(value: $minimumGameCount, in: 0 ... 50) {
                            HStack {
                                AppCardSubheading(text: "Minimum games")
                                Spacer()
                                Text(minimumGameCount == 0 ? "Any" : "\(minimumGameCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .appControlStyle()

                        Button(isSearching ? "Searching..." : "Search Pinball Map") {
                            Task { await runSearch() }
                        }
                        .buttonStyle(AppPrimaryActionButtonStyle())
                        .disabled(isSearching || isLocating || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if isLocating {
                            AppInlineTaskStatus(text: "Getting current location…", showsProgress: true)
                        } else if isSearching {
                            AppInlineTaskStatus(text: "Searching Pinball Map…", showsProgress: true)
                        } else if let errorMessage {
                            AppInlineTaskStatus(text: errorMessage, isError: true)
                        }
                    }
                    .padding(12)
                    .appPanelStyle()

                    if let emptyResultsMessage {
                        AppPanelEmptyCard(text: emptyResultsMessage)
                    }

                    if !filteredResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            AppCardSubheading(text: "Results")

                            VStack(spacing: 0) {
                                ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, venue in
                                    Button {
                                        Task { await importVenue(venue) }
                                    } label: {
                                        SettingsImportResultRow(
                                            title: venue.name,
                                            subtitle: venueSubtitle(venue),
                                            accessorySystemName: "plus.circle.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if index < filteredResults.count - 1 {
                                        AppTableRowDivider()
                                    }
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
        .navigationTitle("Add Venue")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runSearch() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            hasSearched = true
            lastSearchContext = trimmedQuery
            searchResults = try await PinballMapClient.searchVenues(query: trimmedQuery, radiusMiles: radiusMiles)
            errorMessage = nil
        } catch {
            searchResults = []
            errorMessage = error.localizedDescription
        }
    }

    private func runCurrentLocationSearch() async {
        isLocating = true
        do {
            let coordinate = try await locationRequester.requestCurrentLocation()
            isLocating = false
            isSearching = true
            defer { isSearching = false }
            hasSearched = true
            lastSearchContext = "Current location"
            searchResults = try await PinballMapClient.searchVenues(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMiles: radiusMiles
            )
            errorMessage = nil
        } catch {
            isLocating = false
            errorMessage = error.localizedDescription
        }
    }

    private func importVenue(_ venue: PinballLibraryVenueSearchResult) async {
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: venue.id.replacingOccurrences(of: "venue--pm-", with: ""))
            viewModel.importVenue(
                result: venue,
                machineIDs: machineIDs,
                searchQuery: lastSearchContext.isEmpty ? query : lastSearchContext,
                radiusMiles: radiusMiles
            )
            dismiss()
        } catch {
            errorMessage = "Venue import failed: \(error.localizedDescription)"
        }
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

private enum VenueLocationError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "Turn on Location Services to search near you."
        case .permissionDenied:
            return "Location permission is required to search near you."
        case .unavailable:
            return "Couldn't get your current location."
        }
    }
}

@MainActor
private final class VenueLocationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var isAwaitingAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        guard continuation == nil else {
            throw VenueLocationError.unavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                isAwaitingAuthorization = true
                manager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                finish(with: VenueLocationError.permissionDenied)
            @unknown default:
                finish(with: VenueLocationError.unavailable)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isAwaitingAuthorization else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isAwaitingAuthorization = false
            manager.requestLocation()
        case .restricted, .denied:
            finish(with: VenueLocationError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            finish(with: VenueLocationError.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finish(with: VenueLocationError.unavailable)
            return
        }
        finish(with: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .denied {
            finish(with: VenueLocationError.permissionDenied)
        } else {
            finish(with: VenueLocationError.unavailable)
        }
    }

    private func finish(with coordinate: CLLocationCoordinate2D) {
        continuation?.resume(returning: coordinate)
        continuation = nil
        isAwaitingAuthorization = false
    }

    private func finish(with error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        isAwaitingAuthorization = false
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

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsProviderCaption(prefix: "Import powered by ", linkText: "Match Play", urlString: "https://matchplay.events")

                        TextField("Tournament ID or URL", text: $rawTournamentID)
                            .submitLabel(.done)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        Text("Enter a Match Play tournament ID or URL to import its arena list into Library and Practice.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(isImporting ? "Importing..." : "Import Tournament") {
                            Task { await importTournament() }
                        }
                        .buttonStyle(AppPrimaryActionButtonStyle())
                        .disabled(isImporting || tournamentID == nil)

                        if isImporting {
                            AppInlineTaskStatus(text: "Importing tournament…", showsProgress: true)
                        } else if let errorMessage {
                            AppInlineTaskStatus(text: errorMessage, isError: true)
                        }
                    }
                    .padding(12)
                    .appPanelStyle()
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

        do {
            let tournament = try await MatchPlayClient.fetchTournament(id: tournamentID)
            guard !tournament.machineIDs.isEmpty else {
                errorMessage = "No OPDB-linked arenas were found for that tournament."
                return
            }
            viewModel.importTournament(result: tournament)
            dismiss()
        } catch {
            errorMessage = "Tournament import failed: \(error.localizedDescription)"
        }
    }
}

struct SettingsProviderCaption: View {
    let prefix: String
    let linkText: String
    let urlString: String

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .foregroundStyle(AppTheme.brandChalk)
            Link(linkText, destination: URL(string: urlString)!)
                .foregroundStyle(AppTheme.brandGold)
        }
        .font(.caption)
    }
}

struct SettingsImportResultRow: View {
    let title: String
    let subtitle: String
    let accessorySystemName: String
    var showsHighlightBadge = false
    var highlightBadgeText = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    AppCardSubheading(text: title)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if showsHighlightBadge {
                        AppTintedStatusChip(
                            text: highlightBadgeText,
                            foreground: AppTheme.brandGold,
                            compact: true
                        )
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Image(systemName: accessorySystemName)
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 8)
    }
}

func extractTournamentID(from rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if trimmed.allSatisfy(\.isNumber) {
        return trimmed
    }

    if let match = trimmed.range(of: #"tournaments/(\d+)"#, options: .regularExpression) {
        let matched = String(trimmed[match])
        return matched.components(separatedBy: "/").last
    }

    return nil
}
