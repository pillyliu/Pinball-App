import Foundation

extension PracticeStore {
    struct LeagueCSVRow {
        let player: String
        let machine: String
        let rawScore: Double
        let eventDate: Date?
    }

    static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let machineAliases: [String: [String]] = [
        "tmnt": ["teenagemutantninjaturtles"],
        "thegetaway": ["thegetawayhighspeedii"],
        "starwars2017": ["starwars"],
        "jurassicparkstern2019": ["jurassicpark", "jurassicpark2019"],
        "attackfrommars": ["attackfrommarsremake"],
        "dungeonsanddragons": ["dungeonsdragons"]
    ]

    func comparePlayers(yourName: String, opponentName: String) async -> HeadToHeadComparison? {
        let yourNormalized = normalizeHumanName(yourName)
        let opponentNormalized = normalizeHumanName(opponentName)
        guard !yourNormalized.isEmpty, !opponentNormalized.isEmpty else { return nil }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            guard let text = cached.text else { return nil }
            let rows = parseLeagueRows(text: text)

            let yourRows = rows.filter { normalizeHumanName($0.player) == yourNormalized }
            let opponentRows = rows.filter { normalizeHumanName($0.player) == opponentNormalized }
            guard !yourRows.isEmpty, !opponentRows.isEmpty else { return nil }

            struct PerGameAggregate {
                let gameID: String
                let values: [Double]
            }

            func aggregate(_ rows: [LeagueCSVRow]) -> [String: PerGameAggregate] {
                Dictionary(grouping: rows.compactMap { row -> (String, Double)? in
                    guard let gameID = matchGameID(fromMachine: row.machine) else { return nil }
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

    func availableLeaguePlayers() async -> [String] {
        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            guard let text = cached.text else { return [] }
            let rows = parseLeagueRows(text: text)

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
        } catch {
            lastErrorMessage = "Could not load player list: \(error.localizedDescription)"
            return []
        }
    }

    func updateLeagueSettings(playerName: String, csvAutoFillEnabled: Bool) {
        state.leagueSettings.playerName = playerName
        state.leagueSettings.csvAutoFillEnabled = csvAutoFillEnabled
        saveState()
    }

    func rulesheetResumeOffset(for gameID: String) -> Double {
        state.rulesheetResumeOffsets[gameID] ?? 0
    }

    func updateRulesheetResumeOffset(gameID: String, offset: Double) {
        guard !gameID.isEmpty else { return }
        state.rulesheetResumeOffsets[gameID] = max(0, offset)
        saveState()
    }

    func videoResumeHint(for gameID: String) -> String? {
        state.videoResumeHints[gameID]
    }

    func updateVideoResumeHint(gameID: String, hint: String) {
        guard !gameID.isEmpty else { return }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.videoResumeHints[gameID] = trimmed
        saveState()
    }

    func gameSummaryNote(for gameID: String) -> String {
        state.gameSummaryNotes[gameID] ?? ""
    }

    func updateGameSummaryNote(gameID: String, note: String) {
        guard !gameID.isEmpty else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            state.gameSummaryNotes.removeValue(forKey: gameID)
        } else {
            state.gameSummaryNotes[gameID] = trimmed
        }
        saveState()
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

        guard [playerIndex, machineIndex, rawScoreIndex].allSatisfy({ $0 >= 0 }) else { return [] }

        return table.dropFirst().compactMap { columns in
            let maxRequired = max(playerIndex, machineIndex, rawScoreIndex)
            guard columns.indices.contains(maxRequired) else { return nil }
            let player = columns[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let machine = columns[machineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawScore = Double(columns[rawScoreIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            guard !player.isEmpty, !machine.isEmpty, rawScore > 0 else { return nil }
            let eventDate: Date? = {
                guard eventDateIndex >= 0, columns.indices.contains(eventDateIndex) else { return nil }
                let value = columns[eventDateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return nil }
                return Self.eventDateFormatter.date(from: value)
            }()

            return LeagueCSVRow(player: player, machine: machine, rawScore: rawScore, eventDate: eventDate)
        }
    }

    func matchGameID(fromMachine machine: String) -> String? {
        let normalizedMachine = normalizeMachineName(machine)
        if let exact = games.first(where: { normalizeMachineName($0.name) == normalizedMachine }) {
            return exact.id
        }

        if let fuzzy = games.first(where: {
            let candidate = normalizeMachineName($0.name)
            return candidate.contains(normalizedMachine) || normalizedMachine.contains(candidate)
        }) {
            return fuzzy.id
        }
        return nil
    }

    func isDuplicateLeagueScore(gameID: String, score: Double, eventDate: Date) -> Bool {
        state.scoreEntries.contains { existing in
            guard existing.gameID == gameID, existing.context == .league else { return false }
            guard abs(existing.score - score) < 0.5 else { return false }
            return Calendar.current.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
    }

    func normalizeHumanName(_ raw: String) -> String {
        raw
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func normalizeMachineName(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    func leagueTargetScores(forGameName gameName: String) -> LeagueTargetScores? {
        let normalized = normalizeMachineName(gameName)
        let aliases = Self.machineAliases[normalized] ?? []
        let keys = [normalized] + aliases

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
