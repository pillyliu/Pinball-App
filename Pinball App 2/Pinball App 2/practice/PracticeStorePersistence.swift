import Foundation

extension PracticeStore {
    private static func canonicalPracticeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private static func canonicalPracticeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    func loadState() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.data(forKey: Self.storageKey) ?? defaults.data(forKey: Self.legacyStorageKey) else {
            state = .empty
            return
        }

        do {
            state = try Self.canonicalPracticeDecoder().decode(PracticePersistedState.self, from: raw)
            if defaults.data(forKey: Self.storageKey) == nil {
                defaults.set(raw, forKey: Self.storageKey)
            }
        } catch {
            do {
                // Backward compatibility for older iOS builds that used Foundation's default Date Codable encoding.
                state = try JSONDecoder().decode(PracticePersistedState.self, from: raw)
                saveState()
            } catch {
                lastErrorMessage = "Failed to load saved practice data: \(error.localizedDescription)"
                state = .empty
            }
        }
    }

    func saveState() {
        do {
            state.schemaVersion = PracticePersistedState.currentSchemaVersion
            let data = try Self.canonicalPracticeEncoder().encode(state)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.legacyStorageKey)
        } catch {
            lastErrorMessage = "Failed to save practice data: \(error.localizedDescription)"
        }
    }
}
