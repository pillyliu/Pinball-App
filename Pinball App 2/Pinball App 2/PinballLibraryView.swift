import SwiftUI
import Combine
import WebKit
import UIKit

struct PinballLibraryView: View {
    @StateObject private var viewModel = PinballLibraryViewModel()
    @State private var controlsHeight: CGFloat = 96
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscapePhone: Bool { verticalSizeClass == .compact }
    private let landscapeControlHeight: CGFloat = 40
    private var cardsTopBuffer: CGFloat {
        if isLandscapePhone {
            return max(6, controlsHeight - 40)
        }
        return max(20, controlsHeight - 10)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ZStack(alignment: .top) {
                    content
                        .padding(.horizontal, 14)
                        .ignoresSafeArea(edges: .bottom)

                    GeometryReader { geo in
                        let safeTop = geo.safeAreaInsets.top
                        let fadeHeight = isLandscapePhone
                            ? max(52, safeTop + 30)
                            : max(128, controlsHeight + safeTop + 22)

                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.black.opacity(0.62), location: 0.0),
                                .init(color: Color.black.opacity(0.62), location: 0.08),
                                .init(color: Color.black.opacity(0.32), location: 0.50),
                                .init(color: Color.black.opacity(0.17), location: 0.8),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: fadeHeight, alignment: .top)
                        .ignoresSafeArea(edges: [.top, .horizontal])
                        .allowsHitTesting(false)
                    }
                    .zIndex(0.5)

                    VStack(spacing: 8) {
                        controls
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: LibraryControlsHeightKey.self, value: geo.size.height)
                                }
                            )

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                        }
                    }
                    .zIndex(1)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onPreferenceChange(LibraryControlsHeightKey.self) { newValue in
                guard newValue > 0 else { return }
                controlsHeight = newValue
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var controls: some View {
        Group {
            if isLandscapePhone {
                GeometryReader { geo in
                    let spacing: CGFloat = 8
                    let total = max(0, geo.size.width - (spacing * 2))
                    let minBankWidth: CGFloat = 82
                    let minSortWidth: CGFloat = 130
                    let idealSortWidth: CGFloat = 190 // keep "Sort: Alphabetical" fully visible
                    // Nudge search wider so the search/sort gap sits on the screen center.
                    let centeredSearchWidth = (total * 0.5) + (spacing * 0.5)
                    let searchWidth = max(130, centeredSearchWidth)
                    let sortMaxAllowed = max(minSortWidth, total - searchWidth - minBankWidth)
                    let sortWidth = min(idealSortWidth, sortMaxAllowed)
                    let bankWidth = max(minBankWidth, total - searchWidth - sortWidth)

                    HStack(spacing: spacing) {
                        searchField
                            .frame(width: searchWidth)
                            .frame(height: landscapeControlHeight)
                        sortMenu
                            .frame(width: sortWidth)
                            .frame(height: landscapeControlHeight)
                        bankMenu
                            .frame(width: bankWidth)
                            .frame(height: landscapeControlHeight)
                    }
                }
                .frame(height: landscapeControlHeight)
            } else {
                VStack(spacing: 10) {
                    searchField
                    HStack(spacing: 8) {
                        sortMenu
                        bankMenu
                    }
                }
            }
        }
    }

    private var searchField: some View {
        TextField(
            "",
            text: $viewModel.query,
            prompt: Text("Search games...")
                .foregroundStyle(Color(white: 0.72))
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .font(.subheadline)
        .foregroundStyle(Color(white: 0.96))
        .padding(.horizontal, isLandscapePhone ? 11 : 12)
        .padding(.vertical, isLandscapePhone ? 6 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isLandscapePhone ? landscapeControlHeight : nil)
        .appGlassControlStyle()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(PinballLibrarySortOption.allCases) { option in
                Button(option.menuLabel) { viewModel.sortOption = option }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedSortLabel)
                    .font(isLandscapePhone ? .subheadline : .caption2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(isLandscapePhone ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isLandscapePhone ? 11 : 10)
            .padding(.vertical, isLandscapePhone ? 6 : 6)
            .frame(height: isLandscapePhone ? landscapeControlHeight : nil)
            .appGlassControlStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.white)
        .disabled(viewModel.games.isEmpty)
    }

    private var bankMenu: some View {
        Menu {
            Button("All banks") { viewModel.selectedBank = nil }
            ForEach(viewModel.bankOptions, id: \.self) { bank in
                Button("Bank \(bank)") { viewModel.selectedBank = bank }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedBankLabel)
                    .font(isLandscapePhone ? .subheadline : .caption2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(isLandscapePhone ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isLandscapePhone ? 11 : 10)
            .padding(.vertical, isLandscapePhone ? 6 : 6)
            .frame(height: isLandscapePhone ? landscapeControlHeight : nil)
            .appGlassControlStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.white)
        .disabled(viewModel.games.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.games.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isLoading {
                    Text("Loading library...")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No data loaded.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if viewModel.showGroupedView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { idx, section in
                        if idx > 0 {
                            Divider()
                                .overlay(Color.white)
                                .padding(.vertical, 10)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                            ForEach(section.games) { game in
                                gameCard(for: game)
                            }
                        }
                    }
                }
                .padding(.top, cardsTopBuffer)
                .padding(.vertical, 2)
            }
            .ignoresSafeArea(edges: .bottom)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.sortedFilteredGames) { game in
                        gameCard(for: game)
                    }
                }
                .padding(.top, cardsTopBuffer)
                .padding(.vertical, 2)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func gameCard(for game: PinballGame) -> some View {
        NavigationLink {
            PinballGameDetailView(game: game)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                FallbackAsyncImageView(
                    candidates: game.libraryPlayfieldCandidates,
                    emptyMessage: game.playfieldLocalURL == nil ? "No image" : nil
                )
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(height: 44, alignment: .topLeading)

                    Text(game.manufacturerYearLine)
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.7))
                        .lineLimit(1)

                    Text(game.locationBankLine)
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.78))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .appPanelStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 96
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    PinballLibraryView()
}

