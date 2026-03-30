import SwiftUI

struct GameRoomCollectionArtworkChrome: View {
    let imageCandidates: [URL]
    let isSelected: Bool
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
            .overlay(collectionArtworkOverlay)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected ? AppTheme.brandGold.opacity(0.88) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var collectionArtworkOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.82))

            FallbackAsyncImageView(
                candidates: imageCandidates,
                emptyMessage: nil,
                contentMode: .fill,
                fillAlignment: .center,
                layoutMode: .fill
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.0), location: 0.0),
                    .init(color: Color.black.opacity(0.0), location: 0.18),
                    .init(color: Color.black.opacity(0.50), location: 0.40),
                    .init(color: Color.black.opacity(0.78), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct GameRoomAttentionIndicator: View {
    let attentionState: GameRoomAttentionState
    var showsBorder = false

    var body: some View {
        Circle()
            .fill(gameRoomAttentionColor(attentionState))
            .overlay {
                if showsBorder {
                    Circle()
                        .stroke(AppTheme.brandInk.opacity(0.35), lineWidth: 1)
                }
            }
            .frame(width: 8, height: 8)
    }
}
