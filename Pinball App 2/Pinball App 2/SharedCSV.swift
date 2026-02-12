import Foundation
import CryptoKit

private let redactionTokenSalt = "pinball-app-redaction-v1"
private let redactedPlayersCSVPath = "/pinball/data/redacted_players.csv"

private final class RedactedPlayerStore: @unchecked Sendable {
    private let lock = NSLock()
    private var names: Set<String> = []

    func replace(with newNames: Set<String>) {
        lock.lock()
        names = newNames
        lock.unlock()
    }

    func contains(_ normalizedName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return names.contains(normalizedName)
    }
}

private let redactedPlayerStore = RedactedPlayerStore()

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

func redactPlayerNameForDisplay(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard shouldRedactPlayerName(trimmed) else { return trimmed }
    return "Redacted \(redactionToken(for: trimmed))"
}

func refreshRedactedPlayersFromCSV() async {
    do {
        let result = try await PinballDataCache.shared.loadText(path: redactedPlayersCSVPath, allowMissing: true)
        let parsed = parseRedactedPlayersCSV(result.text)
        redactedPlayerStore.replace(with: parsed)
    } catch {
        // Keep prior values if CSV cannot be refreshed.
    }
}

private func shouldRedactPlayerName(_ raw: String) -> Bool {
    let normalized = normalizePlayerName(raw)
    guard !normalized.isEmpty else { return false }
    return redactedPlayerStore.contains(normalized)
}

private func normalizePlayerName(_ raw: String) -> String {
    raw
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

private func redactionToken(for raw: String) -> String {
    let normalized = normalizePlayerName(raw)
    let input = Data("\(redactionTokenSalt):\(normalized)".utf8)
    let digest = SHA256.hash(data: input)
    let prefix = digest.prefix(3)
    return prefix.map { String(format: "%02X", $0) }.joined()
}

private func parseRedactedPlayersCSV(_ text: String?) -> Set<String> {
    guard let text, !text.isEmpty else { return [] }
    let rows = parseCSVRows(text)
    guard !rows.isEmpty else { return [] }

    let header = rows[0].map { normalizeCSVHeader($0) }
    let hasHeader = header.contains("name") || header.contains("player") || header.contains("player_name")
    let nameIndex = header.firstIndex(of: "name")
        ?? header.firstIndex(of: "player")
        ?? header.firstIndex(of: "player_name")
        ?? 0
    let dataRows: ArraySlice<[String]> = hasHeader ? rows.dropFirst() : rows[...]

    return Set(
        dataRows.compactMap { row -> String? in
            guard nameIndex < row.count else { return nil }
            let normalized = normalizePlayerName(row[nameIndex])
            return normalized.isEmpty ? nil : normalized
        }
    )
}
