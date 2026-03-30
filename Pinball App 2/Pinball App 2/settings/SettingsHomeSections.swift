import SwiftUI

struct SettingsHomeContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var navigationPath: [SettingsRoute]
    @Binding var lplFullNameAccessUnlocked: Bool
    @Binding var showFullLPLLastNames: Bool
    @Binding var lplNamePassword: String
    @Binding var lplNamePrivacyError: String?
    let onToggleIntroOverlayForNextLaunch: () -> Void

    private var screenStatus: SettingsSectionStatusContent? {
        if viewModel.isLoading {
            return SettingsSectionStatusContent(text: "Loading settings…", showsProgress: true)
        }
        if let errorMessage = viewModel.errorMessage {
            return SettingsSectionStatusContent(text: errorMessage, isError: true)
        }
        return nil
    }

    private var hostedRefreshStatus: SettingsSectionStatusContent? {
        if let statusMessage = viewModel.hostedDataStatusMessage {
            return SettingsSectionStatusContent(
                text: statusMessage,
                showsProgress: viewModel.isRefreshingHostedData,
                isError: viewModel.hostedDataStatusIsError
            )
        }
        if viewModel.isRefreshingHostedData {
            return SettingsSectionStatusContent(text: "Refreshing hosted pinball data…", showsProgress: true)
        }
        return nil
    }

    private var cacheStatus: SettingsSectionStatusContent? {
        if let statusMessage = viewModel.cacheStatusMessage {
            return SettingsSectionStatusContent(
                text: statusMessage,
                showsProgress: viewModel.isClearingCache,
                isError: viewModel.cacheStatusIsError
            )
        }
        if viewModel.isClearingCache {
            return SettingsSectionStatusContent(text: "Clearing cached data…", showsProgress: true)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let screenStatus {
                SettingsSectionStatusCard(status: screenStatus)
            }
            SettingsHomeAppearanceSection()
            SettingsHomeLibrarySection(
                manufacturers: viewModel.manufacturers,
                importedSources: viewModel.importedSources,
                isEnabled: viewModel.isEnabled,
                isPinned: viewModel.isPinned,
                onAddManufacturer: { navigationPath.append(.addManufacturer) },
                onAddVenue: { navigationPath.append(.addVenue) },
                onAddTournament: { navigationPath.append(.addTournament) },
                onToggleEnabled: { sourceID, isOn in
                    viewModel.toggleEnabled(sourceID, isOn: isOn)
                },
                onTogglePinned: { sourceID, isOn in
                    viewModel.togglePinned(sourceID, isOn: isOn)
                },
                onRefresh: { source in
                    Task { await viewModel.refreshSource(source) }
                },
                onDelete: viewModel.removeImportedSource
            )
            SettingsHomeHostedDataSection(
                isRefreshingHostedData: viewModel.isRefreshingHostedData,
                isClearingCache: viewModel.isClearingCache,
                hostedRefreshStatus: hostedRefreshStatus,
                cacheStatus: cacheStatus,
                onRefreshHostedData: {
                    Task { await viewModel.forceRefreshHostedLibraryData() }
                },
                onClearCache: {
                    Task { await viewModel.clearCachedData() }
                }
            )
            SettingsHomePrivacySection(
                lplFullNameAccessUnlocked: $lplFullNameAccessUnlocked,
                showFullLPLLastNames: $showFullLPLLastNames,
                lplNamePassword: $lplNamePassword,
                lplNamePrivacyError: $lplNamePrivacyError
            )
            SettingsHomeAboutSection(
                onToggleIntroOverlayForNextLaunch: onToggleIntroOverlayForNextLaunch
            )
        }
    }
}

struct SettingsSectionStatusContent {
    let text: String
    var showsProgress = false
    var isError = false
}

struct SettingsSectionStatusCard: View {
    let status: SettingsSectionStatusContent

    var body: some View {
        AppPanelStatusCard(
            text: status.text,
            showsProgress: status.showsProgress,
            isError: status.isError
        )
    }
}

struct SettingsSectionInlineStatus: View {
    let status: SettingsSectionStatusContent

    var body: some View {
        AppInlineTaskStatus(
            text: status.text,
            showsProgress: status.showsProgress,
            isError: status.isError
        )
    }
}
