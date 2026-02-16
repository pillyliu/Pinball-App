import Foundation

enum LibraryActivityKind: String, Codable {
    case browseGame
    case openRulesheet
    case openPlayfield
    case tapVideo
}

struct LibraryActivityEvent: Identifiable, Codable {
    let id: UUID
    let gameID: String
    let gameName: String
    let kind: LibraryActivityKind
    let detail: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        gameID: String,
        gameName: String,
        kind: LibraryActivityKind,
        detail: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.gameID = gameID
        self.gameName = gameName
        self.kind = kind
        self.detail = detail
        self.timestamp = timestamp
    }
}

enum LibraryActivityLog {
    private static let key = "library-activity-log-v1"
    private static let maxEvents = 500

    static func log(gameID: String, gameName: String, kind: LibraryActivityKind, detail: String? = nil) {
        guard !gameID.isEmpty else { return }
        var events = load()
        let now = Date()
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let latest = events.first,
           latest.gameID == gameID,
           latest.kind == kind,
           (latest.detail ?? "") == (trimmedDetail ?? ""),
           now.timeIntervalSince(latest.timestamp) < 2.0 {
            return
        }

        events.insert(
            LibraryActivityEvent(
                gameID: gameID,
                gameName: gameName,
                kind: kind,
                detail: trimmedDetail,
                timestamp: now
            ),
            at: 0
        )
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        save(events)
    }

    static func events() -> [LibraryActivityEvent] {
        load().sorted { $0.timestamp > $1.timestamp }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func load() -> [LibraryActivityEvent] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([LibraryActivityEvent].self, from: data)) ?? []
    }

    private static func save(_ events: [LibraryActivityEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
