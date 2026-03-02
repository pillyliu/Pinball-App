import Foundation

extension PracticeStore {
    private static let preferredLibrarySourceDefaultsKey = "preferred-library-source-id"
    private static let avenueSourceCandidates = ["venue--the-avenue-cafe", "the-avenue"]

    func loadGames() async {
        isLoadingGames = true
        defer { isLoadingGames = false }

        do {
            let extraction = try await loadLibraryExtraction()
            let payload = extraction.payload
            let savedSourceID = UserDefaults.standard.string(forKey: Self.preferredLibrarySourceDefaultsKey)
            let preferredCandidates = [extraction.state.selectedSourceID, savedSourceID] + Self.avenueSourceCandidates.map(Optional.some)
            let selectedSource =
                preferredCandidates.compactMap { $0 }.first(where: { id in payload.sources.contains(where: { $0.id == id }) })
                    .flatMap { id in payload.sources.first(where: { $0.id == id }) }
                ?? payload.sources.first(where: { $0.type == .venue })
                ?? payload.sources.first
            allLibraryGames = payload.games
            librarySources = payload.sources
            defaultPracticeSourceID = selectedSource?.id
            if let selectedSource {
                UserDefaults.standard.set(selectedSource.id, forKey: Self.preferredLibrarySourceDefaultsKey)
                var state = extraction.state
                state.selectedSourceID = selectedSource.id
                PinballLibrarySourceStateStore.save(state)
            }
            if let selectedSource {
                games = payload.games.filter { $0.sourceId == selectedSource.id }
            } else {
                games = payload.games
            }
        } catch {
            games = []
            allLibraryGames = []
            librarySources = []
            defaultPracticeSourceID = nil
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

            targets[LibraryGameLookup.normalizeMachineName(game)] = LeagueTargetScores(great: great, main: main, floor: floor)
        }

        return targets
    }

    func selectPracticeLibrarySource(id sourceID: String?) {
        let trimmed = sourceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selectedSource = librarySources.first { $0.id == trimmed }
        let pool = allLibraryGames.isEmpty ? games : allLibraryGames
        if let selectedSource {
            games = pool.filter { $0.sourceId == selectedSource.id }
            defaultPracticeSourceID = selectedSource.id
            UserDefaults.standard.set(selectedSource.id, forKey: Self.preferredLibrarySourceDefaultsKey)
            var state = PinballLibrarySourceStateStore.load()
            state.selectedSourceID = selectedSource.id
            PinballLibrarySourceStateStore.save(state)
        } else {
            games = pool
            defaultPracticeSourceID = nil
            UserDefaults.standard.removeObject(forKey: Self.preferredLibrarySourceDefaultsKey)
            var state = PinballLibrarySourceStateStore.load()
            state.selectedSourceID = nil
            PinballLibrarySourceStateStore.save(state)
        }
    }
}
