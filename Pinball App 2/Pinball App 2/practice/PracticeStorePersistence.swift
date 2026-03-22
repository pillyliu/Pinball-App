import Foundation

struct LoadedPracticeStateResult {
    let state: PracticePersistedState
    let requiresCanonicalSave: Bool
}

private func loadPracticePersistedStateResultFromDefaults(
    _ defaults: UserDefaults,
    storageKey: String,
    legacyStorageKey: String
) -> LoadedPracticeStateResult? {
    let current = defaults.data(forKey: storageKey)
    let legacy = defaults.data(forKey: legacyStorageKey)
    return loadPracticePersistedStateResult(
        current: current,
        legacy: legacy
    )
}

private func loadPracticePersistedStateResult(
    current: Data?,
    legacy: Data?
) -> LoadedPracticeStateResult? {
    guard let raw = current ?? legacy,
          let loaded = try? PracticeStateCodec.decode(raw).state else {
        return nil
    }
    return LoadedPracticeStateResult(
        state: loaded,
        requiresCanonicalSave: current == nil || legacy != nil
    )
}

extension PracticeStore {
    static func loadPersistedStateFromDefaults(_ defaults: UserDefaults = .standard) -> PracticePersistedState? {
        loadPracticePersistedStateResultFromDefaults(
            defaults,
            storageKey: Self.storageKey,
            legacyStorageKey: Self.legacyStorageKey
        )?.state
    }

    static func loadPreferredLeaguePlayerNameFromDefaults(_ defaults: UserDefaults = .standard) -> String? {
        guard let state = loadPersistedStateFromDefaults(defaults) else {
            return nil
        }
        let trimmed = state.leagueSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func loadPersistedStateResult(_ defaults: UserDefaults = .standard) async -> LoadedPracticeStateResult? {
        let current = defaults.data(forKey: Self.storageKey)
        let legacy = defaults.data(forKey: Self.legacyStorageKey)
        return await PinballPerformanceTrace.measure("PracticeStateDecode") {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(
                        returning: loadPracticePersistedStateResult(
                            current: current,
                            legacy: legacy
                        )
                    )
                }
            }
        }
    }

    func applyLoadedState(_ loaded: LoadedPracticeStateResult?) {
        guard let loaded else {
            state = .empty
            invalidateJournalCaches()
            return
        }

        state = loaded.state
        invalidateJournalCaches()
    }

    func saveState() {
        invalidateJournalCaches()
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
