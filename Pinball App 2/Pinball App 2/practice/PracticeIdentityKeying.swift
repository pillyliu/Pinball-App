import Foundation

extension PinballGame {
    var canonicalPracticeKey: String {
        practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? slug
    }
}

extension PracticeStore {
    private static let practiceIdentityAliases: [String: String] = [:]
    private static let practicePreferenceGameIDKeys: [String] = [
        "practice-quick-game-score",
        "practice-quick-game-study",
        "practice-quick-game-practice",
        "practice-quick-game-mechanics",
        "practice-last-viewed-game-id",
        "library-last-viewed-game-id"
    ]
    private var practiceLookupGamesPool: [PinballGame] {
        allLibraryGames.isEmpty ? games : allLibraryGames
    }

    func canonicalPracticeGameID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let aliased = Self.practiceIdentityAliases[trimmed] ?? trimmed
        if let match = gameForAnyID(aliased) {
            return match.canonicalPracticeKey
        }
        if let match = legacyPracticeKeyMatch(for: aliased) {
            return match.canonicalPracticeKey
        }
        return aliased
    }

    func gameForAnyID(_ id: String) -> PinballGame? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let pool = practiceLookupGamesPool
        return pool.first(where: { $0.canonicalPracticeKey == trimmed })
            ?? pool.first(where: { $0.id == trimmed })
            ?? pool.first(where: { $0.slug == trimmed })
    }

    func practiceGamesDeduped() -> [PinballGame] {
        var seen = Set<String>()
        var out: [PinballGame] = []
        for game in practiceLookupGamesPool {
            let key = game.canonicalPracticeKey
            if seen.insert(key).inserted {
                out.append(game)
            }
        }
        return out
    }

    func migratePracticeStateKeysToCanonicalIfNeeded() {
        guard !practiceLookupGamesPool.isEmpty else { return }
        let migrated = migratedStateKeysToCanonical(state)
        state = migrated
        saveState()
        migratePracticePreferenceGameIDsToCanonicalIfNeeded()
    }

    private func migratedStateKeysToCanonical(_ current: PracticePersistedState) -> PracticePersistedState {
        func mapID(_ value: String) -> String { canonicalPracticeGameID(value) }

        var next = current
        next.studyEvents = current.studyEvents.map { StudyProgressEvent(id: $0.id, gameID: mapID($0.gameID), task: $0.task, progressPercent: $0.progressPercent, timestamp: $0.timestamp) }
        next.videoProgressEntries = current.videoProgressEntries.map { VideoProgressEntry(id: $0.id, gameID: mapID($0.gameID), kind: $0.kind, value: $0.value, timestamp: $0.timestamp) }
        next.scoreEntries = current.scoreEntries.map { ScoreLogEntry(id: $0.id, gameID: mapID($0.gameID), score: $0.score, context: $0.context, tournamentName: $0.tournamentName, timestamp: $0.timestamp, leagueImported: $0.leagueImported) }
        next.noteEntries = current.noteEntries.map { PracticeNoteEntry(id: $0.id, gameID: mapID($0.gameID), category: $0.category, detail: $0.detail, note: $0.note, timestamp: $0.timestamp) }
        next.journalEntries = current.journalEntries.map {
            JournalEntry(
                id: $0.id,
                gameID: mapID($0.gameID),
                action: $0.action,
                task: $0.task,
                progressPercent: $0.progressPercent,
                videoKind: $0.videoKind,
                videoValue: $0.videoValue,
                score: $0.score,
                scoreContext: $0.scoreContext,
                tournamentName: $0.tournamentName,
                noteCategory: $0.noteCategory,
                noteDetail: $0.noteDetail,
                note: $0.note,
                timestamp: $0.timestamp
            )
        }
        next.customGroups = current.customGroups.map { group in
            var updated = group
            updated.gameIDs = uniqueGameIDsPreservingOrder(group.gameIDs.map(mapID))
            return updated
        }
        next.rulesheetResumeOffsets = Dictionary(uniqueKeysWithValues: current.rulesheetResumeOffsets.map { (mapID($0.key), $0.value) }.filter { !$0.0.isEmpty })
        next.videoResumeHints = Dictionary(uniqueKeysWithValues: current.videoResumeHints.map { (mapID($0.key), $0.value) }.filter { !$0.0.isEmpty })
        next.gameSummaryNotes = Dictionary(uniqueKeysWithValues: current.gameSummaryNotes.map { (mapID($0.key), $0.value) }.filter { !$0.0.isEmpty })
        return next
    }

    private func migratePracticePreferenceGameIDsToCanonicalIfNeeded() {
        let defaults = UserDefaults.standard
        var changed = false
        for key in Self.practicePreferenceGameIDKeys {
            let raw = defaults.string(forKey: key) ?? ""
            if raw.isEmpty { continue }
            let canonical = canonicalPracticeGameID(raw)
            if canonical != raw {
                defaults.set(canonical, forKey: key)
                changed = true
            }
        }
        if changed {
            defaults.synchronize()
        }
    }

    private func legacyPracticeKeyMatch(for raw: String) -> PinballGame? {
        let pool = practiceLookupGamesPool
        if let opdbGroup = extractLikelyOPDBGroupID(from: raw) {
            if let byGroup = pool.first(where: { $0.canonicalPracticeKey.caseInsensitiveCompare(opdbGroup) == .orderedSame }) {
                return byGroup
            }
        }

        let normalized = normalizedLegacyGameKey(raw)
        guard !normalized.isEmpty else { return nil }
        return pool.first(where: { normalizedLegacyGameKey($0.slug) == normalized })
            ?? pool.first(where: { normalizedLegacyGameKey($0.canonicalPracticeKey) == normalized })
    }

    private func extractLikelyOPDBGroupID(from raw: String) -> String? {
        let pattern = #"(?i)\bG[0-9A-Z]{4,}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              let tokenRange = Range(match.range, in: raw) else {
            return nil
        }
        return String(raw[tokenRange])
    }

    private func normalizedLegacyGameKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
