import SwiftUI

struct GameRoomSelectedSummaryCard: View {
    @ObservedObject var store: GameRoomStore
    let selectedMachine: OwnedMachine?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppCardTitle(text: "Selected Machine")

            if let selectedMachine {
                AppCardTitleWithVariant(
                    text: selectedMachine.displayTitle,
                    variant: variantBadgeLabel(for: selectedMachine),
                    lineLimit: 2
                )

                Text(locationLine(for: selectedMachine))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                AppCardSubheading(text: "Current Snapshot")
                    .padding(.top, 2)

                AppMetricGrid(items: snapshotMetrics(for: selectedMachine))

            } else {
                AppPanelEmptyCard(text: "Select a machine from the collection below.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func locationLine(for machine: OwnedMachine) -> String {
        gameRoomLocationText(
            areaName: store.area(for: machine.gameRoomAreaID)?.name,
            groupNumber: machine.groupNumber,
            position: machine.position
        )
    }

    private func snapshotMetrics(for machine: OwnedMachine) -> [AppMetricItem] {
        let snapshot = store.snapshot(for: machine.id)
        return gameRoomSnapshotMetrics(snapshot: snapshot, purchaseDate: machine.purchaseDate)
    }

    private func variantBadgeLabel(for machine: OwnedMachine) -> String? {
        gameRoomVariantBadgeLabel(for: machine)
    }
}
