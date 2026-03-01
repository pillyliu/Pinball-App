import SwiftUI

struct NativeMarkdownView: View {
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
