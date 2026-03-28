import Foundation

private let humanNameSuffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv", "v"]

private func normalizedHumanNameTokens(_ raw: String) -> [String] {
    raw
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        .split(separator: " ")
        .map(String.init)
}

private func relaxedHumanNameTokens(_ raw: String) -> [String] {
    let baseTokens = normalizedHumanNameTokens(raw)
    guard !baseTokens.isEmpty else { return [] }

    let withoutSuffixes = baseTokens.filter { !humanNameSuffixes.contains($0) }
    guard withoutSuffixes.count > 2 else { return withoutSuffixes }

    return withoutSuffixes.enumerated().compactMap { index, token in
        let isFirstOrLast = index == 0 || index == withoutSuffixes.count - 1
        if isFirstOrLast || token.count > 1 {
            return token
        }
        return nil
    }
}

private func joinedHumanNameTokens(_ tokens: [String]) -> String {
    tokens.joined(separator: " ")
}

private func humanNameKeys(_ raw: String) -> Set<String> {
    let strict = joinedHumanNameTokens(normalizedHumanNameTokens(raw))
    let relaxed = joinedHumanNameTokens(relaxedHumanNameTokens(raw))
    return Set([strict, relaxed].filter { !$0.isEmpty })
}

private func softHumanNameMatches(_ left: String, _ right: String) -> Bool {
    let leftTokens = relaxedHumanNameTokens(left)
    let rightTokens = relaxedHumanNameTokens(right)
    guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }
    if leftTokens == rightTokens {
        return true
    }
    guard leftTokens.count >= 2, rightTokens.count >= 2 else { return false }
    guard leftTokens.last == rightTokens.last else { return false }

    let leftFirst = leftTokens[0]
    let rightFirst = rightTokens[0]
    if leftFirst == rightFirst {
        return true
    }
    guard min(leftFirst.count, rightFirst.count) >= 3 else { return false }
    return leftFirst.hasPrefix(rightFirst) || rightFirst.hasPrefix(leftFirst)
}

extension PracticeStore {
    struct LeagueCSVRow {
        let player: String
        let machine: String
        let rawScore: Double
        let eventDate: Date?
        let practiceIdentity: String?
        let opdbID: String?
    }

    struct LeagueIFPAPlayerRecord {
        let player: String
        let ifpaPlayerID: String
        let ifpaName: String
    }

    struct LeagueIdentityMatch {
        let player: String
        let ifpaPlayerID: String?
    }

    struct LeagueStatsSnapshot {
        let rows: [LeagueCSVRow]
        let players: [String]
        let updatedAt: Date?
    }

