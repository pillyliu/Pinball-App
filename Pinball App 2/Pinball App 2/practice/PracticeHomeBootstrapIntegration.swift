import Foundation

private let practiceLastViewedGameSnapshotKey = "practice-last-viewed-game-id"

extension PracticeStore {
    func restoreHomeBootstrapSnapshotIfAvailable() {
        guard let snapshot = PracticeHomeBootstrapSnapshotStore.load() else {
            hasRestoredHomeBootstrapSnapshot = false
            return
        }

        var bootstrapState = PracticePersistedState.empty
        bootstrapState.practiceSettings.playerName = snapshot.playerName
        bootstrapState.practiceSettings.selectedGroupID = snapshot.selectedGroupID
        bootstrapState.customGroups = snapshot.customGroups

        state = bootstrapState
        games = snapshot.visibleGames.map(\.pinballGame)
        allLibraryGames = snapshot.lookupGames.map(\.pinballGame)
        librarySources = snapshot.librarySources.map(\.librarySource)
        defaultPracticeSourceID = snapshot.selectedLibrarySourceID
        hasRestoredHomeBootstrapSnapshot = snapshot.isUsable
    }

    func saveHomeBootstrapSnapshotIfNeeded() {
        guard let snapshot = buildHomeBootstrapSnapshot() else { return }
        PracticeHomeBootstrapSnapshotStore.save(snapshot)
    }

    private func buildHomeBootstrapSnapshot() -> PracticeHomeBootstrapSnapshot? {
        let snapshot = PracticeHomeBootstrapSnapshot(
            schemaVersion: PracticeHomeBootstrapSnapshot.currentSchemaVersion,
            capturedAt: Date(),
            playerName: state.practiceSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedGroupID: state.practiceSettings.selectedGroupID,
            customGroups: state.customGroups,
            selectedLibrarySourceID: defaultPracticeSourceID,
            librarySources: librarySources.map(PracticeHomeBootstrapSnapshot.Source.init),
            visibleGames: games.map(PracticeHomeBootstrapSnapshot.Game.init),
            lookupGames: currentHomeBootstrapLookupGames().map(PracticeHomeBootstrapSnapshot.Game.init)
        )
        return snapshot.isUsable ? snapshot : nil
    }

    private func currentHomeBootstrapLookupGames() -> [PinballGame] {
        let baseGames = allLibraryGames.isEmpty ? games : allLibraryGames
        let combined = baseGames + searchCatalogGames + bankTemplateGames
        let practiceLastViewedID = UserDefaults.standard.string(forKey: practiceLastViewedGameSnapshotKey)
        let resumeCandidate = practiceLastViewedID.flatMap(gameForAnyID)

        var ordered: [PinballGame] = []
        var seenKeys: Set<String> = []

        func append(_ game: PinballGame?) {
            guard let game else { return }
            let key = sourceScopedPracticeGameID(sourceID: game.sourceId, gameID: game.canonicalPracticeKey)
            guard seenKeys.insert(key).inserted else { return }
            ordered.append(game)
        }

        append(resumeCandidate)
        combined.forEach(append)
        return ordered
    }
}
