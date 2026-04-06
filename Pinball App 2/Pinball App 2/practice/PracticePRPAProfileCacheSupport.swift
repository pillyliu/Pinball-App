import Foundation

enum PRPAPublicProfileCacheStore {
    private static let keyPrefix = "prpa-public-profile-cache"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load(playerID: String) -> PRPACachedProfileSnapshot? {
        let defaults = UserDefaults.standard
        let key = cacheKey(for: playerID)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? decoder.decode(PRPACachedProfileSnapshot.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    static func save(_ profile: PRPAPlayerProfile) {
        guard let data = try? encoder.encode(PRPACachedProfileSnapshot(profile: profile, cachedAt: Date())) else {
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey(for: profile.playerID))
    }

    private static func cacheKey(for playerID: String) -> String {
        "\(keyPrefix).\(playerID)"
    }
}