    static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    func comparePlayers(yourName: String, opponentName: String) async -> HeadToHeadComparison? {
        let yourNormalized = normalizeHumanName(yourName)
        let opponentNormalized = normalizeHumanName(opponentName)
        guard !yourNormalized.isEmpty, !opponentNormalized.isEmpty else { return nil }

        do {
            await ensureLeagueCatalogGamesLoaded()
            let rows = try await loadLeagueStatsSnapshot().rows
            let machineMappings = try await loadLeagueMachineMappings()

            let yourRows = rows.filter { normalizeHumanName($0.player) == yourNormalized }
            let opponentRows = rows.filter { normalizeHumanName($0.player) == opponentNormalized }
            guard !yourRows.isEmpty, !opponentRows.isEmpty else { return nil }

            struct PerGameAggregate {
                let gameID: String
                let values: [Double]
            }

            func aggregate(_ rows: [LeagueCSVRow]) -> [String: PerGameAggregate] {
                Dictionary(grouping: rows.compactMap { row -> (String, Double)? in
                    guard let gameID = resolveLeagueGameID(for: row, machineMappings: machineMappings) else { return nil }
                    return (gameID, row.rawScore)
                }, by: { $0.0 })
                .mapValues { pairs in
                    PerGameAggregate(gameID: pairs[0].0, values: pairs.map(\.1))
                }
            }

            let yourAgg = aggregate(yourRows)
            let opponentAgg = aggregate(opponentRows)
            let sharedIDs = Set(yourAgg.keys).intersection(opponentAgg.keys)
            guard !sharedIDs.isEmpty else { return nil }

            let games: [HeadToHeadGameStats] = sharedIDs.compactMap { gameID in
                guard let left = yourAgg[gameID], let right = opponentAgg[gameID],
                      !left.values.isEmpty, !right.values.isEmpty else { return nil }
                return HeadToHeadGameStats(
                    gameID: gameID,
                    gameName: gameName(for: gameID),
                    yourCount: left.values.count,
                    opponentCount: right.values.count,
                    yourMean: left.values.reduce(0, +) / Double(left.values.count),
                    opponentMean: right.values.reduce(0, +) / Double(right.values.count),
                    yourHigh: left.values.max() ?? 0,
                    opponentHigh: right.values.max() ?? 0,
                    yourLow: left.values.min() ?? 0,
                    opponentLow: right.values.min() ?? 0
                )
            }
            .sorted { abs($0.meanDelta) > abs($1.meanDelta) }

            let leadCount = games.filter { $0.meanDelta > 0 }.count
            let oppLeadCount = games.filter { $0.meanDelta < 0 }.count
            let avgDelta = games.isEmpty ? 0 : games.map(\.meanDelta).reduce(0, +) / Double(games.count)

            return HeadToHeadComparison(
                yourPlayerName: yourName,
                opponentPlayerName: opponentName,
                totalGamesCompared: games.count,
                gamesYouLeadByMean: leadCount,
                gamesOpponentLeadsByMean: oppLeadCount,
                averageMeanDelta: avgDelta,
                games: games
            )
        } catch {
            lastErrorMessage = "Head-to-head load failed: \(error.localizedDescription)"
            return nil
        }
    }

    func availableLeaguePlayers(forceRefresh: Bool = false) async -> [String] {
        do {
            return try await loadLeagueStatsSnapshot(forceRefresh: forceRefresh).players
        } catch {
            lastErrorMessage = "Could not load player list: \(error.localizedDescription)"
            return []
        }
    }

    func approvedLeagueIdentityMatch(for inputName: String, forceRefresh: Bool = false) async -> LeagueIdentityMatch? {
        let trimmedInput = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        do {
            let approvedPlayers = try await loadLeagueIFPAPlayers(forceRefresh: forceRefresh)
            if let approvedMatch = approvedPlayers.matchedApprovedIFPAPlayer(for: trimmedInput) {
                return LeagueIdentityMatch(
                    player: approvedMatch.player,
                    ifpaPlayerID: approvedMatch.ifpaPlayerID
                )
            }
        } catch {
            lastErrorMessage = "Could not load IFPA lookup: \(error.localizedDescription)"
        }

        let players = await availableLeaguePlayers(forceRefresh: forceRefresh)
        let normalizedInput = normalizeHumanName(trimmedInput)
        guard let matchedPlayer = players.first(where: { normalizeHumanName($0) == normalizedInput }) else {
            return nil
        }
        return LeagueIdentityMatch(player: matchedPlayer, ifpaPlayerID: nil)
    }

    @discardableResult
    func savePracticeProfileAndSyncIFPA(
        playerName: String,
        forceRefreshLeagueIdentity: Bool = false
    ) async -> LeagueIdentityMatch? {
        let trimmedPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatePracticeSettings(playerName: trimmedPlayerName)
        guard !trimmedPlayerName.isEmpty else { return nil }
        let identity = await approvedLeagueIdentityMatch(
            for: trimmedPlayerName,
            forceRefresh: forceRefreshLeagueIdentity
        )
        if let ifpaPlayerID = identity?.ifpaPlayerID {
            updatePracticeSettings(ifpaPlayerID: ifpaPlayerID)
        }
        return identity
    }

