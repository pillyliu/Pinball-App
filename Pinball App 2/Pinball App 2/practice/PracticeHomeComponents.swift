import SwiftUI

struct SelectedGameMiniCard: View {
    let game: PinballGame
    var cardWidth: CGFloat = 122
    var cardHeight: CGFloat = 64
    private let cornerRadius: CGFloat = 10
    private let horizontalInset: CGFloat = 8
    private let bottomInset: CGFloat = 6
    private let titleBandHeight: CGFloat = 34

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PracticeSelectedGameCardBackground(game: game)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            PracticeSelectedGameMiniCardTitle(
                title: game.name,
                font: .system(size: 12, weight: .semibold),
                horizontalInset: horizontalInset,
                bottomInset: bottomInset,
                titleBandHeight: titleBandHeight
            )
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct ResumeSelectedGameCard: View {
    let game: PinballGame
    let targetHeight: CGFloat?
    private let horizontalInset: CGFloat = 10
    private let bottomInset: CGFloat = 11
    private let titleBandHeight: CGFloat = 40

    var body: some View {
        let height = max(72, targetHeight ?? 92)

        ZStack(alignment: .bottomLeading) {
            PracticeSelectedGameCardBackground(game: game)

            PracticeSelectedGameMiniCardTitle(
                title: game.name,
                font: .system(size: 14, weight: .semibold),
                horizontalInset: horizontalInset,
                bottomInset: bottomInset,
                titleBandHeight: titleBandHeight
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PracticeSelectedGameMiniCardTitle: View {
    let title: String
    let font: Font
    let horizontalInset: CGFloat
    let bottomInset: CGFloat
    let titleBandHeight: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear

            Text(title)
                .font(font)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, bottomInset)
        }
        .frame(maxWidth: .infinity, minHeight: titleBandHeight, maxHeight: titleBandHeight, alignment: .bottomLeading)
    }
}

struct PracticeSelectedGameCardBackground: View {
    let game: PinballGame

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.82))

                FallbackAsyncImageView(
                    candidates: game.miniPlayfieldCandidates,
                    emptyMessage: nil,
                    contentMode: .fill,
                    fillAlignment: .center,
                    layoutMode: .fill
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
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
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}
