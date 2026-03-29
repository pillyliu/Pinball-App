import SwiftUI

struct LibraryGameGrid: View {
    let games: [PinballGame]
    let gridColumns: [GridItem]
    let gridSpacing: CGFloat
    let cardTotalHeight: CGFloat
    let cardInfoHeight: CGFloat
    let reduceMotion: Bool
    let cardTransition: Namespace.ID
    let onLoadMore: (String?) -> Void

    var body: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
            ForEach(games) { game in
                LibraryGameCard(
                    game: game,
                    cardTotalHeight: cardTotalHeight,
                    cardInfoHeight: cardInfoHeight,
                    reduceMotion: reduceMotion,
                    cardTransition: cardTransition,
                    onLoadMore: onLoadMore
                )
            }
        }
    }
}

struct LibraryGameCard: View {
    let game: PinballGame
    let cardTotalHeight: CGFloat
    let cardInfoHeight: CGFloat
    let reduceMotion: Bool
    let cardTransition: Namespace.ID
    let onLoadMore: (String?) -> Void

    var body: some View {
        NavigationLink(value: game.id) {
            let card = GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.82))

                    FallbackAsyncImageView(
                        candidates: game.cardArtworkCandidates,
                        emptyMessage: game.cardArtworkCandidates.isEmpty ? "No image" : nil,
                        contentMode: .fill,
                        fillAlignment: .center,
                        layoutMode: .widthFillTopCropBottom
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.0), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 0.18),
                            .init(color: Color.black.opacity(0.50), location: 0.40),
                            .init(color: Color.black.opacity(0.70), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    LibraryCardOverlay(
                        game: game,
                        cardInfoHeight: cardInfoHeight
                    )
                    .frame(width: proxy.size.width, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardTotalHeight)
            .appPanelStyle()
            .contentShape(Rectangle())

            if reduceMotion {
                card
            } else {
                card
                    .matchedTransitionSource(id: game.id, in: cardTransition)
            }
        }
        .onAppear {
            onLoadMore(game.id)
        }
        .buttonStyle(.plain)
    }
}

struct LibraryCardOverlay: View {
    let game: PinballGame
    let cardInfoHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LibraryCardInlineTitleLabel(
                title: game.name,
                variant: game.normalizedVariant
            )
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)

            AppOverlaySubtitle(game.manufacturerYearCardLine)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            AppOverlaySubtitle(game.locationBankLine.isEmpty ? " " : game.locationBankLine, emphasis: 0.9)
                .lineLimit(1)
                .opacity(game.locationBankLine.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, minHeight: cardInfoHeight, maxHeight: cardInfoHeight, alignment: .topLeading)
    }
}

struct LibraryCardInlineTitleLabel: UIViewRepresentable {
    let title: String
    let variant: String?

    private var resolvedVariant: String? {
        let trimmed = variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func makeUIView(context: Context) -> AppInlineTitleWithVariantUILabel {
        let label = AppInlineTitleWithVariantUILabel()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: AppInlineTitleWithVariantUILabel, context: Context) {
        uiView.configure(
            title: title,
            variant: resolvedVariant,
            lineLimit: 2,
            style: .overlay
        )
        uiView.accessibilityLabel = resolvedVariant.map { "\(title), \($0)" } ?? title
    }
}
