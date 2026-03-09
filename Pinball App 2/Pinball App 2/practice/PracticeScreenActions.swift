import SwiftUI

extension PracticeScreen {
    func applyDefaultsAfterLoad() {
        if uiState.selectedGameID.isEmpty, let fallback = defaultPracticeGame {
            uiState.selectedGameID = fallback.canonicalPracticeKey
        }

        uiState.playerName = store.state.practiceSettings.playerName
        uiState.ifpaPlayerID = store.state.practiceSettings.ifpaPlayerID
        uiState.insightsOpponentName = store.state.practiceSettings.comparisonPlayerName
        uiState.leaguePlayerName = store.state.leagueSettings.playerName
        uiState.cloudSyncEnabled = store.state.syncSettings.cloudSyncEnabled

        let knownGroupIDs = Set(store.state.customGroups.map(\.id))
        if let selectedGroupID = store.state.practiceSettings.selectedGroupID,
           knownGroupIDs.contains(selectedGroupID) {
            store.setSelectedGroup(id: selectedGroupID)
        } else if let first = store.state.customGroups.first {
            store.setSelectedGroup(id: first.id)
        }
    }

    func goToGame(_ gameID: String, zoomSourceID: String? = nil) {
        guard !gameID.isEmpty else { return }
        let canonical = store.canonicalPracticeGameID(gameID)
        uiState.gameTransitionSourceID = zoomSourceID
        uiState.selectedGameID = canonical
        markPracticeGameViewed(canonical)
        let target = PracticeRoute.game(canonical)
        if uiState.gameNavigationPath.last != target {
            uiState.gameNavigationPath.append(target)
        }
    }

    func openRoute(_ route: PracticeRoute) {
        if uiState.gameNavigationPath.last != route {
            uiState.gameNavigationPath.append(route)
        }
    }

    func openRulesheet(source: RulesheetRemoteSource?, for game: PinballGame) {
        guard game.hasRulesheetResource || source != nil else { return }
        uiState.selectedGameID = store.canonicalPracticeGameID(game.canonicalPracticeKey)
        uiState.selectedRulesheetSource = source
        uiState.selectedExternalRulesheetURL = nil
        openRoute(.rulesheet)
    }

    func openExternalRulesheet(url: URL, for game: PinballGame) {
        uiState.selectedGameID = store.canonicalPracticeGameID(game.canonicalPracticeKey)
        uiState.selectedRulesheetSource = nil
        uiState.selectedExternalRulesheetURL = url
        openRoute(.rulesheet)
    }

    func openPlayfield(for game: PinballGame, candidates: [URL]? = nil) {
        let resolvedCandidates = (candidates?.isEmpty == false ? candidates : nil) ?? game.fullscreenPlayfieldCandidates
        guard !resolvedCandidates.isEmpty else { return }
        uiState.selectedGameID = store.canonicalPracticeGameID(game.canonicalPracticeKey)
        uiState.selectedPlayfieldImageURLs = resolvedCandidates
        openRoute(.playfield)
    }

    func resumeToPracticeGame(zoomSourceID: String? = nil) {
        if let game = resumeGame {
            goToGame(game.canonicalPracticeKey, zoomSourceID: zoomSourceID)
        } else if let fallback = defaultPracticeGame {
            goToGame(fallback.canonicalPracticeKey, zoomSourceID: zoomSourceID)
        }
    }