    @discardableResult
    func selectLeaguePlayerAndSyncIFPA(_ playerName: String) async -> LeagueIdentityMatch? {
        let trimmedPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        updateLeagueSettings(playerName: trimmedPlayerName)
        guard !trimmedPlayerName.isEmpty else { return nil }
        let identity = await approvedLeagueIdentityMatch(for: trimmedPlayerName)
        if let ifpaPlayerID = identity?.ifpaPlayerID {
            updatePracticeSettings(ifpaPlayerID: ifpaPlayerID)
        }
        return identity
    }

    func updateLeagueSettings(playerName: String) {
        state.leagueSettings.playerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.leagueSettings.csvAutoFillEnabled = true
        saveState()
        notifyLeaguePreviewNeedsRefresh()
    }

    func rulesheetResumeOffset(for gameID: String) -> Double {
        state.rulesheetResumeOffsets[canonicalPracticeGameID(gameID)] ?? 0
    }

    func updateRulesheetResumeOffset(gameID: String, offset: Double) {
        let gameID = canonicalPracticeGameID(gameID)
        guard !gameID.isEmpty else { return }
        state.rulesheetResumeOffsets[gameID] = max(0, offset)
        saveState()
    }

    func videoResumeHint(for gameID: String) -> String? {
        state.videoResumeHints[canonicalPracticeGameID(gameID)]
    }

    func updateVideoResumeHint(gameID: String, hint: String) {
        let gameID = canonicalPracticeGameID(gameID)
        guard !gameID.isEmpty else { return }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.videoResumeHints[gameID] = trimmed
        saveState()
    }

    func gameSummaryNote(for gameID: String) -> String {
        state.gameSummaryNotes[canonicalPracticeGameID(gameID)] ?? ""
    }

    func updateGameSummaryNote(gameID: String, note: String) {
        let gameID = canonicalPracticeGameID(gameID)
        guard !gameID.isEmpty else { return }
        let previous = state.gameSummaryNotes[gameID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            state.gameSummaryNotes.removeValue(forKey: gameID)
        } else {
            state.gameSummaryNotes[gameID] = trimmed
        }
        // Persist the summary note itself first, then log a journal note when the saved note changed.
        saveState()
        if !trimmed.isEmpty, trimmed != previous {
            addNote(gameID: gameID, category: .general, detail: "Game Note", note: trimmed)
        }
    }

