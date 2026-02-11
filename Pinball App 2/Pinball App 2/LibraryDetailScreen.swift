import SwiftUI
import WebKit

struct PinballGameDetailView: View {
    let game: PinballGame
    @StateObject private var viewModel: PinballGameInfoViewModel
    @State private var activeVideoID: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(game: PinballGame) {
        self.game = game
        _viewModel = StateObject(wrappedValue: PinballGameInfoViewModel(slug: game.slug))
    }

    var body: some View {
        GeometryReader { geo in
            let viewportSize = geo.size
            let largeTablet = AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportSize.width)
            let usesDesktopLandscapeLayout = largeTablet && viewportSize.width > viewportSize.height

            let gap: CGFloat = 14
            let horizontalPadding: CGFloat = 14
            let availableWidth = max(0, viewportSize.width - (horizontalPadding * 2) - (gap * 2))
            let unitWidth = max(180, availableWidth / 4)
            let desktopCardHeight = max(460, viewportSize.height - 220)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if usesDesktopLandscapeLayout {
                        HStack(alignment: .top, spacing: gap) {
                            imageCard(usesDesktopLandscapeLayout: true)
                                .frame(width: unitWidth, alignment: .topLeading)
                                .frame(minHeight: desktopCardHeight, alignment: .top)
                            videosCard(usesDesktopLandscapeLayout: true)
                                .frame(width: unitWidth * 2, alignment: .topLeading)
                                .frame(minHeight: desktopCardHeight, alignment: .top)
                            gameInfoCard
                                .frame(width: unitWidth, alignment: .topLeading)
                                .frame(minHeight: desktopCardHeight, alignment: .top)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        imageCard(usesDesktopLandscapeLayout: false)
                        videosCard(usesDesktopLandscapeLayout: false)
                        gameInfoCard
                    }

                    sourcesCard
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AppBackground())
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .appEdgeBackGesture(dismiss: dismiss)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func imageCard(usesDesktopLandscapeLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            imagePreview(usesDesktopLandscapeLayout: usesDesktopLandscapeLayout)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(game.metaLine)
                .font(.subheadline)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                NavigationLink("Rulesheet") {
                    RulesheetView(slug: game.slug)
                }
                .buttonStyle(.glass)

                if !game.fullscreenPlayfieldCandidates.isEmpty {
                    NavigationLink("Playfield") {
                        HostedImageView(imageCandidates: game.fullscreenPlayfieldCandidates)
                    }
                    .buttonStyle(.glass)
                }
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    @ViewBuilder
    private func imagePreview(usesDesktopLandscapeLayout: Bool) -> some View {
        if usesDesktopLandscapeLayout {
            landscapeImagePreview
        } else {
            portraitImagePreview
        }
    }

    private var landscapeImagePreview: some View {
        FallbackAsyncImageView(
            candidates: game.gamePlayfieldCandidates,
            emptyMessage: nil,
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
        .id("game-detail-image-landscape")
    }

    private var portraitImagePreview: some View {
        Rectangle()
            .fill(Color.clear)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                FallbackAsyncImageView(
                    candidates: game.gamePlayfieldCandidates,
                    emptyMessage: nil,
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .clipped()
            .id("game-detail-image-portrait")
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sources")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                if let rulesheetSourceURL = game.rulesheetSourceURL {
                    Link("Rulesheet (source)", destination: rulesheetSourceURL)
                        .buttonStyle(.glass)
                }

                if let playfieldSourceURL = game.playfieldImageSourceURL {
                    Link("Playfield (source)", destination: playfieldSourceURL)
                        .buttonStyle(.glass)
                }
            }

            if game.rulesheetSourceURL == nil && game.playfieldImageSourceURL == nil {
                Text("No sources available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func videosCard(usesDesktopLandscapeLayout: Bool) -> some View {
        let playableVideos = game.videos.compactMap { video -> PinballGame.PlayableVideo? in
            guard let rawURL = video.url,
                  let id = PinballGame.youtubeID(from: rawURL) else {
                return nil
            }
            return PinballGame.PlayableVideo(
                id: id,
                label: video.label ?? "Video"
            )
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Videos")
                .font(.headline)
                .foregroundStyle(.primary)

            if playableVideos.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
                        )
                    Text("No videos listed.")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                if let activeVideoID {
                    EmbeddedYouTubeView(videoID: activeVideoID)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(minHeight: usesDesktopLandscapeLayout ? 260 : 0)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                LazyVGrid(
                    columns: usesDesktopLandscapeLayout
                        ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                        : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(playableVideos) { video in
                        Button {
                            activeVideoID = video.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                YouTubeThumbnailView(candidates: video.thumbnailCandidates)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Text(video.label)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                activeVideoID == video.id
                                    ? Color(uiColor: .secondarySystemFill)
                                    : Color(uiColor: .tertiarySystemFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(uiColor: .separator).opacity(activeVideoID == video.id ? 0.8 : 0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .appPanelStyle()
        .onAppear {
            if activeVideoID == nil {
                activeVideoID = playableVideos.first?.id
            }
        }
    }

    private var gameInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Info")
                .font(.headline)
                .foregroundStyle(.primary)

            switch viewModel.status {
            case .idle, .loading:
                Text("Loading...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .missing:
                Text("No game info yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .error:
                Text("Could not load game info.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .loaded:
                if let infoText = viewModel.markdownText {
                    NativeMarkdownView(markdown: infoText)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}

private struct NativeMarkdownView: View {
    let markdown: String

    private var blocks: [MarkdownBlock] {
        NativeMarkdownParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            MarkdownInlineText(raw: text, baseFont: headingFont(level), textColor: .primary)
                .fontWeight(.semibold)
                .padding(.top, level <= 2 ? 4 : 2)
        case .paragraph(let text):
            MarkdownInlineText(raw: text, baseFont: .body, textColor: .primary)
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        MarkdownInlineText(raw: item, baseFont: .body, textColor: .primary)
                    }
                }
            }
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(item.number).")
                            .foregroundStyle(.secondary)
                            .font(.body.monospacedDigit())
                        MarkdownInlineText(raw: item.text, baseFont: .body, textColor: .primary)
                    }
                }
            }
        case .blockquote(let lines):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        MarkdownInlineText(raw: line, baseFont: .body, textColor: .secondary)
                    }
                }
            }
        case .codeBlock(_, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
            )
        case .horizontalRule:
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 1)
                .padding(.vertical, 2)
        case .table(let headers, let alignments, let rows):
            MarkdownTableView(headers: headers, alignments: alignments, rows: rows)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        case 3: return .headline
        default: return .subheadline
        }
    }
}

private struct MarkdownInlineText: View {
    let raw: String
    let baseFont: Font
    let textColor: Color

    var body: some View {
        if let attributed = parsed {
            Text(attributed)
                .font(baseFont)
                .foregroundStyle(textColor)
                .tint(AppTheme.rulesheetLink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(raw)
                .font(baseFont)
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var parsed: AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return try? AttributedString(markdown: raw, options: options)
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let alignments: [MarkdownTableAlignment]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(headers.indices, id: \.self) { idx in
                        tableCell(
                            text: headers[idx],
                            alignment: alignments[safe: idx] ?? .left,
                            isHeader: true
                        )
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(row.indices, id: \.self) { idx in
                            tableCell(
                                text: row[idx],
                                alignment: alignments[safe: idx] ?? .left,
                                isHeader: false
                            )
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private func tableCell(text: String, alignment: MarkdownTableAlignment, isHeader: Bool) -> some View {
        MarkdownInlineText(
            raw: text,
            baseFont: isHeader ? .subheadline : .footnote,
            textColor: .primary
        )
        .fontWeight(isHeader ? .semibold : .regular)
        .frame(minWidth: 120, alignment: swiftUIAlignment(alignment))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isHeader
                ? Color(uiColor: .secondarySystemBackground)
                : Color(uiColor: .tertiarySystemBackground)
        )
        .overlay(
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.7))
                .frame(width: 1),
            alignment: .trailing
        )
        .overlay(
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.7))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func swiftUIAlignment(_ alignment: MarkdownTableAlignment) -> Alignment {
        switch alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}

private struct EmbeddedYouTubeView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1" />
          <style>
            html, body { margin: 0; padding: 0; background: #000; height: 100%; }
            iframe { border: 0; width: 100%; height: 100%; }
          </style>
        </head>
        <body>
          <iframe
            src="https://www.youtube-nocookie.com/embed/\(videoID)"
            title="YouTube video player"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen>
          </iframe>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
}

private struct YouTubeThumbnailView: View {
    let candidates: [URL]
    @State private var index = 0

    var body: some View {
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil

        AsyncImage(url: currentURL) { phase in
            switch phase {
            case .empty:
                Color(uiColor: .tertiarySystemBackground)
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                if index + 1 < candidates.count {
                    Color(uiColor: .tertiarySystemBackground)
                        .task {
                            index += 1
                        }
                } else {
                    Color(uiColor: .tertiarySystemBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            @unknown default:
                Color(uiColor: .tertiarySystemBackground)
            }
        }
    }
}
