import Foundation

extension PracticeStore {
    func loadGames() async {
        isLoadingGames = true
        defer { isLoadingGames = false }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.libraryPath)
            guard let text = cached.text,
                  let data = text.data(using: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }
            let payload = try decodeLibraryPayload(data: data)
            let selectedSource = payload.sources.first(where: { $0.type == .venue }) ?? payload.sources.first
            if let selectedSource {
                games = payload.games.filter { $0.sourceId == selectedSource.id }
            } else {
                games = payload.games
            }
        } catch {
            games = []
            lastErrorMessage = "Failed to load library for practice upgrade: \(error.localizedDescription)"
        }
    }

    func loadLeagueTargets() async {
        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueTargetsPath, allowMissing: true)
            guard let text = cached.text, !text.isEmpty else {
                leagueTargetsByNormalizedMachine = [:]
                return
            }
            leagueTargetsByNormalizedMachine = parseLeagueTargets(text: text)
        } catch {
            leagueTargetsByNormalizedMachine = [:]
        }
    }

    func parseLeagueTargets(text: String) -> [String: LeagueTargetScores] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [:] }

        let headers = header.map(normalizeCSVHeader)
        guard let gameIndex = headers.firstIndex(of: "game"),
              let secondIndex = headers.firstIndex(of: "second_highest_avg"),
              let fourthIndex = headers.firstIndex(of: "fourth_highest_avg"),
              let eighthIndex = headers.firstIndex(of: "eighth_highest_avg") else {
            return [:]
        }

        var targets: [String: LeagueTargetScores] = [:]
        for row in table.dropFirst() {
            guard row.indices.contains(gameIndex),
                  row.indices.contains(secondIndex),
                  row.indices.contains(fourthIndex),
                  row.indices.contains(eighthIndex) else {
                continue
            }

            let game = row[gameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !game.isEmpty else { continue }

            let second = row[secondIndex].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let fourth = row[fourthIndex].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let eighth = row[eighthIndex].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let great = Double(second), let main = Double(fourth), let floor = Double(eighth) else { continue }

            targets[normalizeMachineName(game)] = LeagueTargetScores(great: great, main: main, floor: floor)
        }

        return targets
    }
}
