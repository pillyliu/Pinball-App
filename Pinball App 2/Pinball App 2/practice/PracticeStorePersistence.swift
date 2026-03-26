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
    let normalized = normalizeImportedLeagueTimestamps(in: loaded)
    return LoadedPracticeStateResult(
        state: normalized.state,
        requiresCanonicalSave: current == nil || legacy != nil || normalized.didChange
    )
}

private func normalizeImportedLeagueTimestamps(
    in state: PracticePersistedState
) -> (state: PracticePersistedState, didChange: Bool) {
    let importNote = "Imported from LPL stats CSV"
    let calendar = Calendar.autoupdatingCurrent
    func normalizedLeagueTimestamp(_ timestamp: Date) -> Date {
        calendar.date(bySettingHour: 22, minute: 0, second: 0, of: timestamp) ?? timestamp
    }
    var didChange = false
    var next = state

    next.scoreEntries = state.scoreEntries.map { entry in
        guard entry.leagueImported else { return entry }
        let normalizedTimestamp = normalizedLeagueTimestamp(entry.timestamp)
        guard normalizedTimestamp != entry.timestamp else { return entry }
        didChange = true
        return ScoreLogEntry(
            id: entry.id,
            gameID: entry.gameID,
            score: entry.score,
            context: entry.context,
            tournamentName: entry.tournamentName,
            timestamp: normalizedTimestamp,
            leagueImported: entry.leagueImported
        )
    }

    next.journalEntries = state.journalEntries.map { entry in
        guard entry.action == .scoreLogged,
              entry.scoreContext == .league,
              (entry.note ?? "").localizedCaseInsensitiveContains(importNote) else {
            return entry
        }

        let normalizedTimestamp = normalizedLeagueTimestamp(entry.timestamp)
        guard normalizedTimestamp != entry.timestamp else { return entry }
        didChange = true
        return JournalEntry(
            id: entry.id,
            gameID: entry.gameID,
            action: entry.action,
            task: entry.task,
            progressPercent: entry.progressPercent,
            videoKind: entry.videoKind,
            videoValue: entry.videoValue,
            score: entry.score,
            scoreContext: entry.scoreContext,
            tournamentName: entry.tournamentName,
            noteCategory: entry.noteCategory,
            noteDetail: entry.noteDetail,
            note: entry.note,
            timestamp: normalizedTimestamp
        )
    }

    return (next, didChange)
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
