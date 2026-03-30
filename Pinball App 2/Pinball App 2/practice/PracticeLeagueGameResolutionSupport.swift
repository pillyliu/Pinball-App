import Foundation

extension PracticeStore {
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
}
