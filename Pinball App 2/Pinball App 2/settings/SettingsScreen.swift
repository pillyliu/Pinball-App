import SwiftUI
import Combine

private enum SettingsRoute: Hashable {
    case addManufacturer
    case addVenue
    case addTournament
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var manufacturers: [PinballCatalogManufacturerOption] = []
    @Published private(set) var importedSources: [PinballImportedSourceRecord] = []
    @Published private(set) var sourceState: PinballLibrarySourceState = .empty
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var didLoad = false
    private let libraryPath = "/pinball/data/pinball_library_v3.json"
    private let opdbCatalogPath = "/pinball/data/opdb_catalog_v1.json"

    let builtinSources: [PinballLibrarySource] = [
        .init(id: "venue--rlm-amusements", name: "RLM Amusements", type: .venue),
        .init(id: "venue--the-avenue-cafe", name: "The Avenue Cafe", type: .venue),
    ]

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            do {
                manufacturers = try await LibrarySeedDatabase.shared.loadManufacturerOptions()
            } catch {
                if let opdbText = try loadBundledPinballText(path: opdbCatalogPath),
                   let opdbData = opdbText.data(using: .utf8) {
                    manufacturers = try decodeCatalogManufacturerOptions(data: opdbData)
                } else {
                    let cached = try await PinballDataCache.shared.loadText(path: opdbCatalogPath, allowMissing: true)
                    if let opdbText = cached.text,
                       let opdbData = opdbText.data(using: .utf8) {
                        manufacturers = try decodeCatalogManufacturerOptions(data: opdbData)
                    } else {
                        manufacturers = []
                    }
                }
            }
            importedSources = PinballImportedSourcesStore.load()
            sourceState = PinballLibrarySourceStateStore.load()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isEnabled(_ sourceID: String, builtin: Bool) -> Bool {
        builtin || sourceState.enabledSourceIDs.contains(sourceID)
    }

    func isPinned(_ sourceID: String) -> Bool {
        sourceState.pinnedSourceIDs.contains(sourceID)
    }

    func toggleEnabled(_ sourceID: String, builtin: Bool, isOn: Bool) {
        guard !builtin else { return }
        PinballLibrarySourceStateStore.setEnabled(sourceID: sourceID, isEnabled: isOn)
        sourceState = PinballLibrarySourceStateStore.load()
        postPinballLibrarySourcesDidChange()
    }

    func togglePinned(_ sourceID: String, isOn: Bool) {
        let success = PinballLibrarySourceStateStore.setPinned(sourceID: sourceID, isPinned: isOn)
        if !success {
            errorMessage = "Pinned sources are limited to \(PinballLibrarySourceStateStore.maxPinnedSources)."
        }
        sourceState = PinballLibrarySourceStateStore.load()
        postPinballLibrarySourcesDidChange()
    }

    func addManufacturer(_ manufacturer: PinballCatalogManufacturerOption) {
        let sourceID = "manufacturer--\(manufacturer.id)"
        let record = PinballImportedSourceRecord(
            id: sourceID,
            name: manufacturer.name,
            type: .manufacturer,
            provider: .opdb,
            providerSourceID: manufacturer.id,
            machineIDs: [],
            lastSyncedAt: Date(),
            searchQuery: nil,
            distanceMiles: nil
        )
        PinballImportedSourcesStore.upsert(record)
        PinballLibrarySourceStateStore.upsertSource(id: sourceID, enable: true, pinIfPossible: true)
        importedSources = PinballImportedSourcesStore.load()
        sourceState = PinballLibrarySourceStateStore.load()
        postPinballLibrarySourcesDidChange()
    }

