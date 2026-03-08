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
    @Published private(set) var isRefreshingHostedData = false
    @Published private(set) var hostedDataStatusMessage: String?
    @Published private(set) var hostedDataStatusIsError = false
    @Published var errorMessage: String?

    private var didLoad = false
    let builtinSources: [PinballLibrarySource] = [
        .init(id: "venue--rlm-amusements", name: "RLM Amusements", type: .venue),
        .init(id: "venue--the-avenue-cafe", name: "The Avenue Cafe", type: .venue),
    ]

    private func applySnapshot(_ snapshot: SettingsDataSnapshot) {
        manufacturers = snapshot.manufacturers
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    private func applySourceSnapshot(_ snapshot: SettingsSourceSnapshot) {
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            applySnapshot(try await loadSettingsDataSnapshot())
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forceRefreshHostedLibraryData() async {
        guard !isRefreshingHostedData else { return }
        isRefreshingHostedData = true
        hostedDataStatusMessage = nil
        hostedDataStatusIsError = false
        defer { isRefreshingHostedData = false }

        do {
            applySnapshot(try await forceRefreshHostedSettingsData())
            hostedDataStatusMessage = "Pinball data refreshed from pillyliu.com."
            hostedDataStatusIsError = false
            postPinballLibrarySourcesDidChange()
        } catch {
            hostedDataStatusMessage = "Hosted data refresh failed: \(error.localizedDescription)"
            hostedDataStatusIsError = true
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
        applySourceSnapshot(addManufacturerSource(manufacturer))
        postPinballLibrarySourcesDidChange()
    }

    func importVenue(result: PinballLibraryVenueSearchResult, machineIDs: [String], searchQuery: String, radiusMiles: Int) {
        applySourceSnapshot(
            addVenueSource(
                result: result,
                machineIDs: machineIDs,
                searchQuery: searchQuery,
                radiusMiles: radiusMiles
            )
        )
        postPinballLibrarySourcesDidChange()
    }

    func importTournament(result: MatchPlayTournamentImportResult) {
        applySourceSnapshot(addTournamentSource(result))
        postPinballLibrarySourcesDidChange()
    }

    func removeImportedSource(_ sourceID: String) {
        applySourceSnapshot(removeSettingsSource(sourceID))
        postPinballLibrarySourcesDidChange()
    }

    func refreshVenue(_ source: PinballImportedSourceRecord) async {
        guard source.type == .venue else { return }
        do {
            applySourceSnapshot(try await refreshVenueSource(source))
            postPinballLibrarySourcesDidChange()
        } catch {
            errorMessage = "Venue refresh failed: \(error.localizedDescription)"
        }
    }

    func refreshTournament(_ source: PinballImportedSourceRecord) async {
        guard source.type == .tournament else { return }
        do {
            applySourceSnapshot(try await refreshTournamentSource(source))
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
                        if viewModel.isLoading {
                            AppPanelStatusCard(
                                text: "Loading settings…",
                                showsProgress: true
                            )
                        } else if let errorMessage = viewModel.errorMessage {
                            AppPanelStatusCard(
                                text: errorMessage,
                                isError: true
                            )
                        }
                        librarySection
                        hostedRefreshSection
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
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: "Library")

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
                AppPanelEmptyCard(text: "No additional sources added yet.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var hostedRefreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Pinball Data")

            Text("Force-refresh the hosted Library and OPDB catalog from pillyliu.com.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await viewModel.forceRefreshHostedLibraryData() }
            } label: {
                Text(viewModel.isRefreshingHostedData ? "Refreshing Pinball Data…" : "Refresh Pinball Data")
            }
            .buttonStyle(.glass)
            .disabled(viewModel.isRefreshingHostedData)

            if let statusMessage = viewModel.hostedDataStatusMessage {
                AppInlineTaskStatus(
                    text: statusMessage,
                    showsProgress: viewModel.isRefreshingHostedData,
                    isError: viewModel.hostedDataStatusIsError
                )
            } else if viewModel.isRefreshingHostedData {
                AppInlineTaskStatus(
                    text: "Refreshing hosted pinball data…",
                    showsProgress: true
                )
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
                            .modifier(AppInlineActionChipStyle())
                            .accessibilityLabel("Refresh \(source.title)")
                        }

                        if source.sourceType == .tournament {
                            Button("Refresh") {
                                if let imported = viewModel.importedSources.first(where: { $0.id == source.id }) {
                                    Task { await viewModel.refreshTournament(imported) }
                                }
                            }
                            .buttonStyle(.plain)
                            .modifier(AppInlineActionChipStyle())
                            .accessibilityLabel("Refresh \(source.title)")
                        }

                        Button("Delete", role: .destructive) {
                            viewModel.removeImportedSource(source.id)
                        }
                        .buttonStyle(.plain)
                        .modifier(AppInlineActionChipStyle(isDestructive: true))
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
            AppSectionTitle(text: "Privacy")

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
            AppSectionTitle(text: "About")
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

private struct ManagedSourceRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let builtin: Bool
    let sourceType: PinballLibrarySourceType
}
