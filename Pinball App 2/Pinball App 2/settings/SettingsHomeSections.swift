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

    var body: some View {
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
                    Button("Manufacturer") {
                        navigationPath.append(.addManufacturer)
                    }
                    .buttonStyle(AppCompactSecondaryActionButtonStyle(fillsWidth: true))
                    .frame(width: manufacturerWidth)

                    Button("Venue") {
                        navigationPath.append(.addVenue)
                    }
                    .buttonStyle(AppCompactSecondaryActionButtonStyle(fillsWidth: true))
                    .frame(width: venueWidth)

                    Button("Tournament") {
                        navigationPath.append(.addTournament)
                    }
                    .buttonStyle(AppCompactSecondaryActionButtonStyle(fillsWidth: true))
                    .frame(width: tournamentWidth)
                }
            }
            .frame(height: 34)
            .frame(maxWidth: .infinity, alignment: .leading)

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

            if let statusMessage = viewModel.cacheStatusMessage {
                AppInlineTaskStatus(
                    text: statusMessage,
                    showsProgress: viewModel.isClearingCache,
                    isError: viewModel.cacheStatusIsError
                )
            } else if viewModel.isClearingCache {
                AppInlineTaskStatus(
                    text: "Clearing cached data…",
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
        let importedRows = viewModel.importedSources.compactMap { source -> ManagedSourceRow? in
            guard !viewModel.builtinSources.contains(where: { $0.id == source.id }) else {
                return nil
            }
            return ManagedSourceRow(
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
                AppCardSubheading(text: source.title)
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
                            .buttonStyle(AppInlineActionChipButtonStyle())
                            .accessibilityLabel("Refresh \(source.title)")
                        }

                        if source.sourceType == .tournament {
                            Button("Refresh") {
                                if let imported = viewModel.importedSources.first(where: { $0.id == source.id }) {
                                    Task { await viewModel.refreshTournament(imported) }
                                }
                            }
                            .buttonStyle(AppInlineActionChipButtonStyle())
                            .accessibilityLabel("Refresh \(source.title)")
                        }

                        Button("Delete", role: .destructive) {
                            viewModel.removeImportedSource(source.id)
                        }
                        .buttonStyle(AppInlineActionChipButtonStyle(isDestructive: true))
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
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onToggleIntroOverlayForNextLaunch()
                }
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
