import Foundation
import OSLog

private let resolvedLeagueTargetsLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.pillyliu.Pinball-App-2",
    category: "DataIntegrity"
)

struct ResolvedLeagueTargetRecord: Decodable, Identifiable {
    let order: Int
    let game: String
    let practiceIdentity: String?
    let opdbID: String?
    let area: String?
    let areaOrder: Int?
    let group: Int?
    let position: Int?
    let bank: Int?
    let secondHighestAvg: Int64
    let fourthHighestAvg: Int64
    let eighthHighestAvg: Int64

    var id: String { practiceIdentity ?? "\(order)-\(game)" }
    var scores: LeagueTargetScores {
        LeagueTargetScores(
            great: Double(secondHighestAvg),
            main: Double(fourthHighestAvg),
            floor: Double(eighthHighestAvg)
        )
    }

    enum CodingKeys: String, CodingKey {
        case order
        case game
        case practiceIdentity = "practice_identity"
        case opdbID = "opdb_id"
        case area
        case areaOrder = "area_order"
        case group
        case position
        case bank
        case secondHighestAvg = "second_highest_avg"
        case fourthHighestAvg = "fourth_highest_avg"
        case eighthHighestAvg = "eighth_highest_avg"
    }
}

private struct ResolvedLeagueTargetsRoot: Decodable {
    let version: Int
    let items: [ResolvedLeagueTargetRecord]
}

func parseResolvedLeagueTargets(text: String) -> [ResolvedLeagueTargetRecord] {
    guard let data = text.data(using: .utf8) ?? text.data(using: .unicode) else { return [] }
    let decoder = JSONDecoder()
    guard let root = try? decoder.decode(ResolvedLeagueTargetsRoot.self, from: data), root.version >= 1 else {
        return []
    }
    return root.items
}

func resolvedLeagueTargetScoresByPracticeIdentity(records: [ResolvedLeagueTargetRecord]) -> [String: LeagueTargetScores] {
    var out: [String: LeagueTargetScores] = [:]
    for record in records {
        guard let practiceIdentity = record.practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !practiceIdentity.isEmpty else {
            continue
        }
        if out[practiceIdentity] != nil {
            resolvedLeagueTargetsLogger.warning(
                "Duplicate resolved league target for practice identity \(practiceIdentity, privacy: .public); keeping later row from game \(record.game, privacy: .public)"
            )
        }
        out[practiceIdentity] = record.scores
    }
    return out
}
