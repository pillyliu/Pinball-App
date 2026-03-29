import SwiftUI

func markdownHeadingFont(_ level: Int) -> Font {
    switch level {
    case 1: return .title2
    case 2: return .title3
    case 3: return .headline
    default: return .subheadline
    }
}

struct MarkdownInlineText: View {
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
