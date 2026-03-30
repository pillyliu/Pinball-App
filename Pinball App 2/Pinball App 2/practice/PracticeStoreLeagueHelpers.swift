import Foundation

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
}
