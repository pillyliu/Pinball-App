import Foundation

struct IFPARecentTournament: Identifiable, Codable, Equatable {
    let name: String
    let date: Date
    let dateLabel: String
    let finish: String
    let pointsGained: String

    var id: String { "\(name)|\(dateLabel)|\(finish)|\(pointsGained)" }
}

struct IFPAPlayerProfile: Codable, Equatable {
    let playerID: String
    let displayName: String
    let location: String?
    let profilePhotoURL: URL?
    let currentRank: String
    let currentWPPRPoints: String
    let rating: String
    let lastEventDate: String?
    let seriesLabel: String?
    let seriesRank: String?
    let recentTournaments: [IFPARecentTournament]
}

struct IFPACachedProfileSnapshot: Codable {
    let profile: IFPAPlayerProfile
    let cachedAt: Date
}
