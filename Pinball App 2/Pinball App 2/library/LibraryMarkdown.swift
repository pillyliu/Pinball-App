import SwiftUI

struct NativeMarkdownDocumentBlock: Identifiable {
    let id: String
    let anchorID: String?
    let block: MarkdownBlock
}

enum NativeMarkdownDocumentBuilder {
    static func build(from markdown: String) -> [NativeMarkdownDocumentBlock] {
        let parsedBlocks = NativeMarkdownParser.parse(markdown)
        var pendingAnchorID: String?
        var blocks: [NativeMarkdownDocumentBlock] = []
        var blockIndex = 0

        for block in parsedBlocks {
            switch block {
            case .anchor(let anchorID):
                pendingAnchorID = anchorID
            case .heading(let level, let rawText):
                let cleanedText = MarkdownHTMLSanitizer.plainText(rawText)
                let normalizedBlock = MarkdownBlock.heading(level: level, text: cleanedText)
                let resolvedAnchorID = pendingAnchorID ?? embeddedAnchorID(in: rawText) ?? inferredAnchorID(for: normalizedBlock)
                blocks.append(
                    NativeMarkdownDocumentBlock(
                        id: resolvedAnchorID ?? "markdown-block-\(blockIndex)",
                        anchorID: resolvedAnchorID,
                        block: normalizedBlock
                    )
                )
                pendingAnchorID = nil
                blockIndex += 1
            default:
                let resolvedAnchorID = pendingAnchorID ?? inferredAnchorID(for: block)
                blocks.append(
                    NativeMarkdownDocumentBlock(
                        id: resolvedAnchorID ?? "markdown-block-\(blockIndex)",
                        anchorID: resolvedAnchorID,
                        block: block
                    )
                )
                pendingAnchorID = nil
                blockIndex += 1
            }
        }

        return blocks
    }

    private static func inferredAnchorID(for block: MarkdownBlock) -> String? {
        guard case .heading(_, let text) = block else { return nil }
        let slug = text
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? nil : "heading--\(slug)"
    }

    private static func embeddedAnchorID(in text: String) -> String? {
        text.firstRegexCapture(
            #"<(?:span|a)\b[^>]*id=['"]([^'"]+)['"][^>]*>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    }
}

struct NativeMarkdownView: View {
    let markdown: String
    var baseURL: URL? = nil

    private var blocks: [NativeMarkdownDocumentBlock] {
        NativeMarkdownDocumentBuilder.build(from: markdown)
    }

    var body: some View {
        NativeMarkdownDocumentView(blocks: blocks, baseURL: baseURL)
    }
}

struct NativeMarkdownDocumentView: View {
    let blocks: [NativeMarkdownDocumentBlock]
    var baseURL: URL? = nil
    var onBlockFramesChange: (([String: CGRect]) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                NativeMarkdownBlockView(block: block, baseURL: baseURL)
                    .id(block.id)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MarkdownBlockFramePreferenceKey.self,
                                value: [block.id: proxy.frame(in: .named(Self.coordinateSpaceName))]
                            )
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .onPreferenceChange(MarkdownBlockFramePreferenceKey.self) { frames in
            onBlockFramesChange?(frames)
        }
    }

    static let coordinateSpaceName = "NativeMarkdownDocumentView"
}

private struct NativeMarkdownBlockView: View {
    let block: NativeMarkdownDocumentBlock
    let baseURL: URL?

