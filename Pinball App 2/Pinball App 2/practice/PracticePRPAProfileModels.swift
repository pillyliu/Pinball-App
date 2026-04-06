import Foundation

struct PRPASceneStanding: Identifiable, Codable, Equatable {
    let name: String
    let rank: String

    var id: String { "\(name)|\(rank)" }
}

struct PRPARecentTournament: Identifiable, Codable, Equatable {
    let name: String
    let eventType: String?
    let date: Date
    let dateLabel: String
    let placement: String
    let pointsGained: String

    var id: String { "\(name)|\(dateLabel)|\(placement)|\(pointsGained)" }
}

struct PRPAPlayerProfile: Codable, Equatable {
    let playerID: String
    let displayName: String
    let openPoints: String
    let eventsPlayed: String
    let openRanking: String
    let averagePointsPerEvent: String
    let bestFinish: String
    let worstFinish: String
    let ifpaPlayerID: String?
    let lastEventDate: String?
    let scenes: [PRPASceneStanding]
    let recentTournaments: [PRPARecentTournament]
}

struct PRPACachedProfileSnapshot: Codable {
    let profile: PRPAPlayerProfile
    let cachedAt: Date
}
