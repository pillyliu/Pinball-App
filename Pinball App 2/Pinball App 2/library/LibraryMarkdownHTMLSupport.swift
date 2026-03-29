import Foundation

enum MarkdownHTMLSanitizer {
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