    func importVenue(result: PinballLibraryVenueSearchResult, machineIDs: [String], searchQuery: String, radiusMiles: Int) {
        let locationID = result.id.replacingOccurrences(of: "venue--pm-", with: "")
        let record = PinballImportedSourceRecord(
            id: result.id,
            name: result.name,
            type: .venue,
            provider: .pinballMap,
            providerSourceID: locationID,
            machineIDs: machineIDs,
            lastSyncedAt: Date(),
            searchQuery: searchQuery,
            distanceMiles: radiusMiles
        )
        PinballImportedSourcesStore.upsert(record)
        PinballLibrarySourceStateStore.upsertSource(id: result.id, enable: true, pinIfPossible: true)
        importedSources = PinballImportedSourcesStore.load()
        sourceState = PinballLibrarySourceStateStore.load()
        postPinballLibrarySourcesDidChange()
    }

    func importTournament(result: MatchPlayTournamentImportResult) {
        let sourceID = "tournament--mp-\(result.id)"
        let record = PinballImportedSourceRecord(
            id: sourceID,
            name: result.name,
            type: .tournament,
            provider: .matchPlay,
            providerSourceID: result.id,
            machineIDs: result.machineIDs,
            lastSyncedAt: Date(),
            searchQuery: nil,
            distanceMiles: nil
        )
        PinballImportedSourcesStore.upsert(record)
        PinballLibrarySourceStateStore.upsertSource(id: sourceID, enable: true, pinIfPossible: true)
        importedSources = PinballImportedSourcesStore.load()
        sourceState = PinballLibrarySourceStateStore.load()
        postPinballLibrarySourcesDidChange()
    }

    func removeImportedSource(_ sourceID: String) {
        PinballImportedSourcesStore.remove(id: sourceID)
        importedSources = PinballImportedSourcesStore.load()
        sourceState = PinballLibrarySourceStateStore.load()
        postPinballLibrarySourcesDidChange()
    }

    func refreshVenue(_ source: PinballImportedSourceRecord) async {
        guard source.type == .venue else { return }
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: source.providerSourceID)
            var updated = source
            updated.machineIDs = machineIDs
            updated.lastSyncedAt = Date()
            PinballImportedSourcesStore.upsert(updated)
            importedSources = PinballImportedSourcesStore.load()
            postPinballLibrarySourcesDidChange()
        } catch {
            errorMessage = "Venue refresh failed: \(error.localizedDescription)"
        }
    }

    func refreshTournament(_ source: PinballImportedSourceRecord) async {
        guard source.type == .tournament else { return }
        do {
            let tournament = try await MatchPlayClient.fetchTournament(id: source.providerSourceID)
            var updated = source
            updated.name = tournament.name
            updated.machineIDs = tournament.machineIDs
            updated.lastSyncedAt = Date()
            PinballImportedSourcesStore.upsert(updated)
            importedSources = PinballImportedSourcesStore.load()
            postPinballLibrarySourcesDidChange()
        } catch {
            errorMessage = "Tournament refresh failed: \(error.localizedDescription)"
        }
    }
}

