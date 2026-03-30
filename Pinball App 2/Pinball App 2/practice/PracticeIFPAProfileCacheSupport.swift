import Foundation

enum IFPAPublicProfileCacheStore {
    private static let keyPrefix = "ifpa-public-profile-cache"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load(playerID: String) -> IFPACachedProfileSnapshot? {
        let defaults = UserDefaults.standard
        let key = cacheKey(for: playerID)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? decoder.decode(IFPACachedProfileSnapshot.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    static func save(_ profile: IFPAPlayerProfile) {
        guard let data = try? encoder.encode(IFPACachedProfileSnapshot(profile: profile, cachedAt: Date())) else {
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey(for: profile.playerID))
    }

    private static func cacheKey(for playerID: String) -> String {
        "\(keyPrefix).\(playerID)"
    }
}
