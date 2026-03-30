import Foundation

enum StandingsCSVLoader {
    static let defaultPath = hostedLeagueStandingsPath

    static func parse(text: String) throws -> [StandingsCSVRow] {
        let table = parseCSVRows(text)
        guard !table.isEmpty else { return [] }

        let headers = table[0].map { normalizeCSVHeader($0) }
        let required = [
            "season", "player", "total", "bank_1", "bank_2", "bank_3", "bank_4",
            "bank_5", "bank_6", "bank_7", "bank_8"
        ]

        for name in required where !headers.contains(name) {
            throw StandingsCSVError.missingColumn(name)
        }

        return table.dropFirst().compactMap { row in
            guard row.count == headers.count else { return nil }

            let dict = Dictionary(uniqueKeysWithValues: zip(headers, row))

            let season = coerceSeasonNumber(dict["season"] ?? "")
            let player = (dict["player"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let total = Double(dict["total"] ?? "") ?? 0
            let rank = Int((dict["rank"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            let eligible = (dict["eligible"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let nights = (dict["nights"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let banks = (1...8).map { index in
                Double(dict["bank_\(index)"] ?? "") ?? 0
            }

            guard season > 0, !player.isEmpty else { return nil }

            return StandingsCSVRow(
                season: season,
                player: player,
                total: total,
                rank: rank,
                eligible: eligible,
                nights: nights,
                banks: banks
            )
        }
    }
}

enum StandingsCSVError: LocalizedError {
    case missingColumn(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingColumn(let column):
            return "Standings CSV missing column: \(column)"
        case .network(let message):
            return message
        }
    }
}

func formatStandingsRounded(_ value: Double) -> String {
    Int(value.rounded()).formatted()
}
