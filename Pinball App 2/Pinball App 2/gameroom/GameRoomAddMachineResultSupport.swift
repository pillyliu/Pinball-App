import SwiftUI

struct GameRoomAddMachineResultRow: View {
    let game: GameRoomCatalogGame
    let metaLine: String
    let isVariantPickerPresented: Bool
    let pendingVariantPickerTitle: String
    let pendingVariantPickerOptions: [String]
    let onBeginAddMachineSelection: () -> Void
    let onDismissVariantPicker: () -> Void
    let onSelectPendingVariant: (String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayTitle)
                    .font(.subheadline.weight(.semibold))
                Text(metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Button(action: onBeginAddMachineSelection) {
                    Image(systemName: "plus")
                }
                .buttonStyle(AppCompactIconActionButtonStyle())
                .gameRoomAdaptivePopover(
                    isPresented: Binding(
                        get: { isVariantPickerPresented },
                        set: { presenting in
                            if !presenting {
                                onDismissVariantPicker()
                            }
                        }
                    ),
                    preferredHeight: min(CGFloat(pendingVariantPickerOptions.count) * 44 + 68, 300)
                ) { availableHeight in
                    GameRoomAddMachineVariantPickerPopover(
                        title: pendingVariantPickerTitle,
                        options: pendingVariantPickerOptions,
                        availableHeight: availableHeight,
                        onSelectVariant: onSelectPendingVariant
                    )
                }
            }
        }
        .padding(10)
        .appControlStyle()
    }
}

struct GameRoomAddMachineVariantPickerPopover: View {
    let title: String
    let options: [String]
    let availableHeight: CGFloat
    let onSelectVariant: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Choose the machine variant")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            onSelectVariant(option)
                        }
                        .buttonStyle(AppSecondaryActionButtonStyle())
                    }
                }
            }
            .frame(maxHeight: max(min(availableHeight - 44, 220), 0))
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }
}
