import Foundation

extension NativeMarkdownParser {
    static func parseHTMLTable(
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

    static func parseHTMLTableHTML(_ html: String) -> MarkdownBlock? {
        let rowHTML = html.regexMatches(
            pattern: #"<tr\b[^>]*>(.*?)</tr>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        guard !rowHTML.isEmpty else { return nil }

        var headerRow: [String]?
        var rows: [[String]] = []

        for row in rowHTML {
            let cells = row.regexMatches(
                pattern: #"<t[dh]\b[^>]*>(.*?)</t[dh]>"#,
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

    static func padCells(_ cells: [String], to count: Int) -> [String] {
        guard cells.count < count else { return cells }
        return cells + Array(repeating: "", count: count - cells.count)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
