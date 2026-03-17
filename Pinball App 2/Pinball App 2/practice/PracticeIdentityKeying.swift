import Foundation

extension PinballGame {
    var canonicalPracticeKey: String {
        practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? slug
    }
}

func preferredPracticeRepresentative(_ games: [PinballGame]) -> PinballGame? {
    games.max {
        let lhsScore = practiceRepresentativeScore($0)
        let rhsScore = practiceRepresentativeScore($1)
        if lhsScore != rhsScore { return lhsScore < rhsScore }
        return $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedDescending
    }
}

private func practiceRepresentativeScore(_ game: PinballGame) -> Int {
    var score = 0
    if game.sourceId == "venue--gameroom" { score += 600 }
    if game.sourceId != "venue--pm-8760" && game.sourceId != "venue--the-avenue-cafe" && game.sourceId != "the-avenue" { score += 250 }
    if game.sourceType != .venue { score += 150 }
    if game.name.contains(":") { score += 120 }
    if let variant = game.normalizedVariant?.trimmingCharacters(in: .whitespacesAndNewlines), !variant.isEmpty {
        score += 100
        if variant.localizedCaseInsensitiveContains("anniversary") { score += 120 }
    }
    if game.primaryImageLargeUrl != nil || game.primaryImageUrl != nil { score += 60 }
    if let year = game.year { score += year }
    score += game.name.count
    return score
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
        if let exactID = pool.first(where: { $0.id == trimmed }) {
            return exactID
        }
        if let exactSlug = pool.first(where: { $0.slug == trimmed }) {
            return exactSlug
        }
        let practiceMatches = pool.filter { $0.canonicalPracticeKey == trimmed }
        if !practiceMatches.isEmpty {
            return preferredPracticeRepresentative(practiceMatches)
        }
        return nil
    }

    func practiceGamesDeduped() -> [PinballGame] {
        Dictionary(grouping: practiceLookupGamesPool, by: \.canonicalPracticeKey)
            .compactMap { preferredPracticeRepresentative($0.value) }
            .sorted {
                let nameCompare = $0.name.localizedCaseInsensitiveCompare($1.name)
                if nameCompare != .orderedSame { return nameCompare == .orderedAscending }
                return $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending
            }
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
        for key in Self.practicePreferenceGameIDKeys {
            let raw = defaults.string(forKey: key) ?? ""
            if raw.isEmpty { continue }
            let canonical = canonicalPracticeGameID(raw)
            if canonical != raw {
                defaults.set(canonical, forKey: key)
            }
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
        if let slugMatch = pool.first(where: { normalizedLegacyGameKey($0.slug) == normalized }) {
            return slugMatch
        }
        let canonicalMatches = pool.filter { normalizedLegacyGameKey($0.canonicalPracticeKey) == normalized }
        if !canonicalMatches.isEmpty {
            return preferredPracticeRepresentative(canonicalMatches)
        }
        return nil
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
