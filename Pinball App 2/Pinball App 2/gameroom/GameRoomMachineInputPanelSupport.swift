import SwiftUI

struct GameRoomMachineInputContent: View {
    let machine: OwnedMachine
    let hasOpenIssues: Bool
    let onSelectSheet: (GameRoomMachineInputSheet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputCategoryPanel(
                title: "Service",
                items: serviceInputItems,
                isDisabled: { _ in !(machine.status == .active || machine.status == .loaned) }
            )

            Divider()

            inputCategoryPanel(
                title: "Issue",
                items: issueInputItems,
                isDisabled: { item in item.sheet == .resolveIssue && !hasOpenIssues }
            )

            Divider()

            inputCategoryPanel(
                title: "Ownership / Media",
                items: ownershipAndMediaInputItems,
                isDisabled: { _ in false }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func inputCategoryPanel(
        title: String,
        items: [(title: String, sheet: GameRoomMachineInputSheet)],
        isDisabled: @escaping (((title: String, sheet: GameRoomMachineInputSheet))) -> Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AppCardSubheading(text: title)
            LazyVGrid(columns: inputGridColumns, spacing: 8) {
                ForEach(items, id: \.title) { item in
                    Button(action: { onSelectSheet(item.sheet) }) {
                        Text(item.title)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .appControlStyle()
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled(item))
                }
            }
        }
    }

    private var inputGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private var serviceInputItems: [(title: String, sheet: GameRoomMachineInputSheet)] {
        [
            ("Clean Glass", .cleanGlass),
            ("Clean Playfield", .cleanPlayfield),
            ("Swap Balls", .swapBalls),
            ("Check Pitch", .checkPitch),
            ("Level Machine", .levelMachine),
            ("General Inspection", .generalInspection)
        ]
    }

    private var issueInputItems: [(title: String, sheet: GameRoomMachineInputSheet)] {
        [
            ("Log Issue", .logIssue),
            ("Resolve Issue", .resolveIssue)
        ]
    }

    private var ownershipAndMediaInputItems: [(title: String, sheet: GameRoomMachineInputSheet)] {
        [
            ("Ownership Update", .ownershipUpdate),
            ("Install Mod", .installMod),
            ("Replace Part", .replacePart),
            ("Log Plays", .logPlays),
            ("Add Photo/Video", .addMedia)
        ]
    }
}
