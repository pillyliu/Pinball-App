import SwiftUI

struct GameRoomArchiveSettingsView: View {
    private enum ArchiveFilter: String, CaseIterable, Identifiable {
        case all
        case sold
        case traded
        case archived

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .sold: return "Sold"
            case .traded: return "Traded"
            case .archived: return "Archived"
            }
        }
    }

    private struct ArchiveFilterPicker: View {
        @Binding var selectedFilter: ArchiveFilter

        var body: some View {
            Picker("Archive Filter", selection: $selectedFilter) {
                ForEach(ArchiveFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .appSegmentedControlStyle()
        }
    }

    private struct ArchiveMachineRow: View {
        let machine: OwnedMachine
        let sourceID: String
        let metaLine: String
        let gameTransition: Namespace.ID
        let onOpenMachineView: (UUID, String?, String) -> Void

        var body: some View {
            Button(action: openMachine) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(metaLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .matchedTransitionSource(id: sourceID, in: gameTransition)
            }
            .buttonStyle(.plain)
        }

        private func openMachine() {
            onOpenMachineView(machine.id, sourceID, machine.displayTitle)
        }
    }

    @ObservedObject var store: GameRoomStore
    let gameTransition: Namespace.ID
    let onOpenMachineView: (UUID, String?, String) -> Void
    @State private var selectedFilter: ArchiveFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArchiveFilterPicker(selectedFilter: $selectedFilter)
            archiveListContent
            archiveSummaryFooter
        }
    }

    @ViewBuilder
    private var archiveListContent: some View {
        if filteredMachines.isEmpty {
            AppPanelEmptyCard(text: "No archived machine instances yet.")
        } else {
            ForEach(filteredMachines) { machine in
                ArchiveMachineRow(
                    machine: machine,
                    sourceID: gameRoomMachineTransitionSourceID(machineID: machine.id, surface: "archive-row"),
                    metaLine: archiveMetaLine(for: machine),
                    gameTransition: gameTransition,
                    onOpenMachineView: onOpenMachineView
                )
            }
        }
    }

    private var archiveSummaryFooter: some View {
        Text("Archived machines: \(filteredMachines.count)")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var filteredMachines: [OwnedMachine] {
        switch selectedFilter {
        case .all:
            return store.archivedMachines
        case .sold:
            return store.archivedMachines.filter { $0.status == .sold }
        case .traded:
            return store.archivedMachines.filter { $0.status == .traded }
        case .archived:
            return store.archivedMachines.filter { $0.status == .archived }
        }
    }

    private func archiveMetaLine(for machine: OwnedMachine) -> String {
        var parts: [String] = [machine.status.rawValue.capitalized]
        if let area = store.area(for: machine.gameRoomAreaID)?.name {
            parts.append(area)
        }
        if let soldOrTradedDate = machine.soldOrTradedDate {
            parts.append(soldOrTradedDate.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " • ")
    }
}