struct SettingsScreen: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var navigationPath: [SettingsRoute] = []
    @AppStorage(LPLNamePrivacySettings.fullNameAccessUnlockedDefaultsKey) private var lplFullNameAccessUnlocked = false
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false
    @State private var lplNamePassword: String = ""
    @State private var lplNamePrivacyError: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        librarySection
                        privacySection
                        aboutSection
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pinballLibrarySourcesDidChange)) { _ in
                Task { await viewModel.refresh() }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .addManufacturer:
                    AddManufacturerScreen(viewModel: viewModel)
                case .addVenue:
                    AddVenueScreen(viewModel: viewModel)
                case .addTournament:
                    AddTournamentScreen(viewModel: viewModel)
                }
            }
            .alert("Library", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library")
                .font(.headline)

            Text("Add:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Manufacturer") {
                    navigationPath.append(.addManufacturer)
                }
                .buttonStyle(.glass)

                Button("Venue") {
                    navigationPath.append(.addVenue)
                }
                .buttonStyle(.glass)

                Button("Tournament") {
                    navigationPath.append(.addTournament)
                }
                .buttonStyle(.glass)
            }

            Text("Enabled adds that source's games to Library and Practice. Library adds the source to the Library source filter for quick switching. Up to \(PinballLibrarySourceStateStore.maxPinnedSources) sources can appear in Library at once.")
                .font(.caption)
                .foregroundStyle(.secondary)

            sourceTable

            if viewModel.importedSources.isEmpty {
                Text("No additional sources added yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var sourceTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Enabled")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 68)
                Text("Library")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 68)
            }
            .padding(.bottom, 6)

            AppTableHeaderDivider()

            ForEach(Array(managedSources.enumerated()), id: \.element.id) { index, source in
                managedSourceRow(source)
                if index < managedSources.count - 1 {
                    AppTableRowDivider()
                }
            }
        }
    }

    private var managedSources: [ManagedSourceRow] {
        let builtinRows = viewModel.builtinSources.map { source in
            ManagedSourceRow(
                id: source.id,
                title: source.name,
                subtitle: "Built-in venue",
                builtin: true,
                sourceType: source.type
            )
        }
        let importedRows = viewModel.importedSources.map { source in
            ManagedSourceRow(
                id: source.id,
                title: source.name,
                subtitle: managedSourceSubtitle(for: source),
                builtin: false,
                sourceType: source.type
            )
        }
        return builtinRows + importedRows
    }

    private func managedSourceSubtitle(for source: PinballImportedSourceRecord) -> String {
        switch source.type {
        case .manufacturer:
            let count = viewModel.manufacturers.first(where: { $0.id == source.providerSourceID })?.gameCount ?? 0
            let label = count == 1 ? "1 game" : "\(count) games"
            return "Manufacturer • \(label)"
        case .venue:
            let count = source.machineIDs.count
            let label = count == 1 ? "1 game" : "\(count) games"
            return "Imported venue • \(label)"
        case .tournament:
            let count = source.machineIDs.count
            let label = count == 1 ? "1 game" : "\(count) games"
            return "Match Play tournament • \(label)"
        case .category:
            return "Category"
        }
    }

    private func managedSourceRow(_ source: ManagedSourceRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(source.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !source.builtin {
                    HStack(spacing: 6) {
                        if source.sourceType == .venue {
                            Button("Refresh") {
                                if let imported = viewModel.importedSources.first(where: { $0.id == source.id }) {
                                    Task { await viewModel.refreshVenue(imported) }
                                }
                            }
                            .buttonStyle(.plain)
                            .modifier(CompactRowActionButtonStyle())
                            .accessibilityLabel("Refresh \(source.title)")
                        }

                        if source.sourceType == .tournament {
                            Button("Refresh") {
                                if let imported = viewModel.importedSources.first(where: { $0.id == source.id }) {
                                    Task { await viewModel.refreshTournament(imported) }
                                }
                            }
                            .buttonStyle(.plain)
                            .modifier(CompactRowActionButtonStyle())
                            .accessibilityLabel("Refresh \(source.title)")
                        }

                        Button("Delete", role: .destructive) {
                            viewModel.removeImportedSource(source.id)
                        }
                        .buttonStyle(.plain)
                        .modifier(CompactRowActionButtonStyle(isDestructive: true))
                        .accessibilityLabel("Remove \(source.title)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.isEnabled(source.id, builtin: source.builtin) },
                    set: { viewModel.toggleEnabled(source.id, builtin: source.builtin, isOn: $0) }
                )
            )
            .labelsHidden()
            .disabled(source.builtin)
            .frame(width: 68)
            .accessibilityLabel("Enabled for \(source.title)")

            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.isPinned(source.id) },
                    set: { viewModel.togglePinned(source.id, isOn: $0) }
                )
            )
            .labelsHidden()
            .frame(width: 68)
            .accessibilityLabel("Show \(source.title) in Library")
        }
        .padding(.vertical, 8)
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy")
                .font(.headline)

            Text("Lansing Pinball League names are shown as first name plus last initial by default.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if lplFullNameAccessUnlocked {
                Toggle("Show full last names for Lansing Pinball League data", isOn: $showFullLPLLastNames)
            } else {
                SecureField("LPL full-name password", text: $lplNamePassword)
                    .textContentType(.password)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                Button("Unlock Full Names") {
                    if unlockLPLFullNameAccess(with: lplNamePassword) {
                        lplFullNameAccessUnlocked = true
                        lplNamePassword = ""
                        lplNamePrivacyError = nil
                    } else {
                        lplNamePrivacyError = "Incorrect password."
                    }
                }
                .buttonStyle(.glass)
                .disabled(lplNamePassword.isEmpty)

                if let lplNamePrivacyError {
                    Text(lplNamePrivacyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(aboutAttributionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var aboutAttributionText: AttributedString {
        let markdown = """
        PinProf is built on [OPDB](https://opdb.org/) (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by [Pinball Map](https://www.pinballmap.com). Rulesheets are sourced from [Tiltforums](https://tiltforums.com/), [Bob's Guide](https://rules.silverballmania.com/), [Pinball Primer](https://pinballprimer.github.io/), and [PAPA](https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/). Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from [Matchplay](https://matchplay.events/).
        """
        return (try? AttributedString(markdown: markdown)) ?? AttributedString("PinProf is built on OPDB (Open Pinball Database) to provide machine and manufacturer data. Rulesheets are sourced from Tiltforums, Bob's Guide, Pinball Primer, and PAPA. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from Matchplay.")
    }
}

private struct AddManufacturerScreen: View {
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
                        Text("Bucket")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

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
                        Text("No manufacturers found for that search.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .appPanelStyle()
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

private enum ManufacturerBucket: String, CaseIterable, Identifiable {
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

private extension Array where Element == PinballCatalogManufacturerOption {
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

private struct AddVenueScreen: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings-add-venue-min-game-count") private var minimumGameCount = 5
    @State private var query: String = ""
    @State private var radiusMiles: Int = 50
    @State private var searchResults: [PinballLibraryVenueSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?

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

                        TextField("City or ZIP code", text: $query)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await runSearch() }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

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
                                Text("Minimum games")
                                Spacer()
                                Text(minimumGameCount == 0 ? "Any" : "\(minimumGameCount)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .appControlStyle()

                        Button(isSearching ? "Searching..." : "Search Pinball Map") {
                            Task { await runSearch() }
                        }
                        .buttonStyle(.glass)
                        .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(12)
                    .appPanelStyle()

                    if let emptyResultsMessage {
                        Text(emptyResultsMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .appPanelStyle()
                    }

                    if !filteredResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Results")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

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
        .alert("Pinball Map", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func runSearch() async {
        isSearching = true
        defer { isSearching = false }
        do {
            hasSearched = true
            searchResults = try await PinballMapClient.searchVenues(query: query, radiusMiles: radiusMiles)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importVenue(_ venue: PinballLibraryVenueSearchResult) async {
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: venue.id.replacingOccurrences(of: "venue--pm-", with: ""))
            viewModel.importVenue(result: venue, machineIDs: machineIDs, searchQuery: query, radiusMiles: radiusMiles)
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

private struct AddTournamentScreen: View {
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
                        .buttonStyle(.glass)
                        .disabled(isImporting || tournamentID == nil)
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
        .alert("Match Play", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
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

private struct ManagedSourceRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let builtin: Bool
    let sourceType: PinballLibrarySourceType
}

private struct SettingsProviderCaption: View {
    let prefix: String
    let linkText: String
    let urlString: String

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
            Link(linkText, destination: URL(string: urlString)!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct SettingsImportResultRow: View {
    let title: String
    let subtitle: String
    let accessorySystemName: String
    var showsHighlightBadge = false
    var highlightBadgeText = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if showsHighlightBadge {
                        Text(highlightBadgeText)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12), in: Capsule())
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

private struct CompactRowActionButtonStyle: ViewModifier {
    var isDestructive = false

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.controlBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isDestructive ? Color.red.opacity(0.28) : AppTheme.controlBorder, lineWidth: 1)
                    )
            )
    }
}

private func extractTournamentID(from rawValue: String) -> String? {
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
