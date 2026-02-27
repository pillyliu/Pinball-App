import SwiftUI

struct PracticeScreen: View {
    @StateObject var store = PracticeStore()
    @EnvironmentObject var appNavigation: AppNavigationModel
    @Namespace var gameTransition

    @State var selectedGameID: String = ""
    @State var gameNavigationPath: [PracticeNavRoute] = []
    @State var openPracticeSettings = false
    @State var openGroupEditor = false
    @State var editingGroupID: UUID?
    @State var openCurrentGroupDateEditor = false
    @State var currentGroupDateEditorGroupID: UUID?
    @State var currentGroupDateEditorField: GroupEditorDateField = .start
    @State var currentGroupDateEditorValue: Date = Date()
    @State var gameTransitionSourceID: String?
    @State var quickSheet: QuickEntrySheet?
    @State var isEditingJournalEntries = false
    @State var selectedJournalItemIDs: Set<String> = []
    @State var editingJournalEntry: JournalEntry?

    @AppStorage("practice-journal-filter") var journalFilterRaw: String = JournalFilter.all.rawValue
    @AppStorage("practice-quick-game-score") var quickScoreGameID: String = ""
    @AppStorage("practice-quick-game-study") var quickStudyGameID: String = ""
    @AppStorage("practice-quick-game-practice") var quickPracticeGameID: String = ""
    @AppStorage("practice-quick-game-mechanics") var quickMechanicsGameID: String = ""
    @AppStorage("practice-last-viewed-game-id") var practiceLastViewedGameID: String = ""
    @AppStorage("practice-last-viewed-game-ts") var practiceLastViewedGameTS: Double = 0
    @AppStorage("library-last-viewed-game-ts") var libraryLastViewedGameTS: Double = 0
    @AppStorage("practice-name-prompted") var practiceNamePrompted = false

    @State var selectedMechanicSkill: String = ""
    @State var mechanicsComfort: Double = 3
    @State var mechanicsNote: String = ""

    @State var playerName: String = ""
    @State var insightsOpponentName: String = ""
    @State var insightsOpponentOptions: [String] = []
    @State var leaguePlayerName: String = ""
    @State var leaguePlayerOptions: [String] = []
    @State var leagueImportStatus: String = ""
    @State var cloudSyncEnabled = false
    @State var showingNamePrompt = false
    @State var firstNamePromptValue: String = ""
    @State var importLplStatsOnNameSave = true
    @State var showingResetJournalPrompt = false
    @State var resetJournalConfirmationText: String = ""
    @State var headToHead: HeadToHeadComparison?
    @State var isLoadingHeadToHead = false
    @State var viewportHeight: CGFloat = 0
    @State var hasRunInitialPracticeLoad = false
    struct TimelineItem: Identifiable {
        let id: String
        let gameID: String
        let summary: String
        let icon: String
        let timestamp: Date
        let journalEntry: JournalEntry?
    }

    var resumeGame: PinballGame? {
        let libraryID = appNavigation.lastViewedLibraryGameID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let practiceID = practiceLastViewedGameID.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateID: String
        if libraryLastViewedGameTS >= practiceLastViewedGameTS {
            candidateID = libraryID.isEmpty ? practiceID : libraryID
        } else {
            candidateID = practiceID.isEmpty ? libraryID : practiceID
        }
        if !candidateID.isEmpty,
           let match = store.gameForAnyID(candidateID) {
            return match
        }
        return defaultPracticeGame
    }

    var defaultPracticeGame: PinballGame? {
        return orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first
    }

    var selectedGroup: CustomGameGroup? {
        store.selectedGroup()
    }

    var greetingName: String? {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let redacted = redactPlayerNameForDisplay(trimmed)
        if redacted != trimmed {
            return redacted
        }
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return first.isEmpty ? nil : first
    }

    var filteredJournalEntries: [JournalEntry] {
        let all = store.allJournalEntries()
        switch journalFilter {
        case .all:
            return all
        case .study:
            return all.filter { [.rulesheetRead, .tutorialWatch, .gameplayWatch, .playfieldViewed].contains($0.action) }
        case .practice:
            return all.filter { $0.action == .practiceSession }
        case .score:
            return all.filter { $0.action == .scoreLogged }
        case .notes:
            return all.filter { $0.action == .noteAdded }
        case .league:
            return all.filter { entry in
                entry.action == .scoreLogged && (entry.scoreContext == .league || (entry.note ?? "").localizedCaseInsensitiveContains("league import"))
            }
        }
    }

    var filteredLibraryActivities: [LibraryActivityEvent] {
        let all = LibraryActivityLog.events()
        switch journalFilter {
        case .all:
            return all
        case .study:
            return all.filter { [.openRulesheet, .openPlayfield, .tapVideo].contains($0.kind) }
        case .practice, .score, .notes, .league:
            return []
        }
    }

