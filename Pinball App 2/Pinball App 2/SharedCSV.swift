import Foundation

func parseCSVRows(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var inQuotes = false
    let chars = Array(text)
    var index = 0

    while index < chars.count {
        let char = chars[index]
        if inQuotes {
            if char == "\"" {
                if index + 1 < chars.count, chars[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    inQuotes = false
                }
            } else {
                field.append(char)
            }
        } else {
            switch char {
            case "\"":
                inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\n":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            case "\r":
                break
            default:
                field.append(char)
            }
        }
        index += 1
    }

    if !field.isEmpty || !row.isEmpty {
        row.append(field)
        rows.append(row)
    }

    return rows
}

func normalizeCSVHeader(_ header: String) -> String {
    header
        .replacingOccurrences(of: "\u{FEFF}", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

func coerceSeasonNumber(_ value: String) -> Int {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.filter(\.isNumber)
    if let number = Int(digits), number > 0 {
        return number
    }
    return Int(trimmed) ?? 0
}

func normalizeSeasonToken(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.filter(\.isNumber)
    return digits.isEmpty ? trimmed : digits
}
