import SwiftUI

struct GameRoomMachineFullscreenPhotoItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

enum GameRoomMachineSubview: String, CaseIterable, Identifiable {
    case summary
    case input
    case log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "Summary"
        case .input: return "Input"
        case .log: return "Log"
        }
    }
}

struct GameRoomMachineHeroSection: View {
    let imageCandidates: [URL]

    var body: some View {
        ConstrainedAsyncImagePreview(
            candidates: imageCandidates,
            emptyMessage: "No image",
            maxAspectRatio: 4.0 / 3.0,
            imagePadding: 0
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GameRoomMachineHeaderSection: View {
    let machine: OwnedMachine
    let metaLine: String

    var body: some View {
        let statusColor = gameRoomStatusColor(machine.status)
        VStack(alignment: .leading, spacing: 6) {
            AppCardTitleWithVariant(
                text: machine.displayTitle,
                variant: gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle),
                lineLimit: 2
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                AppTintedPill(
                    title: gameRoomStatusLabel(machine.status),
                    foreground: statusColor,
                    style: .machineTitle
                )
            }
        }
    }
}

struct GameRoomMachineSubviewPicker: View {
    @Binding var selectedSubview: GameRoomMachineSubview

    var body: some View {
        Picker("Subview", selection: $selectedSubview) {
            ForEach(GameRoomMachineSubview.allCases) { subview in
                Text(subview.title).tag(subview)
            }
        }
        .appSegmentedControlStyle()
    }
}

struct GameRoomMachineUnavailableMessage: View {
    var body: some View {
        Text("This machine is no longer available.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