    var timelineItems: [TimelineItem] {
        let appItems = filteredJournalEntries.map { entry in
            TimelineItem(
                id: "app-\(entry.id.uuidString)",
                gameID: entry.gameID,
                summary: store.journalSummary(for: entry),
                icon: actionIcon(entry.action),
                timestamp: entry.timestamp,
                journalEntry: entry
            )
        }
        let libraryItems = filteredLibraryActivities.map { event in
            TimelineItem(
                id: "library-\(event.id.uuidString)",
                gameID: event.gameID,
                summary: libraryActivitySummary(event),
                icon: libraryActivityIcon(event.kind),
                timestamp: event.timestamp,
                journalEntry: nil
            )
        }
        return (appItems + libraryItems).sorted { $0.timestamp > $1.timestamp }
    }

    var journalSectionItems: [PracticeJournalItem] {
        timelineItems.map { item in
            PracticeJournalItem(
                id: item.id,
                gameID: item.gameID,
                summary: item.summary,
                icon: item.icon,
                timestamp: item.timestamp,
                journalEntry: item.journalEntry
            )
        }
    }

    var journalFilter: JournalFilter {
        JournalFilter(rawValue: journalFilterRaw) ?? .all
    }

    var body: some View {
        NavigationStack(path: $gameNavigationPath) {
            practiceDialogHost(practiceRootContent)
        }
    }

    func applyDefaultsAfterLoad() {
        if selectedGameID.isEmpty, let fallback = defaultPracticeGame {
            selectedGameID = fallback.canonicalPracticeKey
        }

        playerName = store.state.practiceSettings.playerName
        insightsOpponentName = store.state.practiceSettings.comparisonPlayerName
        leaguePlayerName = store.state.leagueSettings.playerName
        cloudSyncEnabled = store.state.syncSettings.cloudSyncEnabled

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
        gameTransitionSourceID = zoomSourceID
        selectedGameID = canonical
        markPracticeGameViewed(canonical)
        let target = PracticeNavRoute.game(canonical)
        if gameNavigationPath.last != target {
            gameNavigationPath.append(target)
        }
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
            selectedGameID = ""
        } else if !remembered.isEmpty {
            selectedGameID = remembered
        } else if !selectedGameID.isEmpty {
            // keep current selection
        } else if let first = orderedGames.first {
            selectedGameID = first.canonicalPracticeKey
        }
        quickSheet = sheet
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
        editingGroupID = selectedID
        openGroupEditor = true
    }
    func openGroupEditorForCreate() {
        editingGroupID = nil
        openGroupEditor = true
    }
    func openCurrentGroupDateEditor(for groupID: UUID, field: GroupEditorDateField) {
        currentGroupDateEditorGroupID = groupID
        currentGroupDateEditorField = field
        if let group = store.state.customGroups.first(where: { $0.id == groupID }) {
            switch field {
            case .start:
                currentGroupDateEditorValue = group.startDate ?? Date()
            case .end:
                currentGroupDateEditorValue = group.endDate ?? Date()
            }
        } else {
            currentGroupDateEditorValue = Date()
        }
        openCurrentGroupDateEditor = true
    }
    func openJournalEntryEditor(_ entry: JournalEntry) {
        guard store.canEditJournalEntry(entry) else { return }
        selectedJournalItemIDs.removeAll()
        isEditingJournalEntries = false
        editingJournalEntry = entry
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
        selectedJournalItemIDs = Set(selectedJournalItemIDs.filter { itemID in
            guard let journalID = journalEntryID(fromTimelineItemID: itemID) else { return false }
            return !ids.contains(journalID)
        })
        if selectedJournalItemIDs.isEmpty {
            isEditingJournalEntries = false
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
        guard !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !insightsOpponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            headToHead = nil
            return
        }

        isLoadingHeadToHead = true
        defer { isLoadingHeadToHead = false }
        headToHead = await store.comparePlayers(yourName: playerName, opponentName: insightsOpponentName)
    }
    func refreshInsightsOpponentOptions() async {
        let names = await store.availableLeaguePlayers()
        let normalizedSelf = playerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        insightsOpponentOptions = names.filter { $0.lowercased() != normalizedSelf }
        if !insightsOpponentName.isEmpty, !insightsOpponentOptions.contains(insightsOpponentName) {
            insightsOpponentName = ""
        }
    }
    func refreshLeaguePlayerOptions() async {
        leaguePlayerOptions = await store.availableLeaguePlayers()
        if !leaguePlayerName.isEmpty, !leaguePlayerOptions.contains(leaguePlayerName) {
            leaguePlayerName = ""
        }
    }

}


#Preview {
    PracticeScreen()
}