    var body: some View {
        blockView(block.block)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .anchor:
            EmptyView()
        case .heading(let level, let text):
            MarkdownInlineText(raw: text, baseFont: headingFont(level), textColor: .primary)
                .fontWeight(.semibold)
                .padding(.top, level <= 2 ? 4 : 2)
        case .paragraph(let text):
            if let image = MarkdownImageDescriptor.first(in: text), MarkdownHTMLSanitizer.strippedText(text).isEmpty {
                NativeMarkdownRemoteImage(descriptor: image, baseURL: baseURL)
            } else {
                MarkdownInlineText(raw: text, baseFont: .body, textColor: .primary)
            }
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
        case .image(let url, let alt):
            NativeMarkdownRemoteImage(
                descriptor: MarkdownImageDescriptor(urlString: url, alt: alt),
                baseURL: baseURL
            )
        case .table(let headers, let alignments, let rows):
            MarkdownTableView(headers: headers, alignments: alignments, rows: rows, baseURL: baseURL)
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
        let sanitized = MarkdownHTMLSanitizer.inlineMarkdown(from: raw)
        if let attributed = parsed(from: sanitized) {
            Text(attributed)
                .font(baseFont)
                .foregroundStyle(textColor)
                .tint(AppTheme.rulesheetLink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(MarkdownHTMLSanitizer.strippedText(raw))
                .font(baseFont)
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func parsed(from text: String) -> AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return try? AttributedString(markdown: text, options: options)
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let alignments: [MarkdownTableAlignment]
    let rows: [[String]]
    let baseURL: URL?

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
        let image = MarkdownImageDescriptor.first(in: text)
        Group {
            if let image, MarkdownHTMLSanitizer.strippedText(text).isEmpty {
                NativeMarkdownRemoteImage(descriptor: image, baseURL: baseURL, minHeight: 150)
            } else {
                MarkdownInlineText(
                    raw: text,
                    baseFont: isHeader ? .subheadline : .footnote,
                    textColor: .primary
                )
            }
        }
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

private struct NativeMarkdownRemoteImage: View {
    let descriptor: MarkdownImageDescriptor
    let baseURL: URL?
    var minHeight: CGFloat = 220

    var body: some View {
        if let url = descriptor.resolvedURL(relativeTo: baseURL) {
            FallbackAsyncImageView(
                candidates: [url],
                emptyMessage: descriptor.alt ?? "Image unavailable",
                contentMode: .fit
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
            )
        } else if let alt = descriptor.alt, !alt.isEmpty {
            Text(alt)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MarkdownImageDescriptor {
    let urlString: String
    let alt: String?

    func resolvedURL(relativeTo baseURL: URL?) -> URL? {
        guard !urlString.hasPrefix("data:") else { return nil }
        if urlString.hasPrefix("//") {
            return URL(string: "https:\(urlString)")
        }
        if let absolute = URL(string: urlString), absolute.scheme != nil {
            return absolute
        }
        if let baseURL {
            return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
        }
        return URL(string: urlString)
    }

    static func first(in raw: String) -> MarkdownImageDescriptor? {
        if let markdownImage = raw.firstRegexMatch(#"!\[([^\]]*)\]\(([^)]+)\)"#),
           let urlString = markdownImage.second {
            return MarkdownImageDescriptor(
                urlString: urlString,
                alt: markdownImage.first.isEmpty ? nil : markdownImage.first
            )
        }

        if let htmlImage = raw.firstRegexMatch(#"<img\b[^>]*src=['"]([^'"]+)['"][^>]*?(?:alt=['"]([^'"]*)['"])?[^>]*?/?>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            return MarkdownImageDescriptor(
                urlString: htmlImage.first,
                alt: htmlImage.second?.isEmpty == true ? nil : htmlImage.second
            )
        }

        return nil
    }
}

private enum MarkdownHTMLSanitizer {
    static func inlineMarkdown(from raw: String) -> String {
        var text = raw

        text = text.replacingOccurrences(
            of: #"<a\b[^>]*href=['"]([^'"]+)['"][^>]*>(.*?)</a>"#,
            with: { captures in
                let href = captures[safe: 0] ?? ""
                let label = strippedText(captures[safe: 1] ?? href)
                return label.isEmpty ? href : "[\(label)](\(href))"
            },
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        text = text.replacingOccurrences(
            of: #"</?(small|div|span|strong|em|p|br)\b[^>]*>"#,
            with: "\n",
            options: [.caseInsensitive, .regularExpression]
        )
        text = text.replacingOccurrences(
            of: #"</?(td|th|tr|tbody|thead|table)\b[^>]*>"#,
            with: " ",
            options: [.caseInsensitive, .regularExpression]
        )
        text = text.replacingOccurrences(
            of: #"<img\b[^>]*>"#,
            with: "",
            options: [.caseInsensitive, .regularExpression]
        )
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )

        return text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func strippedText(_ raw: String) -> String {
        inlineMarkdown(from: raw)
            .replacingOccurrences(of: #"\[[^\]]+\]\(([^)]+)\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func plainText(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct MarkdownBlockFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension String {
    func firstRegexCapture(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: self, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: self) else {
            return nil
        }

        return String(self[captureRange])
    }

    func firstRegexMatch(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> (first: String, second: String?)? {
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: self, options: [], range: range),
              match.numberOfRanges >= 2,
              let firstRange = Range(match.range(at: 1), in: self) else {
            return nil
        }

        let first = String(self[firstRange])
        let second: String?
        if match.numberOfRanges >= 3,
           let secondRange = Range(match.range(at: 2), in: self) {
            second = String(self[secondRange])
        } else {
            second = nil
        }
        return (first, second)
    }

    func replacingOccurrences(
        of pattern: String,
        with transform: ([String]) -> String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return self
        }

        let matches = regex.matches(in: self, options: [], range: NSRange(startIndex..<endIndex, in: self))
        guard !matches.isEmpty else { return self }

        var result = self
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result) else { continue }
            var captures: [String] = []
            for index in 1..<match.numberOfRanges {
                if let captureRange = Range(match.range(at: index), in: result) {
                    captures.append(String(result[captureRange]))
                } else {
                    captures.append("")
                }
            }
            result.replaceSubrange(fullRange, with: transform(captures))
        }
        return result
    }
}
