import Foundation

final class StatsCSVLoader {
    struct LoadResult {
        let rows: [ScoreRow]
        let updatedAt: Date?
    }

    static let defaultPath = hostedLeagueStatsPath

    func loadRows() async throws -> LoadResult {
        let cached = try await PinballDataCache.shared.loadText(path: Self.defaultPath)
        guard let text = cached.text else {
            throw StatsCSVLoaderError.network("Stats CSV is missing from cache and server.")
        }
        return LoadResult(rows: parse(text: text), updatedAt: cached.updatedAt)
    }

    func forceRefreshRows() async throws -> LoadResult {
        let fresh = try await PinballDataCache.shared.forceRefreshText(path: Self.defaultPath)
        guard let text = fresh.text else {
            throw StatsCSVLoaderError.network("Stats CSV is missing from cache and server.")
        }
        return LoadResult(rows: parse(text: text), updatedAt: fresh.updatedAt)
    }

    private func parse(text: String) -> [ScoreRow] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }
        let headers = header.map(normalizeCSVHeader)

        func idx(_ name: String) -> Int {
            headers.firstIndex(of: normalizeCSVHeader(name)) ?? -1
        }

        let seasonIndex = idx("Season")
        let bankNumberIndex = idx("BankNumber")
        let playerIndex = idx("Player")
        let machineIndex = idx("Machine")
        let rawScoreIndex = idx("RawScore")
        let pointsIndex = idx("Points")

        guard [seasonIndex, bankNumberIndex, playerIndex, machineIndex, rawScoreIndex, pointsIndex].allSatisfy({ $0 >= 0 }) else {
            return []
        }

        return table.dropFirst().enumerated().compactMap { offset, columns in
            let requiredIndexes = [
                seasonIndex, bankNumberIndex, playerIndex, machineIndex, rawScoreIndex, pointsIndex
            ]
            guard requiredIndexes.allSatisfy({ columns.indices.contains($0) }) else { return nil }

            let season = normalizeSeasonToken(columns[seasonIndex])
            let bankNumber = Int(columns[bankNumberIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let player = columns[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let machine = columns[machineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawScore = Double(columns[rawScoreIndex].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")) ?? 0
            let points = Double(columns[pointsIndex].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")) ?? 0

            return ScoreRow(
                id: offset,
                season: season,
                bankNumber: bankNumber,
                player: player,
                machine: machine,
                rawScore: rawScore,
                points: points
            )
        }
    }
}

enum StatsCSVLoaderError: LocalizedError {
    case network(String)

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        }
    }
}
