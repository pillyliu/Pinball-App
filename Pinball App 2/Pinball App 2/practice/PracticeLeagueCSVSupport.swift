import Foundation

extension PracticeStore {
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
}
