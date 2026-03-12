import Foundation

enum MarkdownTableAlignment {
    case left
    case center
    case right
}

struct MarkdownOrderedItem {
    let number: Int
    let text: String
}

enum MarkdownBlock {
    case anchor(String)
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([MarkdownOrderedItem])
    case blockquote([String])
    case codeBlock(language: String?, code: String)
    case horizontalRule
    case image(url: String, alt: String?)
    case table(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
}

enum NativeMarkdownParser {
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

            if shouldSkipRawHTMLLine(trimmed) {
                index += 1
                continue
            }

            if let anchorID = parseAnchorID(trimmed) {
                blocks.append(.anchor(anchorID))
                index += 1
                continue
            }

            if let htmlTable = parseHTMLTable(startingAt: index, in: lines) {
                blocks.append(htmlTable.block)
                index = htmlTable.nextIndex
                continue
            }

            if let image = parseStandaloneImage(trimmed) {
                blocks.append(.image(url: image.url, alt: image.alt))
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

    private static func shouldSkipRawHTMLLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "<div class=\"pinball-rulesheet\">" ||
            trimmed == "<div class='pinball-rulesheet'>" ||
            trimmed == "</div>"
    }

    private static func parseAnchorID(_ line: String) -> String? {
        line.firstRegexCapture(#"<a\s+id=['"]([^'"]+)['"]\s*>\s*</a>"#)
    }

    private static func parseStandaloneImage(_ line: String) -> (url: String, alt: String?)? {
        if let markdownMatch = line.firstRegexCaptures(#"!\[([^\]]*)\]\(([^)]+)\)"#, options: .caseInsensitive),
           let url = markdownMatch.1 {
            return (url: url, alt: markdownMatch.0.isEmpty ? nil : markdownMatch.0)
        }

        if let imageMatch = line.firstRegexCaptures(#"<img\b[^>]*src=['"]([^'"]+)['"][^>]*?(?:alt=['"]([^'"]*)['"])?[^>]*?/?>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            return (url: imageMatch.0, alt: imageMatch.1?.isEmpty == true ? nil : imageMatch.1)
        }

        return nil
    }

    private static func parseHTMLTable(
        startingAt startIndex: Int,
        in lines: [String]
    ) -> (block: MarkdownBlock, nextIndex: Int)? {
        let startLine = lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard startLine.contains("<table") || startLine == "<div class=\"md-table\">" || startLine == "<div class='md-table'>" else {
            return nil
        }

        var collected: [String] = []
        var index = startIndex
        var foundTable = startLine.contains("<table")
        var foundClosingTable = false

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            if !foundTable && lowercased.contains("<table") {
                foundTable = true
            }

            collected.append(rawLine)

            if foundTable && lowercased.contains("</table>") {
                foundClosingTable = true
                index += 1
                while index < lines.count {
                    let trailing = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if trailing == "</div>" {
                        collected.append(lines[index])
                        index += 1
                        continue
                    }
                    break
                }
                break
            }

            if !foundTable && trimmed.isEmpty {
                return nil
            }

            index += 1
        }

        guard foundTable, foundClosingTable else { return nil }
        let html = collected.joined(separator: "\n")
        guard let table = parseHTMLTableHTML(html) else { return nil }
        return (table, index)
    }

    private static func parseHTMLTableHTML(_ html: String) -> MarkdownBlock? {
        let rowHTML = regexMatches(
            pattern: #"<tr\b[^>]*>(.*?)</tr>"#,
            in: html,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        guard !rowHTML.isEmpty else { return nil }

        var headerRow: [String]?
        var rows: [[String]] = []

        for row in rowHTML {
            let cells = regexMatches(
                pattern: #"<t[dh]\b[^>]*>(.*?)</t[dh]>"#,
                in: row,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
            guard !cells.isEmpty else { continue }

            let isHeaderRow = row.range(of: "<th", options: .caseInsensitive) != nil
            if isHeaderRow && headerRow == nil {
                headerRow = cells
            } else {
                rows.append(cells)
            }
        }

        if headerRow == nil, let firstRow = rows.first {
            headerRow = firstRow
            rows.removeFirst()
        }

        guard let headerRow, !headerRow.isEmpty else { return nil }
        let columnCount = max(headerRow.count, rows.map(\.count).max() ?? 0)
        let paddedHeaders = padCells(headerRow, to: columnCount)
        let paddedRows = rows.map { padCells($0, to: columnCount) }
        let alignments = Array(repeating: MarkdownTableAlignment.left, count: columnCount)
        return .table(headers: paddedHeaders, alignments: alignments, rows: paddedRows)
    }

    private static func padCells(_ cells: [String], to count: Int) -> [String] {
        guard cells.count < count else { return cells }
        return cells + Array(repeating: "", count: count - cells.count)
    }

    private static func regexMatches(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[captureRange])
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    func firstRegexCapture(_ pattern: String, options: NSRegularExpression.Options = []) -> String? {
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
}
