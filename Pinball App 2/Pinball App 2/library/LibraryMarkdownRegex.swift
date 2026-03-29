import Foundation

struct MarkdownImageMatch {
    let url: String
    let alt: String?
}

enum MarkdownImageParsing {
    static func firstImage(in raw: String) -> MarkdownImageMatch? {
        if let markdownImage = raw.firstRegexMatch(#"!\[([^\]]*)\]\(([^)]+)\)"#),
           let url = markdownImage.second {
            return MarkdownImageMatch(
                url: url,
                alt: markdownImage.first.isEmpty ? nil : markdownImage.first
            )
        }

        if let htmlImage = raw.firstRegexMatch(
            #"<img\b[^>]*src=['"]([^'"]+)['"][^>]*?(?:alt=['"]([^'"]*)['"])?[^>]*?/?>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            return MarkdownImageMatch(
                url: htmlImage.first,
                alt: htmlImage.second?.isEmpty == true ? nil : htmlImage.second
            )
        }

        return nil
    }
}

extension String {
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

    func firstRegexCaptures(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> (String, String?)? {
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

    func firstRegexMatch(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> (first: String, second: String?)? {
        guard let captures = firstRegexCaptures(pattern, options: options) else {
            return nil
        }
        return (first: captures.0, second: captures.1)
    }

    func regexMatches(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: self) else {
                return nil
            }
            return String(self[captureRange])
        }
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
