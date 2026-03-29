import Foundation

extension RemoteRulesheetLoader {
    static func cleanupPrimerHTML(_ html: String) -> String {
        let body = extractBodyHTML(from: html) ?? html
        var cleaned = stripHTML(body, patterns: [
            #"(?is)<iframe\b[^>]*>.*?</iframe>"#,
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<!--.*?-->"#
        ])
        if let firstHeadingRange = cleaned.range(of: #"(?is)<h1\b[^>]*>"#, options: .regularExpression) {
            cleaned = String(cleaned[firstHeadingRange.lowerBound...])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanupLegacyHTML(_ html: String, mimeType: String?, source: RulesheetRemoteSource) -> String {
        if shouldTreatAsPlainText(html: html, mimeType: mimeType) {
            return "<pre class=\"rulesheet-preformatted\">\(html.htmlEscaped)</pre>"
        }

        if source.provider == .bob, let main = extractMainHTML(from: html) {
            let cleanedMain = stripHTML(main, patterns: [
                #"(?is)<script\b[^>]*>.*?</script>"#,
                #"(?is)<!--.*?-->"#,
                #"(?is)<a\b[^>]*title="Print"[^>]*>.*?</a>"#
            ])
            return cleanedMain.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let body = extractBodyHTML(from: html) ?? html
        let cleaned = stripHTML(body, patterns: [
            #"(?is)<\?.*?\?>"#,
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<iframe\b[^>]*>.*?</iframe>"#,
            #"(?is)<!--.*?-->"#,
            #"(?is)</?(html|head|body|meta|link)\b[^>]*>"#
        ])
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func shouldTreatAsPlainText(html: String, mimeType: String?) -> Bool {
        if mimeType?.localizedCaseInsensitiveContains("text/plain") == true {
            return true
        }
        let tagMatch = html.range(of: #"<[a-zA-Z!/][^>]*>"#, options: .regularExpression)
        return tagMatch == nil
    }

    static func extractMainHTML(from html: String) -> String? {
        html.firstRegexCapture(#"(?is)<main\b[^>]*>(.*?)</main>"#)
    }

    static func extractBodyHTML(from html: String) -> String? {
        html.firstRegexCapture(#"(?is)<body\b[^>]*>(.*?)</body>"#)
    }

    static func stripHTML(_ html: String, patterns: [String]) -> String {
        patterns.reduce(html) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }
}
