import Foundation

enum PracticeStateCodec {
    private static let plausibilityEpochCutoff = Date(timeIntervalSince1970: 1_420_070_400) // 2015-01-01

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

    static func fallbackDecoder() -> JSONDecoder {
        // Legacy compatibility with Foundation's default Date Codable encoding.
        JSONDecoder()
    }

    static func loadFromDefaults(
        _ defaults: UserDefaults = .standard,
        storageKey: String,
        legacyStorageKey: String
    ) -> PracticePersistedState? {
        guard let raw = defaults.data(forKey: storageKey) ?? defaults.data(forKey: legacyStorageKey) else {
            return nil
        }
        return try? decode(raw).state
    }

    static func decode(_ raw: Data) throws -> (state: PracticePersistedState, usedFallbackDateDecoding: Bool) {
        func decodeWithFallback() throws -> PracticePersistedState {
            try fallbackDecoder().decode(PracticePersistedState.self, from: raw)
        }

        do {
            let decoded = try canonicalDecoder().decode(PracticePersistedState.self, from: raw)
            if !containsPlausibleRecentTimestamp(decoded) {
                let legacy = try decodeWithFallback()
                if containsPlausibleRecentTimestamp(legacy) {
                    return (legacy, true)
                }
            }
            return (decoded, false)
        } catch let canonicalError {
            do {
                return (try decodeWithFallback(), true)
            } catch {
                throw canonicalError
            }
        }
    }

    private static func containsPlausibleRecentTimestamp(_ state: PracticePersistedState) -> Bool {
        return allTimestamps(state).contains { $0 >= plausibilityEpochCutoff }
    }

    private static func allTimestamps(_ state: PracticePersistedState) -> [Date] {
        var timestamps: [Date] = []
        timestamps += state.studyEvents.map(\.timestamp)
        timestamps += state.videoProgressEntries.map(\.timestamp)
        timestamps += state.scoreEntries.map(\.timestamp)
        timestamps += state.noteEntries.map(\.timestamp)
        timestamps += state.journalEntries.map(\.timestamp)
        timestamps += state.customGroups.map(\.createdAt)
        timestamps += state.customGroups.compactMap(\.startDate)
        timestamps += state.customGroups.compactMap(\.endDate)
        if let lastImportAt = state.leagueSettings.lastImportAt {
            timestamps.append(lastImportAt)
        }
        return timestamps
    }
}
