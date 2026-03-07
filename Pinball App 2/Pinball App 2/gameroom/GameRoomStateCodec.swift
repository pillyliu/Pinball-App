import Foundation

enum GameRoomStateCodec {
    static func canonicalDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    static func loadFromDefaults(
        _ defaults: UserDefaults = .standard,
        storageKey: String,
        legacyStorageKey: String
    ) -> GameRoomPersistedState? {
        guard let raw = defaults.data(forKey: storageKey) ?? defaults.data(forKey: legacyStorageKey) else {
            return nil
        }
        return try? canonicalDecoder().decode(GameRoomPersistedState.self, from: raw)
    }
}

