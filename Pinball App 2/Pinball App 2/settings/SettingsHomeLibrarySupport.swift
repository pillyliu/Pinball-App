import SwiftUI

struct SettingsHomeLibrarySection: View {
    let manufacturers: [PinballCatalogManufacturerOption]
    let importedSources: [PinballImportedSourceRecord]
    let isEnabled: (String) -> Bool
    let isPinned: (String) -> Bool
    let onAddManufacturer: () -> Void
    let onAddVenue: () -> Void
    let onAddTournament: () -> Void
    let onToggleEnabled: (String, Bool) -> Void
    let onTogglePinned: (String, Bool) -> Void
    let onRefresh: (PinballImportedSourceRecord) -> Void
    let onDelete: (String) -> Void

    private var managedSources: [SettingsManagedSourceItem] {
        importedSources.map { source in
            SettingsManagedSourceItem(
                source: source,
                title: source.name,
                subtitle: managedSourceSubtitle(for: source),
                sourceType: source.type
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: "Library")

            AppCardSubheading(text: "Add")

            SettingsLibraryAddButtons(
                onAddManufacturer: onAddManufacturer,
                onAddVenue: onAddVenue,
                onAddTournament: onAddTournament
            )

            Text("Enabled adds that source's games to Library and Practice. Library adds the source to the Library source filter for quick switching. Up to \(PinballLibrarySourceStateStore.maxPinnedSources) sources can appear in Library at once.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SettingsManagedSourceTable(
                items: managedSources,
                isEnabled: isEnabled,
                isPinned: isPinned,
                onToggleEnabled: onToggleEnabled,
                onTogglePinned: onTogglePinned,
                onRefresh: onRefresh,
                onDelete: onDelete
            )

            if importedSources.isEmpty {
                AppPanelEmptyCard(text: "No sources added yet.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func managedSourceSubtitle(for source: PinballImportedSourceRecord) -> String {
        switch source.type {
        case .manufacturer:
            return "Manufacturer • \(gameCountLabel(manufacturers.first(where: { $0.id == source.providerSourceID })?.gameCount ?? 0))"
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
}

private struct SettingsManagedSourceItem: Identifiable {
    let source: PinballImportedSourceRecord
    let title: String
    let subtitle: String
    let sourceType: PinballLibrarySourceType

    var id: String { source.id }
}

private struct SettingsLibraryAddButtons: View {
    let onAddManufacturer: () -> Void
    let onAddVenue: () -> Void
    let onAddTournament: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let totalWidth = max(0, proxy.size.width - (spacing * 2))
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
