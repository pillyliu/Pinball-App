import SwiftUI

struct SettingsHomeContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var navigationPath: [SettingsRoute]
    @Binding var lplFullNameAccessUnlocked: Bool
    @Binding var showFullLPLLastNames: Bool
    @Binding var lplNamePassword: String
    @Binding var lplNamePrivacyError: String?
    let onToggleIntroOverlayForNextLaunch: () -> Void
    @AppStorage(AppDisplayMode.defaultsKey) private var displayModeRawValue = AppDisplayMode.system.rawValue

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
            appearanceSection
            librarySection
            hostedRefreshSection
            privacySection
            aboutSection
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Appearance")

            Text("Choose whether PinProf follows the system appearance or stays in light or dark mode.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                "Display Mode",
                selection: Binding(
                    get: { AppDisplayMode(rawValue: displayModeRawValue) ?? .system },
                    set: { displayModeRawValue = $0.rawValue }
                )
            ) {
                ForEach(AppDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .appSegmentedControlStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: "Library")

            AppCardSubheading(text: "Add")

            SettingsLibraryAddButtons(
                onAddManufacturer: { navigationPath.append(.addManufacturer) },
                onAddVenue: { navigationPath.append(.addVenue) },
                onAddTournament: { navigationPath.append(.addTournament) }
            )

            Text("Enabled adds that source's games to Library and Practice. Library adds the source to the Library source filter for quick switching. Up to \(PinballLibrarySourceStateStore.maxPinnedSources) sources can appear in Library at once.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SettingsManagedSourceTable(
                items: managedSources,
                isEnabled: viewModel.isEnabled,
                isPinned: viewModel.isPinned,
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

            if viewModel.importedSources.isEmpty {
                AppPanelEmptyCard(text: "No sources added yet.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var hostedRefreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Pinball Data")

            Text("Refresh Pinball Data force-fetches the hosted OPDB export, CAF asset indexes, league files, and redacted players list from pillyliu.com.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await viewModel.forceRefreshHostedLibraryData() }
            } label: {
                Text(viewModel.isRefreshingHostedData ? "Refreshing Pinball Data…" : "Refresh Pinball Data")
            }
            .buttonStyle(AppPrimaryActionButtonStyle())
            .disabled(viewModel.isRefreshingHostedData || viewModel.isClearingCache)

            if let hostedRefreshStatus {
                SettingsSectionInlineStatus(status: hostedRefreshStatus)
            }

            AppTableRowDivider()

            Text("Clear Cache removes downloaded pinball data, cached images, and cached remote rulesheets. It does not remove settings, practice history, or GameRoom data.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                Task { await viewModel.clearCachedData() }
            } label: {
                Text(viewModel.isClearingCache ? "Clearing Cache…" : "Clear Cache")
            }
            .buttonStyle(AppSecondaryActionButtonStyle())
            .disabled(viewModel.isRefreshingHostedData || viewModel.isClearingCache)

            if let cacheStatus {
                SettingsSectionInlineStatus(status: cacheStatus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var managedSources: [SettingsManagedSourceItem] {
        viewModel.importedSources.map { source in
            SettingsManagedSourceItem(
                source: source,
                title: source.name,
                subtitle: managedSourceSubtitle(for: source),
                sourceType: source.type
            )
        }
    }

    private func managedSourceSubtitle(for source: PinballImportedSourceRecord) -> String {
        switch source.type {
        case .manufacturer:
            return "Manufacturer • \(gameCountLabel(viewModel.manufacturers.first(where: { $0.id == source.providerSourceID })?.gameCount ?? 0))"
        case .venue:
            return "Imported venue • \(gameCountLabel(source.machineIDs.count))"
        case .tournament:
            return "Match Play tournament • \(gameCountLabel(source.machineIDs.count))"
        case .category:
            return "Category"
        }
    }

    private func gameCountLabel(_ count: Int) -> String {
        count == 1 ? "1 game" : "\(count) games"
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Privacy")

            Text("Lansing Pinball League names are shown as first name plus last initial by default.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if lplFullNameAccessUnlocked {
                Toggle(isOn: $showFullLPLLastNames) {
                    Text("Show full last names for LPL data")
                        .font(.footnote)
                }
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
                .buttonStyle(AppPrimaryActionButtonStyle())
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
            aboutLogo
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

    private var aboutLogo: some View {
        Group {
            if let image = AppIntroBundledArtProvider.image(named: AppIntroCard.welcome.bundledArtworkFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: 150, height: 150)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onToggleIntroOverlayForNextLaunch()
        }
    }
}

private struct SettingsManagedSourceItem: Identifiable {
    let source: PinballImportedSourceRecord
    let title: String
    let subtitle: String
    let sourceType: PinballLibrarySourceType

    var id: String { source.id }
}

private struct SettingsSectionStatusContent {
    let text: String
    var showsProgress = false
    var isError = false
}

private struct SettingsSectionStatusCard: View {
    let status: SettingsSectionStatusContent

    var body: some View {
        AppPanelStatusCard(
            text: status.text,
            showsProgress: status.showsProgress,
            isError: status.isError
        )
    }
}

private struct SettingsSectionInlineStatus: View {
    let status: SettingsSectionStatusContent

    var body: some View {
        AppInlineTaskStatus(
            text: status.text,
            showsProgress: status.showsProgress,
            isError: status.isError
        )
    }
}

private struct SettingsLibraryAddButtons: View {
    let onAddManufacturer: () -> Void
    let onAddVenue: () -> Void
    let onAddTournament: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let totalWidth = max(0, proxy.size.width - (spacing * 2))
            // Match Android's proportional fill in the shared Settings add row.
            let manufacturerUnits: CGFloat = 12
            let venueUnits: CGFloat = 5
            let tournamentUnits: CGFloat = 10
            let totalUnits = manufacturerUnits + venueUnits + tournamentUnits
            let manufacturerWidth = totalWidth * (manufacturerUnits / totalUnits)
            let venueWidth = totalWidth * (venueUnits / totalUnits)
            let tournamentWidth = totalWidth * (tournamentUnits / totalUnits)

            HStack(spacing: spacing) {
                Button("Manufacturer", action: onAddManufacturer)
                    .buttonStyle(AppCompactSecondaryActionButtonStyle(fillsWidth: true))
                    .frame(width: manufacturerWidth)

                Button("Venue", action: onAddVenue)
                    .buttonStyle(AppCompactSecondaryActionButtonStyle(fillsWidth: true))
                    .frame(width: venueWidth)

                Button("Tournament", action: onAddTournament)
                    .buttonStyle(AppCompactSecondaryActionButtonStyle(fillsWidth: true))
                    .frame(width: tournamentWidth)
            }
        }
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsManagedSourceTable: View {
    let items: [SettingsManagedSourceItem]
    let isEnabled: (String) -> Bool
    let isPinned: (String) -> Bool
    let onToggleEnabled: (String, Bool) -> Void
    let onTogglePinned: (String, Bool) -> Void
    let onRefresh: (PinballImportedSourceRecord) -> Void
    let onDelete: (String) -> Void
    @State private var pendingDeleteItem: SettingsManagedSourceItem?

    var body: some View {
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

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                SettingsManagedSourceRow(
                    item: item,
                    isEnabled: isEnabled(item.id),
                    isPinned: isPinned(item.id),
                    onToggleEnabled: { onToggleEnabled(item.id, $0) },
                    onTogglePinned: { onTogglePinned(item.id, $0) },
                    onRefresh: { onRefresh(item.source) },
                    onDelete: { pendingDeleteItem = item }
                )
                if index < items.count - 1 {
                    AppTableRowDivider()
                }
            }
        }
        .alert(deleteAlertTitle, isPresented: pendingDeleteItemAlertIsPresented) {
            Button("Delete", role: .destructive) {
                guard let pendingDeleteItem else { return }
                onDelete(pendingDeleteItem.id)
                self.pendingDeleteItem = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    private var pendingDeleteItemAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteItem != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteItem = nil
                }
            }
        )
    }

    private var deleteAlertTitle: String {
        let typeLabel = pendingDeleteItem.map(deleteTypeLabel(for:)) ?? "Source"
        return "Delete \(typeLabel)?"
    }

    private var deleteAlertMessage: String {
        guard let pendingDeleteItem else {
            return "This removes the source from Library and Practice."
        }
        return "Remove \(pendingDeleteItem.title) from Library and Practice? This cannot be undone."
    }

    private func deleteTypeLabel(for item: SettingsManagedSourceItem) -> String {
        switch item.sourceType {
        case .manufacturer:
            return "Manufacturer"
        case .venue:
            return "Venue"
        case .tournament:
            return "Tournament"
        case .category:
            return "Source"
        }
    }
}

private struct SettingsManagedSourceRow: View {
    let item: SettingsManagedSourceItem
    let isEnabled: Bool
    let isPinned: Bool
    let onToggleEnabled: (Bool) -> Void
    let onTogglePinned: (Bool) -> Void
    let onRefresh: () -> Void
    let onDelete: () -> Void

    private var canRefresh: Bool {
        item.sourceType == .venue || item.sourceType == .tournament
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                AppCardSubheading(text: item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if canRefresh {
                        Button("Refresh", action: onRefresh)
                            .buttonStyle(AppInlineActionChipButtonStyle())
                            .accessibilityLabel("Refresh \(item.title)")
                    }

                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(AppInlineActionChipButtonStyle(isDestructive: true))
                        .accessibilityLabel("Remove \(item.title)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(get: { isEnabled }, set: onToggleEnabled))
                .labelsHidden()
                .frame(width: 68)
                .accessibilityLabel("Enabled for \(item.title)")

            Toggle("", isOn: Binding(get: { isPinned }, set: onTogglePinned))
                .labelsHidden()
                .frame(width: 68)
                .accessibilityLabel("Show \(item.title) in Library")
        }
        .padding(.vertical, 8)
    }
}
