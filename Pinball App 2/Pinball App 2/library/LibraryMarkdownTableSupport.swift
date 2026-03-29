import SwiftUI

struct MarkdownTableView: View {
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
