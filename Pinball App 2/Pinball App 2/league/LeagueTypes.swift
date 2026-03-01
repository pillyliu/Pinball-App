import SwiftUI

enum LeagueDestination: String, CaseIterable, Identifiable {
    case stats
    case standings
    case targets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stats: return "Stats"
        case .standings: return "Standings"
        case .targets: return "Targets"
        }
    }

    var subtitle: String {
        switch self {
        case .stats: return "Player trends and machine performance"
        case .standings: return "Season standings and bank breakdown"
        case .targets: return "Great game, main target, and floor goals"
        }
    }

    var icon: String {
        switch self {
        case .stats: return "chart.xyaxis.line"
        case .standings: return "list.number"
        case .targets: return "scope"
        }
    }
}

enum LeagueTargetMetric: Int, CaseIterable {
    case second
    case fourth
    case eighth

    var title: String {
        switch self {
        case .second: return "2nd"
        case .fourth: return "4th"
        case .eighth: return "8th"
        }
    }

    var color: Color {
        switch self {
        case .second: return AppTheme.targetGreat
        case .fourth: return AppTheme.targetMain
        case .eighth: return AppTheme.targetFloor
        }
    }

    func value(for row: LeagueTargetPreviewRow) -> Int64 {
        switch self {
        case .second: return row.secondHighest
        case .fourth: return row.fourthHighest
        case .eighth: return row.eighthHighest
        }
    }
}

enum LeagueStandingsPreviewMode: Int, CaseIterable {
    case topFive
    case aroundYou

    var title: String {
        switch self {
        case .topFive: return "Top 5"
        case .aroundYou: return "Around You"
        }
    }
}

struct LeagueTargetPreviewRow {
    let game: String
    let secondHighest: Int64
    let fourthHighest: Int64
    let eighthHighest: Int64
    let bank: Int?
    let order: Int
}

struct LeagueStandingsPreviewRow: Identifiable {
    let rank: Int
    let rawPlayer: String
    let points: Double

    var id: String { "\(rank)-\(rawPlayer)" }

    var displayPlayer: String {
        formatLPLPlayerNameForDisplay(rawPlayer)
    }
}

struct LeagueStatsPreviewRow: Identifiable {
    let machine: String
    let score: Double
    let points: Double
    let order: Int

    var id: String { "\(order)-\(machine)" }
}


extension Int64 {
    var leagueHubFormattedWithCommas: String {
        self.formatted(.number.grouping(.automatic))
    }
}

extension Double {
    var leagueHubFormattedWholeNumber: String {
        Int(self.rounded()).formatted(.number.grouping(.automatic))
    }
}
