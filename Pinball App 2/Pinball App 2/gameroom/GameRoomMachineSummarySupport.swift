import SwiftUI

struct GameRoomMachineSummaryContent: View {
    let machine: OwnedMachine
    let snapshot: OwnedMachineSnapshot
    let recentAttachments: [MachineAttachment]
    let attachmentURL: (String) -> URL?
    let linkedEvent: (MachineAttachment) -> MachineEvent?
    let onOpenAttachment: (MachineAttachment) -> Void
    let onEditAttachment: (MachineAttachment) -> Void
    let onDeleteAttachment: (MachineAttachment) -> Void
    let onOpenLogEvent: (MachineEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            snapshotSummaryPanel
            recentMediaPanel
        }
    }

    private var snapshotSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            AppCardSubheading(text: "Current Snapshot")
            AppMetricGrid(items: [
                AppMetricItem(label: "Open Issues", value: "\(snapshot.openIssueCount)"),
                AppMetricItem(label: "Current Plays", value: "\(snapshot.currentPlayCount)"),
                AppMetricItem(label: "Due Tasks", value: "\(snapshot.dueTaskCount)"),
                AppMetricItem(label: "Last Service", value: snapshot.lastServiceAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
                AppMetricItem(label: "Pitch", value: snapshot.currentPitchValue.map { String(format: "%.1f", $0) } ?? "—"),
                AppMetricItem(label: "Last Level", value: snapshot.lastLeveledAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
                AppMetricItem(label: "Last Inspection", value: snapshot.lastGeneralInspectionAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
                AppMetricItem(label: "Purchase Date", value: machine.purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var recentMediaPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppCardSubheading(text: "Media")
            if recentAttachments.isEmpty {
                AppPanelEmptyCard(text: "No media attached yet.")
            } else {
                LazyVGrid(columns: mediaGridColumns, spacing: 8) {
                    ForEach(Array(recentAttachments.prefix(12))) { attachment in
                        mediaAttachmentTile(attachment)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func mediaAttachmentTile(_ attachment: MachineAttachment) -> some View {
        let sourceEvent = linkedEvent(attachment)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                onOpenAttachment(attachment)
            } label: {
                GameRoomAttachmentSquareTile(
                    attachment: attachment,
                    resolvedURL: attachmentURL(attachment.uri)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Edit Media") {
                    onEditAttachment(attachment)
                }
                Button("Delete Media", role: .destructive) {
                    onDeleteAttachment(attachment)
                }
            }

            if let sourceEvent {
                Button("Open Log Entry") {
                    onOpenLogEvent(sourceEvent)
                }
                .font(.caption2.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    private var mediaGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }
}
