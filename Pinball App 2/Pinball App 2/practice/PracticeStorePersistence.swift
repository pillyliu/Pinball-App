import Foundation

extension PracticeStore {
    static func loadPersistedStateFromDefaults(_ defaults: UserDefaults = .standard) -> PracticePersistedState? {
        PracticeStateCodec.loadFromDefaults(defaults, storageKey: Self.storageKey, legacyStorageKey: Self.legacyStorageKey)
    }

    static func loadPreferredLeaguePlayerNameFromDefaults(_ defaults: UserDefaults = .standard) -> String? {
        guard let state = loadPersistedStateFromDefaults(defaults) else {
            return nil
        }
        let trimmed = state.leagueSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func loadState() {
        let defaults = UserDefaults.standard
        guard let loaded = Self.loadPersistedStateFromDefaults(defaults) else {
            state = .empty
            return
        }

        state = loaded
        if defaults.data(forKey: Self.storageKey) == nil || defaults.data(forKey: Self.legacyStorageKey) != nil {
            saveState()
        }
    }

    func saveState() {
        do {
            state.schemaVersion = PracticePersistedState.currentSchemaVersion
            let data = try PracticeStateCodec.canonicalEncoder().encode(state)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.legacyStorageKey)
        } catch {
            lastErrorMessage = "Failed to save practice data: \(error.localizedDescription)"
        }
    }
}
