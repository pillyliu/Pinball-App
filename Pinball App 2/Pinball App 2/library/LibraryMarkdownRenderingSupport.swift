import SwiftUI

struct NativeMarkdownBlockView: View {
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
            MarkdownInlineText(raw: text, baseFont: markdownHeadingFont(level), textColor: .primary)
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
}
