import SwiftUI
import UIKit

extension LibraryScreen {
    var sourceMenuSection: some View {
        Group {
            if !viewModel.sources.isEmpty {
                Section("Library") {
                    ForEach(viewModel.visibleSources) { source in
                        Button {
                            viewModel.selectSource(source.id)
                        } label: {
                            AppSelectableMenuRow(text: source.name, isSelected: viewModel.selectedSource?.id == source.id)
                        }
                    }
                }
            }
        }
    }

    var sortMenuSection: some View {
        Section("Sort") {
            ForEach(viewModel.sortOptions) { option in
                Button {
                    viewModel.selectSortOption(option)
                } label: {
                    AppSelectableMenuRow(text: viewModel.menuLabel(for: option), isSelected: viewModel.sortOption == option)
                }
            }
        }
    }

    var bankMenuSection: some View {
        Group {
            if viewModel.supportsBankFilter {
                Section("Bank") {
                    Button {
                        viewModel.selectedBank = nil
                    } label: {
                        AppSelectableMenuRow(text: "All banks", isSelected: viewModel.selectedBank == nil)
                    }

                    ForEach(viewModel.bankOptions, id: \.self) { bank in
                        Button {
                            viewModel.selectedBank = bank
                        } label: {
                            AppSelectableMenuRow(text: "Bank \(bank)", isSelected: viewModel.selectedBank == bank)
                        }
                    }
                }
            }
        }
    }

    var filterMenuSections: some View {
        Group {
            sourceMenuSection
            sortMenuSection
            bankMenuSection
        }
    }

    @ViewBuilder
    var content: some View {
        if viewModel.games.isEmpty {
            if viewModel.isLoading {
                AppFullscreenStatusOverlay(
                    text: "Loading library…",
                    showsProgress: true
                )
            } else {
                Group {
                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        AppPanelStatusCard(
                            text: errorMessage,
                            isError: true
                        )
                    } else {
                        AppPanelEmptyCard(text: "No data loaded.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            scrollableContent
        }
    }

    @ViewBuilder
    var scrollableContent: some View {
        if viewModel.showGroupedView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { idx, section in
                        if idx > 0 {
                            AppSectionDivider()
                        }

                        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                            ForEach(section.games) { game in
                                gameCard(for: game)
                            }
                        }
                    }

                    loadMoreFooter
                }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                    ForEach(viewModel.visibleSortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }

                loadMoreFooter
            }
        }
    }

    func gameCard(for game: PinballGame) -> some View {
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

                    libraryCardOverlay(for: game)
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
            viewModel.loadMoreGamesIfNeeded(currentGameID: game.id)
        }
        .buttonStyle(.plain)
    }

    private func libraryCardOverlay(for game: PinballGame) -> some View {
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

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.hasMoreVisibleGames {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    viewModel.loadMoreGamesIfNeeded(currentGameID: nil)
                }
        }
    }

    func consumeLibraryDeepLink() {
        guard let gameID = appNavigation.libraryGameIDToOpen else { return }
        guard viewModel.games.contains(where: { $0.id == gameID }) else { return }
        navigationPath = [gameID]
        appNavigation.libraryGameIDToOpen = nil
    }
}

private struct LibraryCardInlineTitleLabel: UIViewRepresentable {
    let title: String
    let variant: String?

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let resolvedVariant = variant?.trimmingCharacters(in: .whitespacesAndNewlines)
        uiView.attributedText = makeAttributedTitle(
            title: title,
            variant: resolvedVariant,
            traits: uiView.traitCollection
        )
        uiView.accessibilityLabel = resolvedVariant.map { "\(title), \($0)" } ?? title
        uiView.preferredMaxLayoutWidth = uiView.bounds.width
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        uiView.preferredMaxLayoutWidth = width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }
}

private func makeAttributedTitle(title: String, variant: String?, traits: UITraitCollection) -> NSAttributedString {
    let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = -1
    paragraphStyle.lineBreakMode = .byTruncatingTail

    let shadow = NSShadow()
    shadow.shadowColor = UIColor.black.withAlphaComponent(1.0)
    shadow.shadowOffset = CGSize(width: 0, height: 3)
    shadow.shadowBlurRadius = 4

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: UIColor.white,
        .paragraphStyle: paragraphStyle,
        .shadow: shadow
    ]

    let attributed = NSMutableAttributedString(string: title, attributes: titleAttributes)

    if let variant, !variant.isEmpty {
        attributed.append(NSAttributedString(string: " ", attributes: titleAttributes))

        let attachment = NSTextAttachment()
        attachment.image = makeLibraryVariantBadgeImage(text: variant, traits: traits)
        if let image = attachment.image {
            let verticalOffset = titleFont.descender.rounded(.toNearestOrAwayFromZero)
            attachment.bounds = CGRect(
                x: 0,
                y: verticalOffset,
                width: image.size.width,
                height: image.size.height
            )
        }

        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attachmentString.length))
        attributed.append(attachmentString)
    }

    return attributed
}

private func makeLibraryVariantBadgeImage(text: String, traits: UITraitCollection) -> UIImage {
    let font = UIFont.systemFont(ofSize: 9, weight: .semibold)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.white,
        .paragraphStyle: paragraphStyle
    ]

    let rawTextSize = (text as NSString).boundingRect(
        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: textAttributes,
        context: nil
    ).integral.size

    let size = CGSize(
        width: max(18, ceil(rawTextSize.width) + 12),
        height: max(14, ceil(rawTextSize.height) + 5)
    )

    let format = UIGraphicsImageRendererFormat()
    format.scale = max(traits.displayScale, 1)
    format.opaque = false

    let gold = UIColor(AppTheme.brandGold).resolvedColor(with: traits)
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.4, dy: 0.4)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        gold.withAlphaComponent(0.20).setFill()
        path.fill()
        gold.withAlphaComponent(0.42).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        let textRect = CGRect(
            x: 6,
            y: floor((size.height - rawTextSize.height) / 2),
            width: size.width - 12,
            height: rawTextSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: textAttributes)
    }
}
