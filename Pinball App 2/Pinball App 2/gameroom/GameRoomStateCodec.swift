import Foundation

enum GameRoomStateCodec {
    enum LoadResult {
        case missing
        case loaded(GameRoomPersistedState, needsResave: Bool, noticeMessage: String?)
        case failed(String)
    }

    private enum SavedStateSource {
        case current
        case legacy

        var displayName: String {
            switch self {
            case .current:
                return "current"
            case .legacy:
                return "legacy"
            }
        }
    }

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

    static func decode(_ raw: Data) throws -> GameRoomPersistedState {
        try canonicalDecoder().decode(GameRoomPersistedState.self, from: raw)
    }

    static func loadFromDefaults(
        _ defaults: UserDefaults = .standard,
        storageKey: String,
        legacyStorageKey: String
    ) -> LoadResult {
        let currentRaw = defaults.data(forKey: storageKey)
        let legacyRaw = defaults.data(forKey: legacyStorageKey)

        if let currentRaw {
            do {
                let decoded = try decode(currentRaw)
                return .loaded(decoded, needsResave: legacyRaw != nil, noticeMessage: nil)
            } catch {
                if let legacyRaw {
                    do {
                        let decoded = try decode(legacyRaw)
                        return .loaded(
                            decoded,
                            needsResave: true,
                            noticeMessage: "GameRoom recovered from the legacy save because the current saved data could not be read."
                        )
                    } catch {
                        return .failed(
                            "Saved GameRoom data could not be restored from either the current or legacy save. GameRoom opened empty, and the unreadable saved data was not overwritten."
                        )
                    }
                }

                return .failed(
                    "Saved GameRoom data could not be restored from the \(SavedStateSource.current.displayName) save. GameRoom opened empty, and the unreadable saved data was not overwritten."
                )
            }
        }

        if let legacyRaw {
            do {
                let decoded = try decode(legacyRaw)
                return .loaded(decoded, needsResave: true, noticeMessage: nil)
            } catch {
                return .failed(
                    "Saved GameRoom data could not be restored from the \(SavedStateSource.legacy.displayName) save. GameRoom opened empty, and the unreadable saved data was not overwritten."
                )
            }
        }

        return .missing
    }
}
