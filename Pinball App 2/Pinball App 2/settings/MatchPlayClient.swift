import Foundation

struct MatchPlayTournamentImportResult: Hashable {
    let id: String
    let name: String
    let machineIDs: [String]
}

enum MatchPlayClient {
    private static let decoder = JSONDecoder()

    static func fetchTournament(id: String) async throws -> MatchPlayTournamentImportResult {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MatchPlayClientError.invalidTournamentID
        }

        guard let url = URL(string: "https://app.matchplay.events/api/tournaments/\(trimmed)?includeArenas=true") else {
            throw MatchPlayClientError.invalidTournamentID
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw MatchPlayClientError.http(statusCode: httpResponse.statusCode)
        }

        let payload = try decoder.decode(MatchPlayTournamentResponse.self, from: data)
        let machineIDs = Array(
            NSOrderedSet(
                array: payload.data.arenas.compactMap { arena in
                    arena.opdbID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
                }
            )
        ).compactMap { $0 as? String }

        return MatchPlayTournamentImportResult(
            id: String(payload.data.tournamentID),
            name: payload.data.name,
            machineIDs: machineIDs
        )
    }
}

private enum MatchPlayClientError: LocalizedError {
    case invalidTournamentID
    case http(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidTournamentID:
            return "Enter a valid tournament ID."
        case .http(let statusCode):
            if statusCode == 404 {
                return "Tournament not found."
            }
            return "Match Play request failed (\(statusCode))."
        }
    }
}

private struct MatchPlayTournamentResponse: Decodable {
    let data: MatchPlayTournamentData
}

private struct MatchPlayTournamentData: Decodable {
    let tournamentID: Int
    let name: String
    let arenas: [MatchPlayArena]

    enum CodingKeys: String, CodingKey {
        case tournamentID = "tournamentId"
        case name
        case arenas
    }
}

private struct MatchPlayArena: Decodable {
    let opdbID: String?

    enum CodingKeys: String, CodingKey {
        case opdbID = "opdbId"
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