    func openQuickEntry(_ sheet: QuickEntrySheet) {
        let orderedGames = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true)
        let remembered = store.canonicalPracticeGameID(rememberedQuickEntryGame(for: sheet))
        if sheet == .mechanics {
            uiState.selectedGameID = ""
        } else if !remembered.isEmpty {
            uiState.selectedGameID = remembered
        } else if !uiState.selectedGameID.isEmpty {
            // keep current selection
        } else if let first = orderedGames.first {
            uiState.selectedGameID = first.canonicalPracticeKey
        }
        uiState.quickEntryKind = sheet
        uiState.presentedSheet = .quickEntry
    }

    func rememberedQuickEntryGame(for sheet: QuickEntrySheet) -> String {
        switch sheet {
        case .score:
            return quickScoreGameID
        case .study:
            return quickStudyGameID
        case .practice:
            return quickPracticeGameID
        case .mechanics:
            return quickMechanicsGameID
        }
    }

    func rememberQuickEntryGame(sheet: QuickEntrySheet, gameID: String) {
        let canonical = store.canonicalPracticeGameID(gameID)
        switch sheet {
        case .score:
            quickScoreGameID = canonical
        case .study:
            quickStudyGameID = canonical
        case .practice:
            quickPracticeGameID = canonical
        case .mechanics:
            quickMechanicsGameID = ""
        }
    }

    func markPracticeGameViewed(_ gameID: String) {
        let canonical = store.canonicalPracticeGameID(gameID)
        guard !canonical.isEmpty else { return }
        practiceLastViewedGameID = canonical
        practiceLastViewedGameTS = Date().timeIntervalSince1970
    }

    func openGroupEditorForSelection() {
        let selectedID = store.state.practiceSettings.selectedGroupID ?? store.state.customGroups.first?.id
        guard let selectedID else { return }
        store.setSelectedGroup(id: selectedID)
        uiState.editingGroupID = selectedID
        openRoute(.groupEditor)
    }

    func openGroupEditorForCreate() {
        uiState.editingGroupID = nil
        openRoute(.groupEditor)
    }

    func openCurrentGroupDateEditor(for groupID: UUID, field: GroupEditorDateField) {
        uiState.currentGroupDateEditorGroupID = groupID
        uiState.currentGroupDateEditorField = field
        if let group = store.state.customGroups.first(where: { $0.id == groupID }) {
            switch field {
            case .start:
                uiState.currentGroupDateEditorValue = group.startDate ?? Date()
            case .end:
                uiState.currentGroupDateEditorValue = group.endDate ?? Date()
            }
        } else {
            uiState.currentGroupDateEditorValue = Date()
        }
        uiState.presentedSheet = .groupDateEditor
    }

    func openJournalEntryEditor(_ entry: JournalEntry) {
        guard store.canEditJournalEntry(entry) else { return }
        uiState.selectedJournalItemIDs.removeAll()
        uiState.isEditingJournalEntries = false
        uiState.editingJournalEntry = entry
        uiState.presentedSheet = .journalEntryEditor
    }

    func saveEditedJournalEntry(_ entry: JournalEntry) {
        _ = store.updateJournalEntry(entry)
    }

    func deleteJournalEntries(_ entries: [JournalEntry]) {
        guard !entries.isEmpty else { return }
        let ids = Set(entries.map(\.id))
        for entry in entries {
            _ = store.deleteJournalEntry(id: entry.id)
        }
        uiState.selectedJournalItemIDs = Set(uiState.selectedJournalItemIDs.filter { itemID in
            guard let journalID = journalEntryID(fromTimelineItemID: itemID) else { return false }
            return !ids.contains(journalID)
        })
        if uiState.selectedJournalItemIDs.isEmpty {
            uiState.isEditingJournalEntries = false
        }
    }

    private func journalEntryID(fromTimelineItemID itemID: String) -> UUID? {
        let prefix = "app-"
        guard itemID.hasPrefix(prefix) else { return nil }
        let raw = String(itemID.dropFirst(prefix.count))
        return UUID(uuidString: raw)
    }

    func actionIcon(_ action: JournalActionType) -> String {
        switch action {
        case .rulesheetRead: return "book"
        case .tutorialWatch: return "play.rectangle"
        case .gameplayWatch: return "video"
        case .playfieldViewed: return "photo"
        case .gameBrowse: return "gamecontroller"
        case .practiceSession: return "figure.run"
        case .scoreLogged: return "number.circle"
        case .noteAdded: return "note.text"
        }
    }

    func libraryActivityIcon(_ kind: LibraryActivityKind) -> String {
        switch kind {
        case .browseGame:
            return "rectangle.grid.2x2"
        case .openRulesheet:
            return "book"
        case .openPlayfield:
            return "photo"
        case .tapVideo:
            return "play.rectangle"
        }
    }

    func libraryActivitySummary(_ event: LibraryActivityEvent) -> String {
        switch event.kind {
        case .browseGame:
            return "Browsed \(event.gameName) in Library"
        case .openRulesheet:
            return "Opened \(event.gameName) rulesheet from Library"
        case .openPlayfield:
            return "Opened \(event.gameName) playfield image from Library"
        case .tapVideo:
            if let detail = event.detail, !detail.isEmpty {
                return "Opened \(detail) video for \(event.gameName) in Library"
            }
            return "Opened video for \(event.gameName) in Library"
        }
    }

    func scoreTrendValues(for gameID: String) -> [Double] {
        let gameID = store.canonicalPracticeGameID(gameID)
        return store.state.scoreEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp < $1.timestamp }
            .map(\.score)
    }

    func refreshHeadToHead() async {
        guard !uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !uiState.insightsOpponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            uiState.headToHead = nil
            return
        }

        uiState.isLoadingHeadToHead = true
        defer { uiState.isLoadingHeadToHead = false }
        uiState.headToHead = await store.comparePlayers(yourName: uiState.playerName, opponentName: uiState.insightsOpponentName)
    }

    func refreshInsightsOpponentOptions() async {
        let names = await store.availableLeaguePlayers()
        let normalizedSelf = uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        uiState.insightsOpponentOptions = names.filter { $0.lowercased() != normalizedSelf }
        if !uiState.insightsOpponentName.isEmpty, !uiState.insightsOpponentOptions.contains(uiState.insightsOpponentName) {
            uiState.insightsOpponentName = ""
        }
    }

    func refreshLeaguePlayerOptions() async {
        uiState.leaguePlayerOptions = await store.availableLeaguePlayers()
        if !uiState.leaguePlayerName.isEmpty, !uiState.leaguePlayerOptions.contains(uiState.leaguePlayerName) {
            uiState.leaguePlayerName = ""
        }
    }
}
