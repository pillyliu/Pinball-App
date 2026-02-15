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
    let scalars = Array(text.unicodeScalars)
    var index = 0

    func flushRow() {
        row.append(field)
        rows.append(row)
        row = []
        field = ""
    }

    while index < scalars.count {
        let scalar = scalars[index]
        if inQuotes {
            if scalar.value == 34 {
                if index + 1 < scalars.count, scalars[index + 1].value == 34 {
                    field.append("\"")
                    index += 1
                } else {
                    inQuotes = false
                }
            } else {
                field.unicodeScalars.append(scalar)
            }
        } else {
            switch scalar.value {
            case 34: // "\""
                inQuotes = true
            case 44: // ","
                row.append(field)
                field = ""
            case 10: // LF
                flushRow()
            case 13: // CR
                flushRow()
                if index + 1 < scalars.count, scalars[index + 1].value == 10 {
                    index += 1
                }
            default:
                field.unicodeScalars.append(scalar)
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
        .replacingOccurrences(of: "\0", with: "")
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
    let decomposed = raw.decomposedStringWithCanonicalMapping
    let withoutDiacritics = String(
        decomposed.unicodeScalars.filter { !$0.properties.isDiacritic }
    )
    return withoutDiacritics
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased(with: Locale(identifier: "en_US_POSIX"))
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