private struct PinballGameDetailView: View {
    let game: PinballGame
    @StateObject private var viewModel: PinballGameInfoViewModel
    @State private var activeVideoID: String?
    @Environment(\.dismiss) private var dismiss

    init(game: PinballGame) {
        self.game = game
        _viewModel = StateObject(wrappedValue: PinballGameInfoViewModel(slug: game.slug))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                imageCard
                videosCard
                gameInfoCard
                sourcesCard
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(AppBackground())
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 14).onEnded { value in
                guard value.startLocation.x < 28 else { return }
                guard value.translation.width > 80 else { return }
                guard abs(value.translation.height) < 90 else { return }
                dismiss()
            }
        )
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FallbackAsyncImageView(candidates: game.gamePlayfieldCandidates, emptyMessage: nil)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(game.metaLine)
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.7))

            HStack(spacing: 8) {
                NavigationLink("Rulesheet") {
                    RulesheetView(slug: game.slug)
                }
                .buttonStyle(.bordered)

                if !game.fullscreenPlayfieldCandidates.isEmpty {
                    NavigationLink("Playfield") {
                        HostedImageView(imageCandidates: game.fullscreenPlayfieldCandidates)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.caption)
            .tint(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let rulesheetSourceURL = game.rulesheetSourceURL {
                    Link("Rulesheet (source)", destination: rulesheetSourceURL)
                        .buttonStyle(.bordered)
                }

                if let playfieldSourceURL = game.playfieldImageSourceURL {
                    Link("Playfield (source)", destination: playfieldSourceURL)
                        .buttonStyle(.bordered)
                }
            }

            if game.rulesheetSourceURL == nil && game.playfieldImageSourceURL == nil {
                Text("No sources available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .tint(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var videosCard: some View {
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
                .foregroundStyle(.white)

            if playableVideos.isEmpty {
                Text("No videos listed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if let activeVideoID {
                    EmbeddedYouTubeView(videoID: activeVideoID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
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
                                    .foregroundStyle(Color(white: 0.95))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(activeVideoID == video.id ? Color(white: 0.24) : Color(white: 0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(white: activeVideoID == video.id ? 0.5 : 0.28), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .foregroundStyle(.white)

            switch viewModel.status {
            case .idle, .loading:
                Text("Loading...")
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.85))
            case .missing:
                Text("No game info yet.")
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.85))
            case .error:
                Text("Could not load game info.")
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.85))
            case .loaded:
                if let infoText = viewModel.markdownText {
                    NativeMarkdownView(markdown: infoText)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            MarkdownInlineText(raw: text, baseFont: headingFont(level), textColor: .white)
                .fontWeight(.semibold)
                .padding(.top, level <= 2 ? 4 : 2)
        case .paragraph(let text):
            MarkdownInlineText(raw: text, baseFont: .body, textColor: Color(white: 0.92))
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(Color(white: 0.9))
                        MarkdownInlineText(raw: item, baseFont: .body, textColor: Color(white: 0.92))
                    }
                }
            }
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(item.number).")
                            .foregroundStyle(Color(white: 0.9))
                            .font(.body.monospacedDigit())
                        MarkdownInlineText(raw: item.text, baseFont: .body, textColor: Color(white: 0.92))
                    }
                }
            }
        case .blockquote(let lines):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color(white: 0.35))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        MarkdownInlineText(raw: line, baseFont: .body, textColor: Color(white: 0.85))
                    }
                }
            }
        case .codeBlock(_, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(Color(white: 0.95))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(white: 0.22), lineWidth: 1)
            )
        case .horizontalRule:
            Rectangle()
                .fill(Color(white: 0.25))
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
                .tint(Color(red: 0.65, green: 0.78, blue: 1.0))
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
                    .stroke(Color(white: 0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private func tableCell(text: String, alignment: MarkdownTableAlignment, isHeader: Bool) -> some View {
        MarkdownInlineText(
            raw: text,
            baseFont: isHeader ? .subheadline : .footnote,
            textColor: isHeader ? .white : Color(white: 0.92)
        )
        .fontWeight(isHeader ? .semibold : .regular)
        .frame(minWidth: 120, alignment: swiftUIAlignment(alignment))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isHeader ? Color(white: 0.14) : Color(white: 0.09))
        .overlay(
            Rectangle()
                .fill(Color(white: 0.22))
                .frame(width: 1),
            alignment: .trailing
        )
        .overlay(
            Rectangle()
                .fill(Color(white: 0.22))
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

private enum MarkdownTableAlignment {
    case left
    case center
    case right
}

private struct MarkdownOrderedItem {
    let number: Int
    let text: String
}

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([MarkdownOrderedItem])
    case blockquote([String])
    case codeBlock(language: String?, code: String)
    case horizontalRule
    case table(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
}

private enum NativeMarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0
        var blocks: [MarkdownBlock] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var codeLines: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isTableHeaderLine(trimmed), index + 1 < lines.count, isTableAlignmentLine(lines[index + 1].trimmingCharacters(in: .whitespaces)) {
                let headers = parsePipeRow(trimmed)
                let alignments = parseAlignments(lines[index + 1].trimmingCharacters(in: .whitespaces))
                index += 2
                var rows: [[String]] = []
                while index < lines.count {
                    let rowLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if rowLine.isEmpty || !rowLine.contains("|") {
                        break
                    }
                    rows.append(parsePipeRow(rowLine))
                    index += 1
                }
                blocks.append(.table(headers: headers, alignments: alignments, rows: rows))
                continue
            }

            if isUnorderedListLine(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let item = parseUnorderedListItem(candidate) else { break }
                    items.append(item)
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            if isOrderedListLine(trimmed) {
                var items: [MarkdownOrderedItem] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let item = parseOrderedListItem(candidate) else { break }
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    let stripped = candidate.dropFirst().trimmingCharacters(in: .whitespaces)
                    quoteLines.append(stripped)
                    index += 1
                }
                blocks.append(.blockquote(quoteLines))
                continue
            }

            var paragraphLines: [String] = [trimLeadingWhitespace(line)]
            index += 1
            while index < lines.count {
                let rawCandidate = lines[index]
                let candidate = rawCandidate.trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty || startsNewBlock(candidate, nextLine: index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : nil) {
                    break
                }
                paragraphLines.append(trimLeadingWhitespace(rawCandidate))
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
        }

        return blocks
    }

    private static func startsNewBlock(_ line: String, nextLine: String?) -> Bool {
        if line.hasPrefix("```") || isHorizontalRule(line) || parseHeading(line) != nil || line.hasPrefix(">") {
            return true
        }
        if isUnorderedListLine(line) || isOrderedListLine(line) {
            return true
        }
        if isTableHeaderLine(line), let nextLine, isTableAlignmentLine(nextLine) {
            return true
        }
        return false
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for char in line {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }
        guard (1...6).contains(level) else { return nil }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" } || compact.allSatisfy { $0 == "*" } || compact.allSatisfy { $0 == "_" }
    }

    private static func isUnorderedListLine(_ line: String) -> Bool {
        parseUnorderedListItem(line) != nil
    }

    private static func parseUnorderedListItem(_ line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let first = line.first
        guard first == "-" || first == "*" || first == "+" else { return nil }
        guard line.dropFirst().first == " " else { return nil }
        return String(line.dropFirst(2))
    }

    private static func isOrderedListLine(_ line: String) -> Bool {
        parseOrderedListItem(line) != nil
    }

    private static func parseOrderedListItem(_ line: String) -> MarkdownOrderedItem? {
        var numberText = ""
        var idx = line.startIndex
        while idx < line.endIndex, line[idx].isNumber {
            numberText.append(line[idx])
            idx = line.index(after: idx)
        }
        guard !numberText.isEmpty, idx < line.endIndex else { return nil }
        let sep = line[idx]
        guard sep == "." || sep == ")" else { return nil }
        idx = line.index(after: idx)
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        idx = line.index(after: idx)
        let itemText = String(line[idx...])
        guard let number = Int(numberText) else { return nil }
        return MarkdownOrderedItem(number: number, text: itemText)
    }

    private static func isTableHeaderLine(_ line: String) -> Bool {
        line.contains("|")
    }

    private static func isTableAlignmentLine(_ line: String) -> Bool {
        let cells = parsePipeRow(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.replacingOccurrences(of: " ", with: "")
            guard compact.count >= 3 else { return false }
            return compact.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func parseAlignments(_ line: String) -> [MarkdownTableAlignment] {
        parsePipeRow(line).map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let left = trimmed.hasPrefix(":")
            let right = trimmed.hasSuffix(":")
            switch (left, right) {
            case (true, true): return .center
            case (false, true): return .right
            default: return .left
            }
        }
    }

    private static func parsePipeRow(_ line: String) -> [String] {
        var cleaned = line
        if cleaned.hasPrefix("|") { cleaned.removeFirst() }
        if cleaned.hasSuffix("|") { cleaned.removeLast() }
        return cleaned.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func trimLeadingWhitespace(_ line: String) -> String {
        guard let firstNonWhitespace = line.firstIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        return String(line[firstNonWhitespace...])
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct RulesheetView: View {
    let slug: String
    @StateObject private var viewModel: RulesheetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = false
    @State private var suppressChromeToggle = false

    init(slug: String) {
        self.slug = slug
        _viewModel = StateObject(wrappedValue: RulesheetViewModel(slug: slug))
    }

    var body: some View {
        ZStack {
            AppBackground()

            switch viewModel.status {
            case .idle, .loading:
                Text("Loading rulesheet...")
                    .foregroundStyle(.secondary)
            case .missing:
                Text("Rulesheet not available.")
                    .foregroundStyle(.secondary)
            case .error:
                Text("Could not load rulesheet.")
                    .foregroundStyle(.secondary)
            case .loaded:
                if let markdownText = viewModel.markdownText {
                    MarkdownWebView(
                        markdown: markdownText,
                        onAnchorTap: {
                            suppressChromeToggle = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                suppressChromeToggle = false
                            }
                        }
                    )
                        .ignoresSafeArea()
                }
            }

            if controlsVisible {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.opacity)
            }

        }
        .simultaneousGesture(
            TapGesture().onEnded {
                if suppressChromeToggle { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    controlsVisible.toggle()
                }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 14).onEnded { value in
                guard value.startLocation.x < 28 else { return }
                guard value.translation.width > 80 else { return }
                guard abs(value.translation.height) < 90 else { return }
                dismiss()
            }
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear {
            controlsVisible = false
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

private enum LoadStatus {
    case idle
    case loading
    case loaded
    case missing
    case error
}

private enum PinballLibrarySortOption: String, CaseIterable, Identifiable {
    case location
    case bank
    case alphabetical

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .location:
            return "Sort: Location"
        case .bank:
            return "Sort: Bank"
        case .alphabetical:
            return "Sort: Alphabetical"
        }
    }
}

@MainActor
private final class PinballLibraryViewModel: ObservableObject {
    @Published private(set) var games: [PinballGame] = []
    @Published var query: String = ""
    @Published var sortOption: PinballLibrarySortOption = .location
    @Published var selectedBank: Int?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private var didLoad = false
    private static let libraryPath = "/pinball/data/pinball_library.json"

    var bankOptions: [Int] {
        Array(Set(games.compactMap(\.bank))).sorted()
    }

    var selectedBankLabel: String {
        if let selectedBank {
            return "Bank \(selectedBank)"
        }
        return "All banks"
    }

    var selectedSortLabel: String {
        sortOption.menuLabel
    }

    var filteredGames: [PinballGame] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return games.filter { game in
            let matchesQuery: Bool
            if trimmed.isEmpty {
                matchesQuery = true
            } else {
                let haystack = "\(game.name) \(game.manufacturer ?? "") \(game.year.map(String.init) ?? "")".lowercased()
                matchesQuery = haystack.contains(trimmed)
            }

            let matchesBank = selectedBank == nil || game.bank == selectedBank
            return matchesQuery && matchesBank
        }
    }

    var sortedFilteredGames: [PinballGame] {
        switch sortOption {
        case .location:
            return filteredGames.sorted {
                byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .bank:
            return filteredGames.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .alphabetical:
            return filteredGames.sorted {
                byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? false
            }
        }
    }

    var showGroupedView: Bool {
        selectedBank == nil && (sortOption == .location || sortOption == .bank)
    }

    var sections: [PinballGroupSection] {
        var out: [PinballGroupSection] = []
        let groupingKey: (PinballGame) -> Int? = {
            switch sortOption {
            case .location:
                return { $0.group }
            case .bank:
                return { $0.bank }
            case .alphabetical:
                return { _ in nil }
            }
        }()

        for game in sortedFilteredGames {
            let key = groupingKey(game)
            if let last = out.last, last.groupKey == key {
                var mutable = last
                mutable.games.append(game)
                out[out.count - 1] = mutable
            } else {
                out.append(PinballGroupSection(groupKey: key, games: [game]))
            }
        }

        return out
    }

    private func byOptionalAscending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return byAscending(l, r)
        case (nil, nil):
            return nil
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func byAscending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        if lhs == rhs { return nil }
        return lhs < rhs
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadGames()
    }

    private func loadGames() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.libraryPath)
            guard let text = cached.text,
                  let data = text.data(using: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }

            let decoder = JSONDecoder()
            games = try decoder.decode([PinballGame].self, from: data)
            errorMessage = nil
        } catch {
            games = []
            errorMessage = "Failed to load pinball library: \(error.localizedDescription)"
        }
    }
}

@MainActor
private final class PinballGameInfoViewModel: ObservableObject {
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var markdownText: String?

    private let slug: String
    private var didLoad = false

    init(slug: String) {
        self.slug = slug
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    private func load() async {
        status = .loading
        markdownText = nil

        do {
            let path = "/pinball/gameinfo/\(slug).md"
            let cached = try await PinballDataCache.shared.loadText(path: path, allowMissing: true)
            if cached.isMissing {
                status = .missing
                return
            }
            guard let text = cached.text, !text.isEmpty else {
                status = .missing
                return
            }

            markdownText = text
            status = .loaded
        } catch {
            status = .error
        }
    }
}

@MainActor
private final class RulesheetViewModel: ObservableObject {
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var markdownText: String?

    private let slug: String
    private var didLoad = false

    init(slug: String) {
        self.slug = slug
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    private func load() async {
        status = .loading
        markdownText = nil

        do {
            let path = "/pinball/rulesheets/\(slug).md"
            let cached = try await PinballDataCache.shared.loadText(path: path, allowMissing: true)
            if cached.isMissing {
                status = .missing
                return
            }
            guard let text = cached.text, !text.isEmpty else {
                status = .missing
                return
            }

            markdownText = Self.normalizeRulesheet(text)
            status = .loaded
        } catch {
            status = .error
        }
    }

    private static func normalizeRulesheet(_ input: String) -> String {
        var text = input.replacingOccurrences(of: "\r\n", with: "\n")

        if text.hasPrefix("---\n") {
            let start = text.index(text.startIndex, offsetBy: 4)
            if let endRange = text.range(of: "\n---", range: start..<text.endIndex),
               let after = text[endRange.upperBound...].firstIndex(of: "\n") {
                text = String(text[text.index(after, offsetBy: 1)...])
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    var disableMarkerTracking: Bool = false
    var onAnchorTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(disableMarkerTracking: disableMarkerTracking, onAnchorTap: onAnchorTap)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "codexAnchorTap")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator

        let boundsHeight = webView.bounds.height
        let heightChanged = abs(boundsHeight - context.coordinator.lastKnownHeight) > 1
        context.coordinator.lastKnownHeight = boundsHeight

        guard context.coordinator.lastMarkdown != markdown else {
            if heightChanged && !context.coordinator.disableMarkerTracking {
                context.coordinator.prepareForRestore()
                DispatchQueue.main.async {
                    context.coordinator.restoreScrollPosition(in: webView)
                }
            }
            return
        }

        context.coordinator.lastMarkdown = markdown
        webView.loadHTMLString(
            Self.html(for: markdown, disableMarkerTracking: context.coordinator.disableMarkerTracking),
            baseURL: URL(string: "https://pillyliu.com")
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        let disableMarkerTracking: Bool
        let onAnchorTap: (() -> Void)?
        var lastMarkdown: String?
        var lastKnownHeight: CGFloat = 0
        weak var webView: WKWebView?
        private var restoreToken = 0
        private var lastScrollRatio: CGFloat = 0
        private var pendingRestoreRatio: CGFloat?
        private var orientationObserver: NSObjectProtocol?
        private var orientationRestoreWorkItem: DispatchWorkItem?

        init(disableMarkerTracking: Bool, onAnchorTap: (() -> Void)?) {
            self.disableMarkerTracking = disableMarkerTracking
            self.onAnchorTap = onAnchorTap
            super.init()
            orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if self.disableMarkerTracking { return }
                self.pendingRestoreRatio = self.lastScrollRatio
                self.orientationRestoreWorkItem?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self, let webView = self.webView else { return }
                    self.restoreScrollPosition(in: webView)
                }
                self.orientationRestoreWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if disableMarkerTracking { return }
            updateReadableTopInset(in: webView)
            restoreScrollPosition(in: webView)
        }

        func prepareForRestore() {
        }

        func restoreScrollPosition(in webView: WKWebView) {
            restoreToken += 1
            let token = restoreToken
            let expectedRatio = pendingRestoreRatio ?? lastScrollRatio
            pendingRestoreRatio = nil
            updateReadableTopInset(in: webView)
            let markerRestoreJS = "window.__codexRestoreFromMarkerPoint();"
            webView.evaluateJavaScript("window.__codexSetMarkerTracking(false);", completionHandler: nil)
            webView.evaluateJavaScript(markerRestoreJS, completionHandler: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak webView] in
                guard let self, let webView, token == self.restoreToken else { return }
                webView.evaluateJavaScript(markerRestoreJS, completionHandler: nil)
                self.applyScrollRatioFallbackIfNeeded(in: webView, expectedRatio: expectedRatio)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, token == self.restoreToken, let webView = self.webView else { return }
                webView.evaluateJavaScript(markerRestoreJS, completionHandler: nil)
                self.applyScrollRatioFallbackIfNeeded(in: webView, expectedRatio: expectedRatio)
                webView.evaluateJavaScript("window.__codexSetMarkerTracking(true);", completionHandler: nil)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !disableMarkerTracking else { return }
            let maxScroll = scrollView.contentSize.height - scrollView.bounds.height
            guard maxScroll > 1 else {
                lastScrollRatio = 0
                return
            }
            let ratio = scrollView.contentOffset.y / maxScroll
            lastScrollRatio = min(max(ratio, 0), 1)
        }

        private func updateReadableTopInset(in webView: WKWebView) {
            let measuredInset = measuredTopOverlay(in: webView)
            let readableInset = max(measuredInset, 14)
            let js = "window.__codexSetReadableTopInset(\(readableInset));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func measuredTopOverlay(in webView: WKWebView) -> CGFloat {
            guard
                let window = webView.window,
                let viewController = hostingViewController(from: webView),
                let navController = viewController.navigationController
            else {
                return webView.safeAreaInsets.top
            }

            if navController.isNavigationBarHidden || navController.navigationBar.isHidden || navController.navigationBar.alpha < 0.01 {
                return webView.safeAreaInsets.top
            }

            let navFrame = navController.navigationBar.convert(navController.navigationBar.bounds, to: window)
            let webFrame = webView.convert(webView.bounds, to: window)
            return max(0, navFrame.maxY - webFrame.minY)
        }

        private func hostingViewController(from view: UIView) -> UIViewController? {
            sequence(first: view.next, next: { $0?.next }).first { $0 is UIViewController } as? UIViewController
        }

        private func applyScrollRatioFallbackIfNeeded(in webView: WKWebView, expectedRatio: CGFloat) {
            let currentRatio = currentScrollRatio(in: webView)
            let unexpectedBottomJump = currentRatio > 0.97 && expectedRatio < 0.9
            guard unexpectedBottomJump else { return }

            applyScrollRatio(in: webView, ratio: expectedRatio)
        }

        private func applyScrollRatio(in webView: WKWebView, ratio: CGFloat) {
            let targetRatio = min(max(ratio, 0), 1)
            let scrollView = webView.scrollView
            let maxScroll = scrollView.contentSize.height - scrollView.bounds.height
            guard maxScroll > 1 else { return }
            let targetY = min(max(targetRatio * maxScroll, 0), maxScroll)
            scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
        }

        private func currentScrollRatio(in webView: WKWebView) -> CGFloat {
            let scrollView = webView.scrollView
            let maxScroll = scrollView.contentSize.height - scrollView.bounds.height
            guard maxScroll > 1 else { return 0 }
            return min(max(scrollView.contentOffset.y / maxScroll, 0), 1)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "codexAnchorTap" else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onAnchorTap?()
            }
        }

        deinit {
            orientationRestoreWorkItem?.cancel()
            if let orientationObserver {
                NotificationCenter.default.removeObserver(orientationObserver)
            }
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "codexAnchorTap")
        }

    }
}

private extension MarkdownWebView {
    static func scriptForTopAnchor() -> String {
        """
        function __codexCaretAtPoint(x, y) {
          if (document.caretRangeFromPoint) {
            var range = document.caretRangeFromPoint(x, y);
            if (range) return { node: range.startContainer, offset: range.startOffset };
          } else if (document.caretPositionFromPoint) {
            var pos = document.caretPositionFromPoint(x, y);
            if (pos) return { node: pos.offsetNode, offset: pos.offset };
          }
          return null;
        }

        function __codexFirstTextDesc(node) {
          if (!node) return null;
          if (node.nodeType === Node.TEXT_NODE) return node;
          var walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT, null);
          return walker.nextNode();
        }

        function __codexLastTextDesc(node) {
          if (!node) return null;
          if (node.nodeType === Node.TEXT_NODE) return node;
          var walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT, null);
          var last = null;
          var n;
          while ((n = walker.nextNode())) last = n;
          return last;
        }

        function __codexResolveTextPoint(hit) {
          if (!hit || !hit.node) return null;
          if (hit.node.nodeType === Node.TEXT_NODE) {
            var len = (hit.node.nodeValue || '').length;
            return { node: hit.node, offset: Math.max(0, Math.min(hit.offset || 0, len)) };
          }

          if (hit.node.nodeType !== Node.ELEMENT_NODE) return null;
          var el = hit.node;
          var at = Math.max(0, Math.min(hit.offset || 0, el.childNodes.length));

          var forward = el.childNodes[at] || null;
          var forwardText = __codexFirstTextDesc(forward);
          if (forwardText) {
            return { node: forwardText, offset: 0 };
          }

          if (at > 0) {
            var back = el.childNodes[at - 1];
            var backText = __codexLastTextDesc(back);
            if (backText) {
              return { node: backText, offset: (backText.nodeValue || '').length };
            }
          }

          var next = el.nextSibling;
          while (next) {
            var nextText = __codexFirstTextDesc(next);
            if (nextText) return { node: nextText, offset: 0 };
            next = next.nextSibling;
          }

          return null;
        }

        var __codexReadableInsetPx = null;
        function __codexSetReadableTopInset(px) {
          var v = Number(px);
          __codexReadableInsetPx = Number.isFinite(v) ? Math.max(0, v) : null;
        }

        var __codexMarkerTracking = true;
        function __codexSetMarkerTracking(enabled) {
          __codexMarkerTracking = !!enabled;
        }

        var __codexMarkerPoint = null;

        function __codexPathToNode(node) {
          var path = [];
          var n = node;
          while (n && n !== document.body) {
            var parent = n.parentNode;
            if (!parent) break;
            var idx = 0;
            while (idx < parent.childNodes.length && parent.childNodes[idx] !== n) idx += 1;
            path.push(idx);
            n = parent;
          }
          path.reverse();
          return path;
        }

        function __codexNodeFromPath(path) {
          if (!Array.isArray(path)) return null;
          var n = document.body;
          for (var i = 0; i < path.length; i++) {
            var idx = path[i];
            if (!n || !n.childNodes || idx < 0 || idx >= n.childNodes.length) return null;
            n = n.childNodes[idx];
          }
          return n;
        }

        function __codexTopTextPoint() {
          try {
            var isLandscape = window.innerWidth > window.innerHeight;
            var baseY = __codexReadableTopInset() + (isLandscape ? 22 : 14);
            var xPoints = isLandscape
              ? [
                  Math.floor(window.innerWidth * 0.2),
                  Math.floor(window.innerWidth * 0.35),
                  Math.floor(window.innerWidth * 0.5),
                  Math.floor(window.innerWidth * 0.65),
                  Math.floor(window.innerWidth * 0.8)
                ]
              : [
                  Math.floor(window.innerWidth * 0.16),
                  Math.floor(window.innerWidth * 0.28),
                  Math.floor(window.innerWidth * 0.34),
                  Math.floor(window.innerWidth * 0.5),
                  Math.floor(window.innerWidth * 0.66),
                  Math.floor(window.innerWidth * 0.72),
                  Math.floor(window.innerWidth * 0.84)
                ];
            var bestPoint = null;
            var bestScore = null;
            for (var dy = 0; dy <= 56; dy += 4) {
              var y = baseY + dy;
              for (var i = 0; i < xPoints.length; i++) {
                var hit = __codexCaretAtPoint(xPoints[i], y);
                if (!hit || !hit.node) continue;
                var resolved = __codexResolveTextPoint(hit);
                if (!resolved || !resolved.node) continue;
                var score = dy * 1000 + i;
                if (bestScore === null || score < bestScore) {
                  bestScore = score;
                  bestPoint = resolved;
                }
              }
            }
            return bestPoint;
          } catch (e) {
            return null;
          }
        }

        function __codexPlaceMarker() {
          if (!__codexMarkerTracking) return false;
          try {
            var point = __codexTopTextPoint();
            if (!point || !point.node) return false;
            var range = document.createRange();
            range.setStart(point.node, point.offset);
            range.setEnd(point.node, point.offset);
            var rect = range.getBoundingClientRect();
            if ((!rect || !Number.isFinite(rect.top)) && point.node.parentElement) {
              rect = point.node.parentElement.getBoundingClientRect();
            }
            if (!rect || !Number.isFinite(rect.top)) return false;
            __codexMarkerPoint = {
              path: __codexPathToNode(point.node),
              offset: point.offset || 0,
              topDelta: rect.top - __codexReadableTopInset()
            };
            return true;
          } catch (e) {
            try {
              if (point && point.node && point.node.parentElement) {
                var fallbackRect = point.node.parentElement.getBoundingClientRect();
                if (fallbackRect && Number.isFinite(fallbackRect.top)) {
                  __codexMarkerPoint = {
                    path: __codexPathToNode(point.node),
                    offset: point.offset || 0,
                    topDelta: fallbackRect.top - __codexReadableTopInset()
                  };
                  return true;
                }
              }
            } catch (_) {
            }
          }
          return false;
        }

        function __codexRestoreFromMarkerPoint() {
          try {
            if (!__codexMarkerPoint || !Array.isArray(__codexMarkerPoint.path)) return false;
            var node = __codexNodeFromPath(__codexMarkerPoint.path);
            if (!node) return false;
            var targetNode = node;
            if (targetNode.nodeType !== Node.TEXT_NODE) {
              var textNode = __codexFirstTextDesc(targetNode) || __codexLastTextDesc(targetNode);
              if (textNode) targetNode = textNode;
            }
            if (targetNode.nodeType !== Node.TEXT_NODE) return false;
            var maxOffset = (targetNode.nodeValue || '').length;
            var offset = Math.max(0, Math.min(__codexMarkerPoint.offset || 0, maxOffset));
            var range = document.createRange();
            range.setStart(targetNode, offset);
            range.setEnd(targetNode, offset);
            var rect = range.getBoundingClientRect();
            if ((!rect || !Number.isFinite(rect.top)) && targetNode.parentElement) {
              rect = targetNode.parentElement.getBoundingClientRect();
            }
            if (!rect || !Number.isFinite(rect.top)) return false;
            var inset = __codexReadableTopInset();
            var desiredTop = inset + (Number.isFinite(__codexMarkerPoint.topDelta) ? __codexMarkerPoint.topDelta : 0);
            window.scrollTo(0, Math.max(0, window.scrollY + rect.top - desiredTop));
            return true;
          } catch (e) {}
          return false;
        }

        function __codexReadableTopInset() {
          if (__codexReadableInsetPx !== null) return __codexReadableInsetPx;
          var paddingTop = parseFloat(getComputedStyle(document.body).paddingTop || '14');
          return Math.max(0, paddingTop - 14);
        }

        function __codexScrollToHash(hash) {
          if (!hash) return;
          var id = hash.charAt(0) === '#' ? decodeURIComponent(hash.slice(1)) : decodeURIComponent(hash);
          if (!id) return;
          var el = document.getElementById(id);
          if (!el) return;
          var inset = __codexReadableTopInset();
          var top = window.scrollY + el.getBoundingClientRect().top - inset;
          window.scrollTo(0, Math.max(0, top));
        }

        function __codexBestTextNodeForElement(el) {
          if (!el) return null;
          var text = __codexFirstTextDesc(el) || __codexLastTextDesc(el);
          if (text) return text;
          var p = el.parentElement;
          while (p && p !== document.body) {
            text = __codexFirstTextDesc(p) || __codexLastTextDesc(p);
            if (text) return text;
            p = p.parentElement;
          }
          return null;
        }

        function __codexPlaceMarkerForHash(hash) {
          try {
            if (!hash) return false;
            var id = hash.charAt(0) === '#' ? decodeURIComponent(hash.slice(1)) : decodeURIComponent(hash);
            if (!id) return false;
            var el = document.getElementById(id);
            if (!el) return false;
            var targetNode = __codexBestTextNodeForElement(el);
            if (!targetNode) return false;
            __codexMarkerPoint = {
              path: __codexPathToNode(targetNode),
              offset: 0,
              topDelta: 0
            };
            return true;
          } catch (e) {}
          return false;
        }

        var __codexTicking = false;
        var __codexHashToken = 0;
        function __codexTickPlaceMarker() {
          if (!__codexMarkerTracking) return;
          if (__codexTicking) return;
          __codexTicking = true;
          requestAnimationFrame(function() {
            __codexTicking = false;
            __codexPlaceMarker();
          });
        }

        window.addEventListener('scroll', __codexTickPlaceMarker, { passive: true });
        // Freeze marker updates during orientation/resize; Swift will restore from
        // the last stable marker and re-enable tracking afterward.
        window.addEventListener('orientationchange', function() {
          __codexSetMarkerTracking(false);
        });
        window.addEventListener('resize', function() {
          __codexSetMarkerTracking(false);
        });
        window.addEventListener('hashchange', function() {
          __codexHashToken += 1;
          var token = __codexHashToken;
          __codexSetMarkerTracking(false);
          __codexScrollToHash(location.hash);
          setTimeout(function() {
            if (token !== __codexHashToken) return;
            __codexPlaceMarkerForHash(location.hash);
            __codexSetMarkerTracking(true);
          }, 80);
        });
        function __codexNotifyAnchorTapToNative() {
          try {
            if (
              window.webkit &&
              window.webkit.messageHandlers &&
              window.webkit.messageHandlers.codexAnchorTap
            ) {
              window.webkit.messageHandlers.codexAnchorTap.postMessage('anchor');
            }
          } catch (e) {}
        }
        document.addEventListener('touchstart', function(e) {
          var t = e.target;
          var a = t && t.closest ? t.closest('a[href^="#"]') : null;
          if (a) __codexNotifyAnchorTapToNative();
        }, { passive: true, capture: true });
        document.addEventListener('mousedown', function(e) {
          var t = e.target;
          var a = t && t.closest ? t.closest('a[href^="#"]') : null;
          if (a) __codexNotifyAnchorTapToNative();
        }, { capture: true });
        setTimeout(__codexPlaceMarker, 0);
        """
    }
}

private extension MarkdownWebView {
    static func injectedScript(markdownJSON: String, disableMarkerTracking: Bool) -> String {
        let renderScript = """
            const markdown = \(markdownJSON);
            const container = document.getElementById('content');
            if (!window.markdownit) {
              const fallback = document.createElement('div');
              fallback.className = 'fallback-markdown';
              fallback.textContent = markdown;
              container.appendChild(fallback);
            } else {
              const md = window.markdownit({ html: true, linkify: true, breaks: false });
              container.innerHTML = md.render(markdown);
            }
        """
        if disableMarkerTracking {
            return renderScript
        }
        return """
        \(renderScript)

        \(scriptForTopAnchor())

        if (location.hash) {
          __codexHashToken += 1;
          var token = __codexHashToken;
          __codexSetMarkerTracking(false);
          __codexScrollToHash(location.hash);
          setTimeout(function() {
            if (token !== __codexHashToken) return;
            __codexPlaceMarkerForHash(location.hash);
            __codexSetMarkerTracking(true);
            __codexPlaceMarker();
          }, 80);
        }
        """
    }
}

private extension MarkdownWebView {
    static func html(for markdown: String, disableMarkerTracking: Bool) -> String {
        let markdownJSON = (try? String(data: JSONEncoder().encode(markdown), encoding: .utf8)) ?? "\"\""

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
          <style>
            :root { color-scheme: dark; }
            body {
              margin: 0;
              padding: 14px 18px;
              padding-left: max(18px, calc(env(safe-area-inset-left) + 10px));
              padding-right: max(18px, calc(env(safe-area-inset-right) + 10px));
              padding-top: calc(14px + env(safe-area-inset-top));
              font: -apple-system-body;
              -webkit-text-size-adjust: 100%;
              text-size-adjust: 100%;
              background: transparent;
              color: #f3f3f3;
              line-height: 1.45;
            }
            #content > :first-child { margin-top: 0 !important; }
            a { color: #a6c8ff; text-decoration: underline; }
            code, pre { background: #111; border-radius: 8px; color: #f3f3f3; }
            pre { padding: 10px; overflow-x: auto; }
            .fallback-markdown { white-space: pre-wrap; color: #f3f3f3; }
            table { border-collapse: collapse; width: 100%; overflow-x: auto; display: block; }
            th, td { border: 1px solid #2a2a2a; padding: 6px 8px; }
            img { max-width: 100%; height: auto; }
            hr { border: none; border-top: 1px solid #2a2a2a; }
          </style>
          <script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>
        </head>
        <body>
          <article id="content"></article>
          <script>
        \(injectedScript(markdownJSON: markdownJSON, disableMarkerTracking: disableMarkerTracking))
          </script>
        </body>
        </html>
        """
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
                Color(white: 0.18)
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                if index + 1 < candidates.count {
                    Color(white: 0.18)
                        .task {
                            index += 1
                        }
                } else {
                    Color(white: 0.18)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            @unknown default:
                Color(white: 0.18)
            }
        }
    }
}

private struct FallbackAsyncImageView: View {
    let candidates: [URL]
    let emptyMessage: String?
    @State private var index = 0
    @State private var image: UIImage?
    @State private var didFailCurrent = false

    var body: some View {
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil

        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.12)
                    .overlay {
                        if let emptyMessage, candidates.isEmpty || didFailCurrent {
                            Text(emptyMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: currentURL) {
            guard let currentURL else {
                image = nil
                didFailCurrent = true
                return
            }
            do {
                let data = try await PinballDataCache.shared.loadData(url: currentURL)
                guard let loaded = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                image = loaded
                didFailCurrent = false
            } catch {
                image = nil
                didFailCurrent = true
                if index + 1 < candidates.count {
                    index += 1
                }
            }
        }
    }
}

private struct HostedImageView: View {
    let imageCandidates: [URL]
    @StateObject private var loader = RemoteUIImageLoader()
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = loader.image {
                ZoomableImageScrollView(image: image)
                    .ignoresSafeArea()
            } else if loader.failed {
                VStack(spacing: 8) {
                    Text("Could not load image.")
                        .foregroundStyle(.secondary)
                    if let sourceURL = imageCandidates.first {
                        Link("Open Original URL", destination: sourceURL)
                            .font(.footnote)
                    }
                }
            } else {
                ProgressView()
            }

            if controlsVisible {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                withAnimation(.easeInOut(duration: 0.18)) {
                    controlsVisible.toggle()
                }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 14).onEnded { value in
                guard value.startLocation.x < 28 else { return }
                guard value.translation.width > 80 else { return }
                guard abs(value.translation.height) < 90 else { return }
                dismiss()
            }
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(true)
        .onAppear {
            controlsVisible = false
        }
        .task {
            await loader.loadIfNeeded(from: imageCandidates)
        }
    }

}

@MainActor
private final class RemoteUIImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false

    private var didLoad = false

    func loadIfNeeded(from urls: [URL]) async {
        guard !didLoad else { return }
        didLoad = true

        for url in urls {
            do {
                let data = try await PinballDataCache.shared.loadData(url: url)
                guard let uiImage = UIImage(data: data) else {
                    continue
                }

                image = uiImage
                failed = false
                return
            } catch {
                continue
            }
        }

        failed = true
    }
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 8
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.imageView?.frame = uiView.bounds
        uiView.contentSize = uiView.bounds.size
        uiView.minimumZoomScale = 1
        uiView.setZoomScale(uiView.minimumZoomScale, animated: false)
        context.coordinator.centerImage(in: uiView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        func centerImage(in scrollView: UIScrollView) {
            let boundsSize = scrollView.bounds.size
            let contentSize = scrollView.contentSize

            let horizontalInset = max(0, (boundsSize.width - contentSize.width) / 2)
            let verticalInset = max(0, (boundsSize.height - contentSize.height) / 2)

            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}

private struct PinballGroupSection {
    let groupKey: Int?
    var games: [PinballGame]
}

private struct PinballGame: Identifiable, Decodable {
    struct PlayableVideo: Identifiable {
        let id: String
        let label: String

        var thumbnailCandidates: [URL] {
            [
                URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"),
                URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg"),
                URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg"),
                URL(string: "https://img.youtube.com/vi/\(id)/0.jpg")
            ].compactMap { $0 }
        }
    }

    struct Video: Identifiable, Decodable {
        let kind: String?
        let label: String?
        let url: String?

        var id: String {
            [kind ?? "", label ?? "", url ?? UUID().uuidString].joined(separator: "|")
        }
    }

    let group: Int?
    let pos: Int?
    let bank: Int?
    let name: String
    let manufacturer: String?
    let year: Int?
    let slug: String
    let playfieldImageUrl: String?
    let playfieldLocal: String?
    let rulesheetUrl: String?
    let rulesheetLocal: String?
    let videos: [Video]

    var id: String { slug }

    var metaLine: String {
        var parts: [String] = []

        parts.append(manufacturer ?? "-")

        if let year {
            parts.append(String(year))
        }

        if let locationText {
            parts.append(locationText)
        }

        if let bank, bank > 0 {
            parts.append("Bank \(bank)")
        }

        return parts.joined(separator: " • ")
    }

    var manufacturerYearLine: String {
        let maker = manufacturer ?? "-"
        if let year {
            return "\(maker) • \(year)"
        }
        return maker
    }

    var locationBankLine: String {
        var parts: [String] = []
        if let locationText {
            parts.append(locationText)
        }
        if let bank, bank > 0 {
            parts.append("Bank \(bank)")
        }
        return parts.isEmpty ? "-" : parts.joined(separator: " • ")
    }

    var locationText: String? {
        guard let group, let pos else { return nil }
        let floor = (1...4).contains(group) ? "U" : "D"
        return "\(floor):\(group):\(pos)"
    }

    var playfieldLocalURL: URL? {
        guard let playfieldLocal else { return nil }
        return Self.resolveURL(pathOrURL: playfieldLocal)
    }

    var libraryPlayfieldCandidates: [URL] {
        [derivedPlayfieldURL(width: 700), playfieldLocalURL].compactMap { $0 }
    }

    var gamePlayfieldCandidates: [URL] {
        [derivedPlayfieldURL(width: 1400), playfieldLocalURL, derivedPlayfieldURL(width: 700)].compactMap { $0 }
    }

    var fullscreenPlayfieldCandidates: [URL] {
        [playfieldLocalURL, derivedPlayfieldURL(width: 1400), derivedPlayfieldURL(width: 700)].compactMap { $0 }
    }

    var playfieldImageSourceURL: URL? {
        guard let playfieldImageUrl else { return nil }
        return URL(string: playfieldImageUrl)
    }

    var rulesheetSourceURL: URL? {
        guard let rulesheetUrl else { return nil }
        return URL(string: rulesheetUrl)
    }

    private static func resolveURL(pathOrURL: String) -> URL? {
        if let direct = URL(string: pathOrURL), direct.scheme != nil {
            return direct
        }

        if pathOrURL.hasPrefix("/") {
            return URL(string: "https://pillyliu.com\(pathOrURL)")
        }

        return URL(string: "https://pillyliu.com/\(pathOrURL)")
    }

    private func derivedPlayfieldURL(width: Int) -> URL? {
        guard let playfieldLocal else { return nil }

        let normalizedPath: String
        if let url = URL(string: playfieldLocal), url.scheme != nil {
            normalizedPath = url.path
        } else {
            normalizedPath = playfieldLocal
        }

        guard let slashIndex = normalizedPath.lastIndex(of: "/") else { return nil }
        let directory = String(normalizedPath[..<slashIndex])
        let derived = "\(directory)/\(slug)_\(width).webp"
        return Self.resolveURL(pathOrURL: derived)
    }

    static func youtubeWatchURL(from raw: String) -> URL? {
        guard let id = youtubeID(from: raw) else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(id)")
    }

    static func youtubeID(from raw: String) -> String? {
        guard let url = URL(string: raw),
              let host = url.host?.lowercased() else {
            return nil
        }

        if host.contains("youtu.be") {
            let id = url.path.replacingOccurrences(of: "/", with: "")
            guard !id.isEmpty else { return nil }
            return id
        }

        if host.contains("youtube.com"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let id = queryItems.first(where: { $0.name == "v" })?.value,
           !id.isEmpty {
            return id
        }

        return nil
    }
}
