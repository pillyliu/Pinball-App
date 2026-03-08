import SwiftUI
import Combine

enum SettingsRoute: Hashable {
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
                    SettingsHomeContent(
                        viewModel: viewModel,
                        navigationPath: $navigationPath,
                        lplFullNameAccessUnlocked: $lplFullNameAccessUnlocked,
                        showFullLPLLastNames: $showFullLPLLastNames,
                        lplNamePassword: $lplNamePassword,
                        lplNamePrivacyError: $lplNamePrivacyError
                    )
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
}