    func parseLeagueRows(text: String) -> [LeagueCSVRow] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }
        let headers = header.map(normalizeCSVHeader)

        func idx(_ name: String) -> Int {
            headers.firstIndex(of: normalizeCSVHeader(name)) ?? -1
        }

        func firstIndex(_ names: [String]) -> Int {
            names.map(idx).first(where: { $0 >= 0 }) ?? -1
        }

        let playerIndex = firstIndex(["Player"])
        let machineIndex = firstIndex(["Machine", "Game"])
        let rawScoreIndex = firstIndex(["RawScore", "Score"])
        let eventDateIndex = firstIndex(["EventDate", "Event Date", "Date"])
        let practiceIdentityIndex = firstIndex(["PracticeIdentity", "practice_identity"])
        let opdbIDIndex = firstIndex(["OPDBID", "OPDB ID", "opdb_id", "opdbId"])

        guard [playerIndex, machineIndex, rawScoreIndex].allSatisfy({ $0 >= 0 }) else { return [] }

        return table.dropFirst().compactMap { columns in
            let maxRequired = max(playerIndex, machineIndex, rawScoreIndex)
            guard columns.indices.contains(maxRequired) else { return nil }
            let player = columns[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let machine = columns[machineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawScore = Double(
                columns[rawScoreIndex]
                    .replacingOccurrences(of: ",", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ) ?? 0

            guard !player.isEmpty, !machine.isEmpty, rawScore > 0 else { return nil }
            let eventDate: Date? = {
                guard eventDateIndex >= 0, columns.indices.contains(eventDateIndex) else { return nil }
                let value = columns[eventDateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return nil }
                return Self.eventDateFormatter.date(from: value)
            }()
            let practiceIdentity: String? = {
                guard practiceIdentityIndex >= 0, columns.indices.contains(practiceIdentityIndex) else { return nil }
                let value = columns[practiceIdentityIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }()
            let opdbID: String? = {
                guard opdbIDIndex >= 0, columns.indices.contains(opdbIDIndex) else { return nil }
                let value = columns[opdbIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }()

            return LeagueCSVRow(
                player: player,
                machine: machine,
                rawScore: rawScore,
                eventDate: eventDate,
                practiceIdentity: practiceIdentity,
                opdbID: opdbID
            )
        }
    }

    func loadLeagueStatsSnapshot(forceRefresh: Bool = false) async throws -> LeagueStatsSnapshot {
        let cached: CachedTextResult
        if forceRefresh {
            do {
                cached = try await PinballDataCache.shared.forceRefreshText(path: Self.leagueStatsPath)
            } catch {
                cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            }
        } else {
            cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
        }
        guard let text = cached.text else {
            cachedLeagueStatsUpdatedAt = cached.updatedAt
            cachedLeagueStatsRows = []
            cachedLeaguePlayers = []
            return LeagueStatsSnapshot(rows: [], players: [], updatedAt: cached.updatedAt)
        }

        if cachedLeagueStatsRows.isEmpty || cachedLeagueStatsUpdatedAt != cached.updatedAt {
            let snapshot = PinballPerformanceTrace.measure("PracticeLeagueStatsLoad") {
                let rows = parseLeagueRows(text: text)
                return LeagueStatsSnapshot(
                    rows: rows,
                    players: leaguePlayers(from: rows),
                    updatedAt: cached.updatedAt
                )
            }
            cachedLeagueStatsRows = snapshot.rows
            cachedLeaguePlayers = snapshot.players
            cachedLeagueStatsUpdatedAt = cached.updatedAt
        }

        return LeagueStatsSnapshot(
            rows: cachedLeagueStatsRows,
            players: cachedLeaguePlayers,
            updatedAt: cached.updatedAt
        )
    }

    func parseLeagueIFPAPlayers(text: String) -> [LeagueIFPAPlayerRecord] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }
        let headers = header.map(normalizeCSVHeader)

        func idx(_ name: String) -> Int {
            headers.firstIndex(of: normalizeCSVHeader(name)) ?? -1
        }

        let playerIndex = idx("player")
        let ifpaPlayerIDIndex = idx("ifpa_player_id")
        let ifpaNameIndex = idx("ifpa_name")

        guard [playerIndex, ifpaPlayerIDIndex, ifpaNameIndex].allSatisfy({ $0 >= 0 }) else { return [] }

        return table.dropFirst().compactMap { columns in
            let maxRequired = max(playerIndex, ifpaPlayerIDIndex, ifpaNameIndex)
            guard columns.indices.contains(maxRequired) else { return nil }

            let player = columns[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let ifpaPlayerID = columns[ifpaPlayerIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let ifpaName = columns[ifpaNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !player.isEmpty, !ifpaPlayerID.isEmpty else { return nil }

            return LeagueIFPAPlayerRecord(
                player: player,
                ifpaPlayerID: ifpaPlayerID,
                ifpaName: ifpaName.isEmpty ? player : ifpaName
            )
        }
    }

    func loadLeagueIFPAPlayers(forceRefresh: Bool = false) async throws -> [LeagueIFPAPlayerRecord] {
        let cached: CachedTextResult
        if forceRefresh {
            do {
                cached = try await PinballDataCache.shared.forceRefreshText(path: Self.leagueIFPAPlayersPath, allowMissing: true)
            } catch {
                cached = try await PinballDataCache.shared.loadText(path: Self.leagueIFPAPlayersPath, allowMissing: true)
            }
        } else {
            cached = try await PinballDataCache.shared.loadText(path: Self.leagueIFPAPlayersPath, allowMissing: true)
        }

        guard let text = cached.text else {
            cachedLeagueIFPAPlayersUpdatedAt = cached.updatedAt
            cachedLeagueIFPAPlayers = []
            return []
        }

        if cachedLeagueIFPAPlayers.isEmpty || cachedLeagueIFPAPlayersUpdatedAt != cached.updatedAt {
            cachedLeagueIFPAPlayers = parseLeagueIFPAPlayers(text: text)
            cachedLeagueIFPAPlayersUpdatedAt = cached.updatedAt
        }

        return cachedLeagueIFPAPlayers
    }

    func leaguePlayers(from rows: [LeagueCSVRow]) -> [String] {
        var dedupedByNormalized: [String: String] = [:]
        for row in rows {
            let normalized = normalizeHumanName(row.player)
            guard !normalized.isEmpty else { continue }
            if dedupedByNormalized[normalized] == nil {
                dedupedByNormalized[normalized] = row.player.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return dedupedByNormalized.values
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func loadLeagueMachineMappings(forceRefresh: Bool = false) async throws -> [String: LeagueMachineMappingRecord] {
        let cached: CachedTextResult
        if forceRefresh {
            do {
                cached = try await PinballDataCache.shared.forceRefreshText(path: Self.leagueMachineMappingsPath, allowMissing: true)
            } catch {
                cached = try await PinballDataCache.shared.loadText(path: Self.leagueMachineMappingsPath, allowMissing: true)
            }
        } else {
            cached = try await PinballDataCache.shared.loadText(path: Self.leagueMachineMappingsPath, allowMissing: true)
        }

        guard let text = cached.text else {
            cachedLeagueMachineMappingsUpdatedAt = cached.updatedAt
            cachedLeagueMachineMappings = [:]
            return [:]
        }

        if cachedLeagueMachineMappings.isEmpty || cachedLeagueMachineMappingsUpdatedAt != cached.updatedAt {
            cachedLeagueMachineMappings = parseLeagueMachineMappings(text: text)
            cachedLeagueMachineMappingsUpdatedAt = cached.updatedAt
        }

        return cachedLeagueMachineMappings
    }

    func leagueEventTimestamp(for eventDate: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.date(bySettingHour: 22, minute: 0, second: 0, of: eventDate) ?? eventDate
    }

    func resolveLeagueGameID(
        for row: LeagueCSVRow,
        machineMappings: [String: LeagueMachineMappingRecord]
    ) -> String? {
        if let direct = leaguePracticeGameID(practiceIdentity: row.practiceIdentity, opdbID: row.opdbID) {
            return direct
        }

        let normalizedMachine = LibraryGameLookup.normalizeMachineName(row.machine)
        if let mapping = machineMappings[normalizedMachine],
           let mapped = leaguePracticeGameID(practiceIdentity: mapping.practiceIdentity, opdbID: mapping.opdbID) {
            return mapped
        }

        return matchGameID(fromMachine: row.machine)
    }

    private func leaguePracticeGameID(practiceIdentity: String?, opdbID: String?) -> String? {
        let candidates = [
            practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
            opdbID.flatMap(leagueOPDBGroupID(from:)),
            opdbID?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        for candidate in candidates {
            guard let candidate, !candidate.isEmpty else { continue }
            let canonical = canonicalPracticeGameID(candidate)
            if !canonical.isEmpty, gameForAnyID(canonical) != nil || gameForAnyID(candidate) != nil {
                return canonical
            }
        }
        return nil
    }

    func matchGameID(fromMachine machine: String) -> String? {
        let machineKeys = LibraryGameLookup.equivalentKeys(gameName: machine)
        guard !machineKeys.isEmpty else { return nil }

        let matches = Set(practiceGamesDeduped().compactMap { game -> String? in
            let gameKeys = LibraryGameLookup.equivalentKeys(gameName: game.name)
            guard !machineKeys.isDisjoint(with: gameKeys) else { return nil }
            return game.canonicalPracticeKey
        })

        return matches.count == 1 ? matches.first : nil
    }

    func isDuplicateLeagueScore(gameID: String, score: Double, eventDate: Date) -> Bool {
        let gameID = canonicalPracticeGameID(gameID)
        return state.scoreEntries.contains { existing in
            guard existing.gameID == gameID, existing.context == .league else { return false }
            guard abs(existing.score - score) < 0.5 else { return false }
            return Calendar.current.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
    }

    func repairImportedLeagueScore(gameID: String, score: Double, eventDate: Date) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        let canonicalGameID = canonicalPracticeGameID(gameID)
        let matchingScores = state.scoreEntries.enumerated().filter { _, existing in
            guard existing.leagueImported, existing.context == .league else { return false }
            guard abs(existing.score - score) < 0.5 else { return false }
            return calendar.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
        guard matchingScores.count == 1 else { return false }

        let (scoreIndex, existingScore) = matchingScores[0]
        var didChange = false
        if existingScore.gameID != canonicalGameID || existingScore.timestamp != eventDate {
            state.scoreEntries[scoreIndex] = ScoreLogEntry(
                id: existingScore.id,
                gameID: canonicalGameID,
                score: existingScore.score,
                context: existingScore.context,
                tournamentName: existingScore.tournamentName,
                timestamp: eventDate,
                leagueImported: existingScore.leagueImported
            )
            didChange = true
        }

        let matchingJournal = state.journalEntries.enumerated().filter { _, existing in
            guard existing.action == .scoreLogged, existing.scoreContext == .league else { return false }
            guard let existingScore = existing.score, abs(existingScore - score) < 0.5 else { return false }
            return calendar.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
        if matchingJournal.count == 1 {
            let (journalIndex, existingJournal) = matchingJournal[0]
            if existingJournal.gameID != canonicalGameID || existingJournal.timestamp != eventDate {
                state.journalEntries[journalIndex] = JournalEntry(
                    id: existingJournal.id,
                    gameID: canonicalGameID,
                    action: existingJournal.action,
                    task: existingJournal.task,
                    progressPercent: existingJournal.progressPercent,
                    videoKind: existingJournal.videoKind,
                    videoValue: existingJournal.videoValue,
                    score: existingJournal.score,
                    scoreContext: existingJournal.scoreContext,
                    tournamentName: existingJournal.tournamentName,
                    noteCategory: existingJournal.noteCategory,
                    noteDetail: existingJournal.noteDetail,
                    note: existingJournal.note,
                    timestamp: eventDate
                )
                didChange = true
            }
        }

        return didChange
    }

    private func leagueOPDBGroupID(from raw: String) -> String? {
        let pattern = #"(?i)\bG[0-9A-Z]{4,}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              let tokenRange = Range(match.range, in: raw) else {
            return nil
        }
        return String(raw[tokenRange])
    }

    func normalizeHumanName(_ raw: String) -> String {
        raw
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func leagueTargetScores(forGameName gameName: String) -> LeagueTargetScores? {
        let keys = LibraryGameLookup.candidateKeys(gameName: gameName)
        guard !keys.isEmpty else { return nil }

        for key in keys {
            if let exact = leagueTargetsByNormalizedMachine[key] {
                return exact
            }
        }

        if let looseKey = leagueTargetsByNormalizedMachine.keys.first(where: { candidate in
            keys.contains { key in candidate.contains(key) || key.contains(candidate) }
        }) {
            return leagueTargetsByNormalizedMachine[looseKey]
        }

        return nil
    }
}

private extension Array where Element == PracticeStore.LeagueIFPAPlayerRecord {
    func matchedApprovedIFPAPlayer(for inputName: String) -> PracticeStore.LeagueIFPAPlayerRecord? {
        let inputKeys = humanNameKeys(inputName)
        let exactMatches = filter { record in
            let candidateKeys = humanNameKeys(record.player).union(humanNameKeys(record.ifpaName))
            return !candidateKeys.isDisjoint(with: inputKeys)
        }
        if exactMatches.count == 1 {
            return exactMatches[0]
        }
        if exactMatches.count > 1 {
            return nil
        }

        let softMatches = filter { record in
            softHumanNameMatches(inputName, record.player) || softHumanNameMatches(inputName, record.ifpaName)
        }
        return softMatches.count == 1 ? softMatches[0] : nil
    }
}
