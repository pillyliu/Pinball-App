import SwiftUI

struct GameRoomMiniCard: View {
    let machine: OwnedMachine
    let imageCandidates: [URL]
    let transitionSourceID: String
    let transitionNamespace: Namespace.ID
    let snapshot: OwnedMachineSnapshot
    let isSelected: Bool
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 10

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameRoomCollectionArtworkChrome(
                imageCandidates: imageCandidates,
                isSelected: isSelected,
                cornerRadius: cornerRadius
            )
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(machine.displayTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        if let label = variantBadgeLabel {
                            GameRoomVariantPill(label: label, style: .mini)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(isSelected ? AppTheme.brandGold.opacity(0.88) : Color.clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            HStack(spacing: 6) {
                GameRoomAttentionIndicator(attentionState: snapshot.attentionState, showsBorder: true)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .frame(height: 64)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .matchedTransitionSource(id: transitionSourceID, in: transitionNamespace)
        .onTapGesture(perform: onTap)
    }

    private var variantBadgeLabel: String? {
        gameRoomVariantBadgeLabel(for: machine)
    }
}

struct GameRoomListRow: View {
    let machine: OwnedMachine
    let imageCandidates: [URL]
    let transitionSourceID: String
    let transitionNamespace: Namespace.ID
    let snapshot: OwnedMachineSnapshot
    let areaName: String?
    let isSelected: Bool
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            GameRoomCollectionArtworkChrome(
                imageCandidates: imageCandidates,
                isSelected: isSelected,
                cornerRadius: cornerRadius
            )

            HStack(spacing: 8) {
                GameRoomAttentionIndicator(attentionState: snapshot.attentionState)

                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
                        .lineLimit(1)

                    Text(metaLine)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.86))
                        .shadow(color: .black.opacity(1.0), radius: 3, x: 0, y: 2)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let label = variantBadgeLabel {
                    GameRoomVariantPill(label: label, style: .standard)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .matchedTransitionSource(id: transitionSourceID, in: transitionNamespace)
        .onTapGesture(perform: onTap)
    }

    private var metaLine: String {
        gameRoomLocationText(
            areaName: areaName,
            groupNumber: machine.groupNumber,
            position: machine.position
        )
    }

    private var variantBadgeLabel: String? {
        gameRoomVariantBadgeLabel(for: machine)
    }
}
