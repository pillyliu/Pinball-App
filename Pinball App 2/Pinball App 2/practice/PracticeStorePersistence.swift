import Foundation

extension PracticeStore {
    static func loadPersistedStateFromDefaults(_ defaults: UserDefaults = .standard) -> PracticePersistedState? {
        PracticeStateCodec.loadFromDefaults(defaults, storageKey: Self.storageKey, legacyStorageKey: Self.legacyStorageKey)
    }

    func loadState() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.data(forKey: Self.storageKey) ?? defaults.data(forKey: Self.legacyStorageKey) else {
            state = .empty
            return
        }

        do {
            let decoded = try PracticeStateCodec.decode(raw)
            state = decoded.state
            if defaults.data(forKey: Self.storageKey) == nil {
                defaults.set(raw, forKey: Self.storageKey)
            } else if decoded.usedFallbackDateDecoding {
                saveState()
            }
        } catch {
            lastErrorMessage = "Failed to load saved practice data: \(error.localizedDescription)"
            state = .empty
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
