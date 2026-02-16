import Foundation

extension PracticeStore {
    func loadState() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.data(forKey: Self.storageKey) ?? defaults.data(forKey: Self.legacyStorageKey) else {
            state = .empty
            return
        }

        do {
            state = try JSONDecoder().decode(PracticePersistedState.self, from: raw)
            if defaults.data(forKey: Self.storageKey) == nil {
                defaults.set(raw, forKey: Self.storageKey)
            }
        } catch {
            lastErrorMessage = "Failed to load saved practice data: \(error.localizedDescription)"
            state = .empty
        }
    }

    func saveState() {
        do {
            let data = try JSONEncoder().encode(state)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.legacyStorageKey)
        } catch {
            lastErrorMessage = "Failed to save practice data: \(error.localizedDescription)"
        }
    }
}
