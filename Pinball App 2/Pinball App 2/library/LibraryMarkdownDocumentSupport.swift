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

struct MarkdownBlockFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
