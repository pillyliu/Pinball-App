import SwiftUI

struct GameRoomMachineContentView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let machine: OwnedMachine?
    @Binding var selectedSubview: GameRoomMachineSubview
    @Binding var selectedLogEventID: UUID?
    let linkedAttachment: (MachineEvent) -> MachineAttachment?
    let linkedEvent: (MachineAttachment) -> MachineEvent?
    let attachmentURL: (String) -> URL?
    let onOpenAttachment: (MachineAttachment) -> Void
    let onEditAttachment: (MachineAttachment) -> Void
    let onDeleteAttachment: (MachineAttachment) -> Void
    let onSelectInputSheet: (GameRoomMachineInputSheet) -> Void
    let onEditEvent: (MachineEvent) -> Void
    let onDeleteEvent: (MachineEvent) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameRoomMachineHeroSection(
                    imageCandidates: machine.map { catalogLoader.imageCandidates(for: $0) } ?? []
                )

                if let machine {
                    machineDetailContent(for: machine)
                } else {
                    GameRoomMachineUnavailableMessage()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func machineDetailContent(for machine: OwnedMachine) -> some View {
        GameRoomMachineHeaderSection(
            machine: machine,
            metaLine: gameRoomMachineMetaLine(
                machine,
                areaName: store.area(for: machine.gameRoomAreaID)?.name
            )
        )
        GameRoomMachineSubviewPicker(selectedSubview: $selectedSubview)
        machineSubviewContent(for: machine)
    }

    @ViewBuilder
    private func machineSubviewContent(for machine: OwnedMachine) -> some View {
        switch selectedSubview {
        case .summary:
            summarySection(for: machine)
        case .input:
            inputSection(for: machine)
        case .log:
            logSection(for: machine)
        }
    }

    private func summarySection(for machine: OwnedMachine) -> some View {
        let snapshot = store.snapshot(for: machine.id)
        let recentAttachments = gameRoomRecentAttachments(
            for: machine.id,
            attachments: store.state.attachments
        )
        return GameRoomMachineSummaryContent(
            machine: machine,
            snapshot: snapshot,
            recentAttachments: recentAttachments,
            attachmentURL: attachmentURL,
            linkedEvent: linkedEvent,
            onOpenAttachment: onOpenAttachment,
            onEditAttachment: onEditAttachment,
            onDeleteAttachment: onDeleteAttachment,
            onOpenLogEvent: { event in
                selectedSubview = .log
                selectedLogEventID = event.id
            }
        )
    }

    private func inputSection(for machine: OwnedMachine) -> some View {
        GameRoomMachineInputContent(
            machine: machine,
            hasOpenIssues: gameRoomMachineHasOpenIssues(
                machineID: machine.id,
                issues: store.state.issues
            ),
            onSelectSheet: onSelectInputSheet
        )
    }

    private func logSection(for machine: OwnedMachine) -> some View {
        let events = gameRoomSortedMachineEvents(
            for: machine.id,
            events: store.state.events
        )
        return GameRoomMachineLogContent(
            events: events,
            selectedLogEventID: $selectedLogEventID,
            linkedAttachment: linkedAttachment,
            onOpenAttachment: onOpenAttachment,
            onEditEvent: onEditEvent,
            onDeleteEvent: onDeleteEvent
        )
    }
}
