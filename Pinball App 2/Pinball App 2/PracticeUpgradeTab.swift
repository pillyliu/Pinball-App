import SwiftUI
import UniformTypeIdentifiers

private enum PracticeHubDestination: String, CaseIterable, Identifiable, Hashable {
    case groupDashboard
    case journal
    case insights
    case mechanics

    var id: String { rawValue }

    var label: String {
        switch self {
        case .groupDashboard: return "Group Dashboard"
        case .journal: return "Journal Timeline"
        case .insights: return "Insights"
        case .mechanics: return "Mechanics"
        }
    }

    var subtitle: String {
        switch self {
        case .groupDashboard: return "Focus set, suggested game, and per-game progress"
        case .journal: return "Full app activity history"
        case .insights: return "Scores, variance, and trend context"
        case .mechanics: return "Track transferable pinball skill practice"
        }
    }

    var icon: String {
        switch self {
        case .groupDashboard: return "square.grid.2x2"
        case .journal: return "list.bullet.rectangle"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .mechanics: return "circle.fill"
        }
    }
}

private enum PracticeNavRoute: Hashable {
    case destination(PracticeHubDestination)
    case game(String)
}

private enum QuickEntrySheet: String, Identifiable {
    case score
    case study
    case practice
    case mechanics

    var id: String { rawValue }

    var title: String {
        "Quick Entry"
    }

    var defaultActivity: QuickEntryActivity {
        switch self {
        case .score: return .score
        case .study: return .rulesheet
        case .practice: return .practice
        case .mechanics: return .mechanics
        }
    }
}

private enum QuickEntryActivity: String, CaseIterable, Identifiable {
    case score
    case rulesheet
    case tutorialVideo
    case gameplayVideo
    case playfield
    case practice
    case mechanics

    var id: String { rawValue }

    var label: String {
        switch self {
        case .score: return "Score"
        case .rulesheet: return "Rulesheet"
        case .tutorialVideo: return "Tutorial Video"
        case .gameplayVideo: return "Gameplay Video"
        case .playfield: return "Playfield Image"
        case .practice: return "Practice"
        case .mechanics: return "Mechanics"
        }
    }

    var asTask: StudyTaskKind? {
        switch self {
        case .rulesheet: return .rulesheet
        case .tutorialVideo: return .tutorialVideo
        case .gameplayVideo: return .gameplayVideo
        case .playfield: return .playfield
        case .practice: return .practice
        case .mechanics: return nil
        case .score: return nil
        }
    }
}

private enum JournalFilter: String, CaseIterable, Identifiable {
    case all
    case study
    case practice
    case score
    case notes
    case league

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .study: return "Study"
        case .practice: return "Practice"
        case .score: return "Scores"
        case .notes: return "Notes"
        case .league: return "League"
        }
    }
}

struct PracticeUpgradeTab: View {
    @StateObject private var store = PracticeUpgradeStore()
    @EnvironmentObject private var appNavigation: AppNavigationModel
    @Namespace private var gameTransition

    @State private var selectedGameID: String = ""
    @State private var gameNavigationPath: [PracticeNavRoute] = []
    @State private var openPracticeSettings = false
    @State private var openGroupEditor = false
    @State private var editingGroupID: UUID?
    @State private var openCurrentGroupDateEditor = false
    @State private var currentGroupDateEditorGroupID: UUID?
    @State private var currentGroupDateEditorField: GroupEditorDateField = .start
    @State private var currentGroupDateEditorValue: Date = Date()
    @State private var quickSheet: QuickEntrySheet?

    @AppStorage("practice-journal-filter") private var journalFilterRaw: String = JournalFilter.all.rawValue
    @AppStorage("practice-quick-game-score") private var quickScoreGameID: String = ""
    @AppStorage("practice-quick-game-study") private var quickStudyGameID: String = ""
    @AppStorage("practice-quick-game-practice") private var quickPracticeGameID: String = ""
    @AppStorage("practice-quick-game-mechanics") private var quickMechanicsGameID: String = ""
    @AppStorage("practice-last-viewed-game-id") private var practiceLastViewedGameID: String = ""
    @AppStorage("practice-last-viewed-game-ts") private var practiceLastViewedGameTS: Double = 0
    @AppStorage("library-last-viewed-game-ts") private var libraryLastViewedGameTS: Double = 0
    @AppStorage("practice-name-prompted") private var practiceNamePrompted = false

    @State private var selectedMechanicSkill: String = ""
    @State private var mechanicsComfort: Double = 3
    @State private var mechanicsNote: String = ""

    @State private var playerName: String = ""
    @State private var insightsOpponentName: String = ""
    @State private var insightsOpponentOptions: [String] = []
    @State private var leaguePlayerName: String = ""
    @State private var leaguePlayerOptions: [String] = []
    @State private var leagueImportStatus: String = ""
    @State private var cloudSyncEnabled = false
    @State private var showingNamePrompt = false
    @State private var firstNamePromptValue: String = ""
    @State private var showingResetJournalPrompt = false
    @State private var resetJournalConfirmationText: String = ""
    @State private var headToHead: HeadToHeadComparison?
    @State private var isLoadingHeadToHead = false
    @State private var viewportHeight: CGFloat = 0

    private struct TimelineItem: Identifiable {
        let id: String
        let gameID: String
        let summary: String
        let icon: String
        let timestamp: Date
    }

    private var selectedGame: PinballGame? {
        store.games.first(where: { $0.id == selectedGameID })
    }

    private var resumeGame: PinballGame? {
        let libraryID = appNavigation.lastViewedLibraryGameID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let practiceID = practiceLastViewedGameID.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateID: String
        if libraryLastViewedGameTS >= practiceLastViewedGameTS {
            candidateID = libraryID.isEmpty ? practiceID : libraryID
        } else {
            candidateID = practiceID.isEmpty ? libraryID : practiceID
        }
        if !candidateID.isEmpty,
           let match = store.games.first(where: { $0.id == candidateID }) {
            return match
        }
        return nil
    }

    private var selectedGroup: CustomGameGroup? {
        store.selectedGroup()
    }

    private var greetingName: String? {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return first.isEmpty ? nil : first
    }

    private var filteredJournalEntries: [JournalEntry] {
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

    private var filteredLibraryActivities: [LibraryActivityEvent] {
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

    private var timelineItems: [TimelineItem] {
        let appItems = filteredJournalEntries.map { entry in
            TimelineItem(
                id: "app-\(entry.id.uuidString)",
                gameID: entry.gameID,
                summary: store.journalSummary(for: entry),
                icon: actionIcon(entry.action),
                timestamp: entry.timestamp
            )
        }
        let libraryItems = filteredLibraryActivities.map { event in
            TimelineItem(
                id: "library-\(event.id.uuidString)",
                gameID: event.gameID,
                summary: libraryActivitySummary(event),
                icon: libraryActivityIcon(event.kind),
                timestamp: event.timestamp
            )
        }
        return (appItems + libraryItems).sorted { $0.timestamp > $1.timestamp }
    }

    private var journalFilter: JournalFilter {
        JournalFilter(rawValue: journalFilterRaw) ?? .all
    }

    var body: some View {
        NavigationStack(path: $gameNavigationPath) {
            ZStack {
                AppBackground()

                if store.isLoadingGames {
                    ProgressView("Loading practice data...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(greetingName == nil ? "Welcome back" : "Welcome back, \(greetingName!)")
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                Button {
                                    openPracticeSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                                .buttonStyle(.glass)
                            }
                            .padding(.leading, 8)

                            practiceHomeCard

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(PracticeHubDestination.allCases) { destination in
                                    NavigationLink(value: PracticeNavRoute.destination(destination)) {
                                        PracticeHubMiniCard(destination: destination)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                if showingNamePrompt {
                    Color.black.opacity(0.30)
                        .ignoresSafeArea()

                    practiceWelcomeOverlay
                        .padding(.horizontal, 20)
                        .frame(maxWidth: 560)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            viewportHeight = geo.size.height
                        }
                        .onChange(of: geo.size.height) { _, newHeight in
                            viewportHeight = newHeight
                        }
                }
            )
            .sheet(item: $quickSheet) { kind in
                QuickEntrySheetView(
                    kind: kind,
                    store: store,
                    selectedGameID: $selectedGameID,
                    onGameSelectionChanged: { sheet, gameID in
                        rememberQuickEntryGame(sheet: sheet, gameID: gameID)
                    },
                    onEntrySaved: { gameID in
                        markPracticeGameViewed(gameID)
                    }
                )
            }
            .navigationDestination(for: PracticeNavRoute.self) { route in
                switch route {
                case .destination(let destination):
                    destinationView(for: destination)
                case .game(let gameID):
                    PracticeGameWorkspace(store: store, selectedGameID: $selectedGameID, onGameViewed: { viewedGameID in
                        markPracticeGameViewed(viewedGameID)
                    })
                        .onAppear { selectedGameID = gameID }
                        .navigationTransition(.zoom(sourceID: gameID, in: gameTransition))
                }
            }
            .navigationDestination(isPresented: $openPracticeSettings) {
                practiceScreen("Practice Settings") {
                    settingsScreen
                }
                .alert("Reset Practice Log?", isPresented: $showingResetJournalPrompt) {
                    TextField("Type reset", text: $resetJournalConfirmationText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("No", role: .cancel) {}
                    Button("Yes, Reset", role: .destructive) {
                        resetJournalConfirmationText = ""
                        store.resetPracticeState()
                        applyDefaultsAfterLoad()
                        LibraryActivityLog.clearAll()
                    }
                    .disabled(resetJournalConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "reset")
                } message: {
                    Text("This resets the full local Practice JSON log state. Type \"reset\" to enable confirmation.")
                }
            }
            .sheet(isPresented: $openGroupEditor) {
                NavigationStack {
                    GroupEditorScreen(
                        store: store,
                        editingGroupID: editingGroupID
                    ) {
                        openGroupEditor = false
                        editingGroupID = nil
                    }
                }
            }
            .sheet(isPresented: $openCurrentGroupDateEditor) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker(
                            currentGroupDateEditorField == .start ? "Start Date" : "End Date",
                            selection: $currentGroupDateEditorValue,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)

                        HStack {
                            Button("Clear", role: .destructive) {
                                guard let groupID = currentGroupDateEditorGroupID else {
                                    openCurrentGroupDateEditor = false
                                    return
                                }
                                switch currentGroupDateEditorField {
                                case .start:
                                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: nil)
                                case .end:
                                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: nil)
                                }
                                openCurrentGroupDateEditor = false
                            }
                            .buttonStyle(.glass)

                            Spacer()

                            Button("Save") {
                                guard let groupID = currentGroupDateEditorGroupID else {
                                    openCurrentGroupDateEditor = false
                                    return
                                }
                                switch currentGroupDateEditorField {
                                case .start:
                                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: currentGroupDateEditorValue)
                                case .end:
                                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: currentGroupDateEditorValue)
                                }
                                openCurrentGroupDateEditor = false
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppBackground())
                    .navigationTitle(currentGroupDateEditorField == .start ? "Set Start Date" : "Set End Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                openCurrentGroupDateEditor = false
                            }
                        }
                    }
                }
            }
            .task {
                await store.loadIfNeeded()
                applyDefaultsAfterLoad()
                await refreshLeaguePlayerOptions()
                await refreshHeadToHead()
                let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    firstNamePromptValue = ""
                    showingNamePrompt = true
                }
            }
            .onChange(of: appNavigation.lastViewedLibraryGameID) { _, newValue in
                let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmed.isEmpty else { return }
                libraryLastViewedGameTS = Date().timeIntervalSince1970
            }
        }
    }

    private var practiceHomeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if let game = resumeGame {
                    Text("Resume")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            resumeToPracticeGame()
                        } label: {
                            resumeChip(game.name)
                        }
                        .buttonStyle(.plain)

                        Menu {
                            ForEach(store.games) { listGame in
                                Button(listGame.name) {
                                    goToGame(listGame.id)
                                }
                            }
                        } label: {
                            resumeChip("Other game", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    quickActionButton("Score", icon: "number.circle", action: { openQuickEntry(.score) })
                    quickActionButton("Study", icon: "book.circle", action: { openQuickEntry(.study) })
                    quickActionButton("Practice", icon: "figure.run.circle", action: { openQuickEntry(.practice) })
                    quickActionButton("Mechanics", icon: "circle.fill", action: { openQuickEntry(.mechanics) })
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 6) {
                Text("Active Groups")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                let allGroups = store.state.customGroups
                let orderedGroups = allGroups.filter(\.isActive)

                if orderedGroups.isEmpty {
                    Text("No active groups")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(orderedGroups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(group.name)
                                        .font(.subheadline.weight(.semibold))
                                    if group.id == selectedGroup?.id {
                                        Text("Selected")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.14), in: Capsule())
                                    }
                                }

                                let groupGames = store.groupGames(for: group)
                                if groupGames.isEmpty {
                                    Text("No games in this group.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(groupGames) { game in
                                                Button {
                                                    goToGame(game.id)
                                                } label: {
                                                    SelectedGameMiniCard(game: game)
                                                        .matchedTransitionSource(id: game.id, in: gameTransition)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var practiceWelcomeOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Practice")
                .font(.headline)

            Text("Enter your player name to get started.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Player name", text: $firstNamePromptValue)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            VStack(alignment: .leading, spacing: 8) {
                overlaySectionRow("Home", detail: "Return to game, quick entry, active groups")
                overlaySectionRow("Group Dashboard", detail: "View and manage game study groups")
                overlaySectionRow("Insights", detail: "Score trends, consistency, and head-to-head.")
                overlaySectionRow("Journal Timeline", detail: "Practice and library activity history.")
                overlaySectionRow("Game View", detail: "Game resources and study log")
            }
            .padding(.top, 2)

            HStack {
                Button("Not now") {
                    practiceNamePrompted = true
                    showingNamePrompt = false
                }
                .buttonStyle(.glass)

                Spacer()

                Button("Save") {
                    let trimmed = firstNamePromptValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    playerName = trimmed
                    store.updatePracticeSettings(playerName: trimmed)
                    practiceNamePrompted = true
                    showingNamePrompt = false
                }
                .buttonStyle(.glass)
                .disabled(firstNamePromptValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appPanelStyle()
    }

    private func overlaySectionRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent Activity")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink(value: PracticeNavRoute.destination(.journal)) { Text("View all") }
                .font(.footnote)
            }

            let entries = Array(store.allJournalEntries().prefix(6))
            if entries.isEmpty {
                Text("No activity yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.journalSummary(for: entry))
                            .font(.subheadline)
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    @ViewBuilder
    private func destinationView(for destination: PracticeHubDestination) -> some View {
        switch destination {
        case .groupDashboard:
            practiceScreen("Group Dashboard") {
                groupDashboardScreen
            }
        case .journal:
            practiceViewportScreen("Journal Timeline") {
                journalScreen
            }
        case .insights:
            practiceScreen("Insights") {
                insightsScreen
            }
        case .mechanics:
            practiceScreen("Mechanics") {
                mechanicsScreen
            }
        }
    }

    private func practiceScreen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(AppBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func practiceViewportScreen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupDashboardScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupListCard

            if let group = selectedGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.name)
                        .font(.headline)

                    HStack(spacing: 8) {
                        statusChip(group.isActive ? "Active" : "Inactive", color: group.isActive ? .green : .secondary)
                        statusChip(group.type.label, color: .secondary)
                        if group.isPriority {
                            statusChip("Priority", color: .orange)
                        }
                        if let start = group.startDate {
                            statusChip("\(formatGroupDate(start))", color: .secondary, font: .caption2)
                        }
                        if let end = group.endDate {
                            statusChip("\(formatGroupDate(end))", color: .secondary, font: .caption2)
                        }
                    }

                    let score = store.groupDashboardScore(for: group)
                    HStack(spacing: 8) {
                        MetricPill(label: "Completion", value: "\(score.completionAverage)%")
                        MetricPill(label: "Stale", value: "\(score.staleGameCount)")
                        MetricPill(label: "Variance Risk", value: "\(score.weakerGameCount)")
                    }

                    if let suggested = store.recommendedGame(in: group) {
                        Button {
                            goToGame(suggested.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Suggested Practice Game")
                                        .font(.footnote.weight(.semibold))
                                    Text(suggested.name)
                                        .font(.subheadline)
                                    Text("Historically weaker and/or recently neglected.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .appControlStyle()
                            .matchedTransitionSource(id: suggested.id, in: gameTransition)
                        }
                        .buttonStyle(.plain)
                    }

                    let snapshots = store.groupProgress(for: group)
                    if snapshots.isEmpty {
                        Text("No games in this group yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshots) { snapshot in
                            Button {
                                goToGame(snapshot.game.id)
                            } label: {
                                HStack(spacing: 10) {
                                    GroupProgressWheel(taskProgress: snapshot.taskProgress)
                                        .frame(width: 46, height: 46)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(snapshot.game.name)
                                            .font(.footnote.weight(.semibold))
                                        Text(progressSummary(taskProgress: snapshot.taskProgress))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .matchedTransitionSource(id: snapshot.game.id, in: gameTransition)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.removeGame(snapshot.game.id, fromGroup: group.id)
                                } label: {
                                    Label("Delete Game", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .appPanelStyle()
            } else {
                Text("Create or select a group to populate the dashboard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .appPanelStyle()
            }
        }
    }

    private var groupListCard: some View {
        let effectiveSelectedID = selectedGroup?.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Groups")
                    .font(.headline)
                Spacer()
                Button {
                    openGroupEditorForCreate()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)

                Button {
                    openGroupEditorForSelection()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.glass)
                .disabled(effectiveSelectedID == nil)
            }

            if store.state.customGroups.isEmpty {
                Text("No groups yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Priority").frame(width: 50, alignment: .center)
                        Text("Start").frame(width: 78, alignment: .center)
                        Text("End").frame(width: 78, alignment: .center)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    ForEach(store.state.customGroups) { group in
                        HStack {
                            Button {
                                store.setSelectedGroup(id: group.id)
                            } label: {
                                Text(group.name)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        effectiveSelectedID == group.id
                                            ? Color.white.opacity(0.18)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.updateGroup(id: group.id, isPriority: !group.isPriority)
                            } label: {
                                Image(systemName: group.isPriority ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(group.isPriority ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 54, alignment: .center)

                            Button {
                                openCurrentGroupDateEditor(for: group.id, field: .start)
                            } label: {
                                Text(formattedDashboardDate(group.startDate))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 78, alignment: .center)

                            Button {
                                openCurrentGroupDateEditor(for: group.id, field: .end)
                            } label: {
                                Text(formattedDashboardDate(group.endDate))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 78, alignment: .center)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var journalScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Filter", selection: Binding(
                get: { journalFilter },
                set: { journalFilterRaw = $0.rawValue }
            )) {
                ForEach(JournalFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                if timelineItems.isEmpty {
                    Text("No matching journal events.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    let grouped = Dictionary(grouping: timelineItems) { Calendar.current.startOfDay(for: $0.timestamp) }
                    let days = grouped.keys.sorted(by: >)

                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                            ForEach(days, id: \.self) { day in
                                Section {
                                    ForEach(grouped[day] ?? []) { entry in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: entry.icon)
                                                .font(.caption)
                                                .frame(width: 14)
                                                .foregroundStyle(.secondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.summary)
                                                    .font(.footnote)
                                                    .foregroundStyle(.primary)
                                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            goToGame(entry.gameID)
                                        }
                                        .matchedTransitionSource(id: "\(entry.gameID)-\(entry.id)", in: gameTransition)
                                    }
                                } header: {
                                    Text(day.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.ultraThinMaterial.opacity(0.85))
                                }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var insightsScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            insightsGameDropdown

            VStack(alignment: .leading, spacing: 8) {
                Text("Stats")
                    .font(.headline)

                if let gameID = selectedGame?.id,
                   let summary = store.scoreSummary(for: gameID) {
                    Text("Average: \(formattedScore(summary.average))")
                    Text("Median: \(formattedScore(summary.median))")
                    Text("Floor: \(formattedScore(summary.floor))")
                    Text("IQR: \(formattedScore(summary.p25)) to \(formattedScore(summary.p75))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    let timeline = store.timelineSummary(for: gameID, gapMode: store.state.analyticsSettings.gapMode)
                    Text("Mode: \(timeline.modeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        let spreadRatio = summary.median > 0 ? (summary.p75 - summary.floor) / summary.median : 0
                        MetricPill(label: "Consistency", value: spreadRatio >= 0.6 ? "High Risk" : "Stable")
                        MetricPill(label: "Floor", value: formattedScore(summary.floor))
                        MetricPill(label: "Median", value: formattedScore(summary.median))
                    }

                    ScoreTrendSparkline(values: scoreTrendValues(for: gameID))
                        .frame(height: 180)
                } else {
                    Text("Log scores to unlock trends and consistency analytics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Head-to-Head")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await refreshHeadToHead() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingHeadToHead)
                }

                insightsOpponentDropdown

                if isLoadingHeadToHead {
                    ProgressView("Loading player comparison...")
                        .font(.footnote)
                } else if insightsOpponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Select a player above to enable player-vs-player views.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let scoped = scopedHeadToHeadComparison() {
                    HStack(spacing: 8) {
                        MetricPill(label: "Games", value: "\(scoped.totalGamesCompared)")
                        MetricPill(label: "You Lead", value: "\(scoped.gamesYouLeadByMean)")
                        MetricPill(label: "Avg Delta", value: signedScore(scoped.averageMeanDelta))
                    }

                    ForEach(Array(scoped.games.prefix(8))) { game in
                        HeadToHeadGameRow(game: game)
                    }
                    if scoped.games.count > 8 {
                        Text("Showing top 8 by mean delta.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let chartGames = Array(scoped.games.prefix(8))
                    HeadToHeadDeltaBars(games: chartGames)
                        .frame(height: headToHeadPlotHeight(for: chartGames.count))
                } else {
                    Text("No shared machine history yet between \(playerName.isEmpty ? "you" : playerName) and \(insightsOpponentName).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .task {
            await refreshInsightsOpponentOptions()
        }
        .task(id: "\(playerName)|\(insightsOpponentName)") {
            await refreshHeadToHead()
        }
    }

    private var mechanicsScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mechanics")
                    .font(.headline)
                Text("Skills are tracked as tags in your notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Skill", selection: $selectedMechanicSkill) {
                    ForEach(store.allTrackedMechanicsSkills(), id: \.self) { skill in
                        Text(skill).tag(skill)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Competency")
                    Spacer()
                    Text("\(Int(mechanicsComfort))/5")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $mechanicsComfort, in: 1...5, step: 1)

                TextField("Mechanics note (ex: #dropcatch felt consistent)", text: $mechanicsNote, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                let detected = store.detectedMechanicsTags(in: mechanicsNote)
                if !detected.isEmpty {
                    Text("Detected tags: \(detected.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Log Mechanics Session") {
                    let targetGameID = selectedGameID.isEmpty ? (store.games.first?.id ?? "") : selectedGameID
                    guard !targetGameID.isEmpty else { return }

                    let prefix = selectedMechanicSkill.isEmpty ? "#mechanics" : "#\(selectedMechanicSkill.replacingOccurrences(of: " ", with: ""))"
                    let note = "\(prefix) competency \(Int(mechanicsComfort))/5. \(mechanicsNote)"
                    store.addNote(gameID: targetGameID, category: .general, detail: selectedMechanicSkill, note: note)
                    mechanicsNote = ""
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            if !selectedMechanicSkill.isEmpty {
                let summary = store.mechanicsSummary(for: selectedMechanicSkill)
                let logs = store.mechanicsLogs(for: selectedMechanicSkill)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedMechanicSkill) History")
                        .font(.headline)

                    HStack(spacing: 8) {
                        MetricPill(label: "Logs", value: "\(summary.totalLogs)")
                        MetricPill(label: "Latest", value: summary.latestComfort.map { "\($0)/5" } ?? "-")
                        MetricPill(label: "Avg", value: summary.averageComfort.map { String(format: "%.1f/5", $0) } ?? "-")
                        MetricPill(label: "Trend", value: summary.trendDelta.map { signedCompact($0) } ?? "-")
                    }

                    MechanicsTrendSparkline(logs: logs)
                        .frame(height: 54)

                    if logs.isEmpty {
                        Text("No sessions logged for this skill yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(logs.reversed())) { log in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(log.note)
                                            .font(.footnote)
                                        Text("\(log.timestamp.formatted(date: .abbreviated, time: .shortened)) • \(store.gameName(for: log.gameID))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if log.id != logs.first?.id {
                                        Divider().overlay(.white.opacity(0.14))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: mechanicsHistoryMaxHeight())
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .appPanelStyle()
            }

            if let tutorialsURL = URL(string: "https://www.deadflip.com/tutorials") {
                Link("Dead Flip Tutorials", destination: tutorialsURL)
                    .buttonStyle(.glass)
            }
        }
    }

    private var settingsScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Practice Profile")
                    .font(.headline)

                TextField("Player name", text: $playerName)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                Button("Save Profile") {
                    store.updatePracticeSettings(playerName: playerName)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("League Import")
                    .font(.headline)

                Menu {
                    if leaguePlayerOptions.isEmpty {
                        Text("No player names found")
                    } else {
                        ForEach(leaguePlayerOptions, id: \.self) { name in
                            Button(name) {
                                leaguePlayerName = name
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(leaguePlayerName.isEmpty ? "Select league player" : leaguePlayerName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()
                }

                Text("Used when you tap Import LPL CSV.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Import LPL CSV") {
                    Task {
                        store.updateLeagueSettings(playerName: leaguePlayerName, csvAutoFillEnabled: true)
                        let result = await store.importLeagueScoresFromCSV()
                        leagueImportStatus = result.summaryLine
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.glass)
                .disabled(leaguePlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !leagueImportStatus.isEmpty {
                    Text(leagueImportStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Defaults")
                    .font(.headline)

                Toggle("Enable optional cloud sync", isOn: $cloudSyncEnabled)
                    .onChange(of: cloudSyncEnabled) { _, newValue in
                        store.updateSyncSettings(cloudSyncEnabled: newValue)
                    }
                Text("Placeholder for Phase 2 sync to pillyliu.com. Data stays on-device today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reset")
                    .font(.headline)

                Text("Erase the full local Practice log state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Practice Log", role: .destructive) {
                    resetJournalConfirmationText = ""
                    showingResetJournalPrompt = true
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.red)
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var insightsGameDropdown: some View {
        Menu {
            if store.games.isEmpty {
                Text("No game data")
            } else {
                ForEach(store.games.prefix(41)) { game in
                    Button(game.name) {
                        selectedGameID = game.id
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedGameName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        }
    }

    private var insightsOpponentDropdown: some View {
        Menu {
            Button("Select player") {
                insightsOpponentName = ""
            }
            ForEach(insightsOpponentOptions, id: \.self) { name in
                Button(name) {
                    insightsOpponentName = name
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(insightsOpponentName.isEmpty ? "Select player" : insightsOpponentName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        }
    }

    private var selectedGameName: String {
        guard !selectedGameID.isEmpty else { return "Select game" }
        if let game = store.games.first(where: { $0.id == selectedGameID }) {
            return game.name
        }
        return "Select game"
    }

    private func headToHeadPlotHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 170 }
        let rowHeight: CGFloat = 20
        let rowSpacing: CGFloat = 6
        let rows = CGFloat(count)
        let content = (rows * rowHeight) + (max(0, rows - 1) * rowSpacing) + 14
        return max(170, content)
    }

    private func mechanicsHistoryMaxHeight() -> CGFloat {
        let height = viewportHeight > 0 ? viewportHeight : 800
        return max(200, height - 470)
    }

    private func applyDefaultsAfterLoad() {
        if selectedGameID.isEmpty, let first = store.games.first {
            selectedGameID = first.id
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

        if selectedMechanicSkill.isEmpty {
            selectedMechanicSkill = store.allTrackedMechanicsSkills().first ?? ""
        }
    }

    private func goToGame(_ gameID: String) {
        guard !gameID.isEmpty else { return }
        selectedGameID = gameID
        markPracticeGameViewed(gameID)
        let target = PracticeNavRoute.game(gameID)
        if gameNavigationPath.last != target {
            gameNavigationPath.append(target)
        }
    }

    private func resumeToPracticeGame() {
        if let game = resumeGame {
            goToGame(game.id)
        } else if let first = store.games.first {
            goToGame(first.id)
        }
    }

    private func openQuickEntry(_ sheet: QuickEntrySheet) {
        let remembered = rememberedQuickEntryGame(for: sheet)
        if sheet == .mechanics {
            selectedGameID = remembered
        } else if !remembered.isEmpty {
            selectedGameID = remembered
        } else if !selectedGameID.isEmpty {
            // keep current selection
        } else if let first = store.games.first {
            selectedGameID = first.id
        }
        quickSheet = sheet
    }

    private func rememberedQuickEntryGame(for sheet: QuickEntrySheet) -> String {
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

    private func rememberQuickEntryGame(sheet: QuickEntrySheet, gameID: String) {
        switch sheet {
        case .score:
            quickScoreGameID = gameID
        case .study:
            quickStudyGameID = gameID
        case .practice:
            quickPracticeGameID = gameID
        case .mechanics:
            quickMechanicsGameID = gameID
        }
    }

    private func markPracticeGameViewed(_ gameID: String) {
        guard !gameID.isEmpty else { return }
        practiceLastViewedGameID = gameID
        practiceLastViewedGameTS = Date().timeIntervalSince1970
    }

    private func openGroupEditorForSelection() {
        let selectedID = selectedGroup?.id ?? store.state.customGroups.first?.id
        guard let selectedID else { return }
        store.setSelectedGroup(id: selectedID)
        editingGroupID = selectedID
        openGroupEditor = true
    }

    private func openGroupEditorForCreate() {
        editingGroupID = nil
        openGroupEditor = true
    }

    private func openCurrentGroupDateEditor(for groupID: UUID, field: GroupEditorDateField) {
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

    private func formattedDashboardDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return shortDashboardDateFormatter.string(from: date)
    }

    private var shortDashboardDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }

    private func resumeChip(_ text: String, showsChevron: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.14), in: Capsule())
    }

    private func statusChip(_ text: String, color: Color, font: Font = .caption) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func formatGroupDate(_ date: Date) -> String {
        Self.groupDateFormatter.string(from: date)
    }

    private static let groupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    private func quickActionButton(_ text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                Text(text)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .appControlStyle()
        }
        .buttonStyle(.plain)
    }

    private func progressSummary(taskProgress: [StudyTaskKind: Int]) -> String {
        let ordered = StudyTaskKind.allCases.map { task in
            "\(taskShortLabel(task)): \(taskProgress[task] ?? 0)%"
        }
        return ordered.joined(separator: "  •  ")
    }

    private func taskShortLabel(_ task: StudyTaskKind) -> String {
        switch task {
        case .playfield: return "Playfield"
        case .rulesheet: return "Rules"
        case .tutorialVideo: return "Tutorial"
        case .gameplayVideo: return "Gameplay"
        case .practice: return "Practice"
        }
    }

    private func actionIcon(_ action: JournalActionType) -> String {
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

    private func libraryActivityIcon(_ kind: LibraryActivityKind) -> String {
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

    private func libraryActivitySummary(_ event: LibraryActivityEvent) -> String {
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

    private func scoreTrendValues(for gameID: String) -> [Double] {
        store.state.scoreEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp < $1.timestamp }
            .map(\.score)
    }

    private func formattedScore(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    private func signedScore(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(formattedScore(value))"
    }

    private func signedCompact(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))"
    }

    private func refreshHeadToHead() async {
        guard !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !insightsOpponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            headToHead = nil
            return
        }

        isLoadingHeadToHead = true
        defer { isLoadingHeadToHead = false }
        headToHead = await store.comparePlayers(yourName: playerName, opponentName: insightsOpponentName)
    }

    private func refreshInsightsOpponentOptions() async {
        let names = await store.availableLeaguePlayers()
        let normalizedSelf = playerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        insightsOpponentOptions = names.filter { $0.lowercased() != normalizedSelf }
        if !insightsOpponentName.isEmpty, !insightsOpponentOptions.contains(insightsOpponentName) {
            insightsOpponentName = ""
        }
    }

    private func refreshLeaguePlayerOptions() async {
        leaguePlayerOptions = await store.availableLeaguePlayers()
        if !leaguePlayerName.isEmpty, !leaguePlayerOptions.contains(leaguePlayerName) {
            leaguePlayerName = ""
        }
    }

    private func scopedHeadToHeadComparison() -> HeadToHeadComparison? {
        headToHead
    }
}

private struct QuickEntrySheetView: View {
    let kind: QuickEntrySheet
    @ObservedObject var store: PracticeUpgradeStore
    @Binding var selectedGameID: String
    let onGameSelectionChanged: (QuickEntrySheet, String) -> Void
    let onEntrySaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedActivity: QuickEntryActivity = .score
    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var rulesheetProgress: Double = 0
    @State private var videoKind: VideoProgressInputKind = .clock
    @State private var videoValue: String = ""
    @State private var videoPercent: Double = 0
    @State private var practiceMinutes: String = ""
    @State private var practiceCategory: PracticeCategory = .general
    @State private var mechanicsSkill: String = ""
    @State private var mechanicsCompetency: Double = 3
    @State private var mechanicsNote: String = ""
    @State private var noteText: String = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Game", selection: $selectedGameID) {
                            if selectedActivity == .mechanics {
                                Text("None").tag("")
                            }
                            if store.games.isEmpty {
                                Text("No game data").tag("")
                            } else {
                                ForEach(store.games.prefix(41)) { game in
                                    Text(game.name).tag(game.id)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: store.games.count) { _, _ in
                            if selectedGameID.isEmpty, let first = store.games.first {
                                selectedGameID = first.id
                            }
                        }

                        Picker("Activity", selection: $selectedActivity) {
                            ForEach(QuickEntryActivity.allCases) { activity in
                                Text(activity.label).tag(activity)
                            }
                        }
                        .pickerStyle(.menu)

                        sectionCard("Details") {
                            switch selectedActivity {
                            case .score:
                                styledTextField("Score", text: $scoreText, keyboard: .numbersAndPunctuation)

                                Picker("Context", selection: $scoreContext) {
                                    ForEach(ScoreContext.allCases) { context in
                                        Text(context.label).tag(context)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if scoreContext == .tournament {
                                    styledTextField("Tournament name", text: $tournamentName)
                                }
                            case .rulesheet:
                                sliderRow(title: "Rulesheet progress", value: $rulesheetProgress)
                                styledTextField("Optional note", text: $noteText, axis: .vertical)
                            case .tutorialVideo, .gameplayVideo:
                                Picker("Input mode", selection: $videoKind) {
                                    ForEach(VideoProgressInputKind.allCases) { kind in
                                        Text(kind.label).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if videoKind == .clock {
                                    styledTextField("mm:ss (example: 12:45)", text: $videoValue, keyboard: .numbersAndPunctuation)
                                } else {
                                    sliderRow(title: "Percent watched", value: $videoPercent)
                                }

                                styledTextField("Optional note", text: $noteText, axis: .vertical)
                            case .playfield:
                                Text("Logs a timestamped playfield review.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                styledTextField("Optional note", text: $noteText, axis: .vertical)
                            case .practice:
                                styledTextField("Practice minutes (optional)", text: $practiceMinutes, keyboard: .numberPad)
                                Picker("Practice note type", selection: $practiceCategory) {
                                    ForEach(noteCategories) { option in
                                        Text(option.label).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                styledTextField("Optional note", text: $noteText, axis: .vertical)
                            case .mechanics:
                                Picker("Skill", selection: $mechanicsSkill) {
                                    ForEach(store.allTrackedMechanicsSkills(), id: \.self) { skill in
                                        Text(skill).tag(skill)
                                    }
                                }
                                .pickerStyle(.menu)

                                HStack {
                                    Text("Competency")
                                    Spacer()
                                    Text("\(Int(mechanicsCompetency))/5")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $mechanicsCompetency, in: 1...5, step: 1)

                                styledTextField("Mechanics note", text: $mechanicsNote, axis: .vertical)

                                let detected = store.detectedMechanicsTags(in: mechanicsNote)
                                if !detected.isEmpty {
                                    Text("Detected tags: \(detected.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let savedGameID = save() {
                            onEntrySaved(savedGameID)
                            dismiss()
                        }
                    }
                    .disabled(selectedGameID.isEmpty && selectedActivity != .mechanics)
                }
            }
            .onAppear {
                selectedActivity = kind.defaultActivity
                if selectedGameID.isEmpty, kind != .mechanics, let first = store.games.first {
                    selectedGameID = first.id
                }
                if mechanicsSkill.isEmpty {
                    mechanicsSkill = store.allTrackedMechanicsSkills().first ?? ""
                }
            }
            .onChange(of: selectedGameID) { _, newValue in
                onGameSelectionChanged(kind, newValue)
            }
            .onChange(of: selectedActivity) { _, newValue in
                if newValue == .mechanics {
                    if selectedGameID.isEmpty {
                        selectedGameID = ""
                    }
                } else if selectedGameID.isEmpty, let first = store.games.first {
                    selectedGameID = first.id
                }
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func styledTextField(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text, axis: axis)
            .keyboardType(keyboard)
            .lineLimit(axis == .vertical ? 2 ... 4 : 1 ... 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
    }

    private func sliderRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(.white.opacity(0.92))
                .padding(.horizontal, 2)
        }
    }

    private func save() -> String? {
        validationMessage = nil
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmedNote.isEmpty ? nil : trimmedNote

        switch selectedActivity {
        case .score:
            let normalized = scoreText.replacingOccurrences(of: ",", with: "")
            guard let score = Double(normalized), score > 0 else {
                validationMessage = "Enter a valid score above 0."
                return nil
            }
            store.addScore(gameID: selectedGameID, score: score, context: scoreContext, tournamentName: tournamentName)
            return selectedGameID
        case .rulesheet:
            store.addGameTaskEntry(
                gameID: selectedGameID,
                task: .rulesheet,
                progressPercent: Int(rulesheetProgress.rounded()),
                note: note
            )
            return selectedGameID
        case .tutorialVideo, .gameplayVideo:
            guard let normalizedVideoValue = validatedVideoValue(
                value: videoKind == .percent ? "\(Int(videoPercent.rounded()))" : videoValue,
                kind: videoKind
            ) else {
                validationMessage = videoKind == .clock
                    ? "Video time must be in mm:ss format (example: 12:45)."
                    : "Video percent must be a whole number between 0 and 100."
                return nil
            }

            let action: JournalActionType = selectedActivity == .tutorialVideo ? .tutorialWatch : .gameplayWatch
            store.addManualVideoProgress(
                gameID: selectedGameID,
                action: action,
                kind: videoKind,
                value: normalizedVideoValue,
                note: note
            )
            return selectedGameID
        case .playfield:
            store.addGameTaskEntry(
                gameID: selectedGameID,
                task: .playfield,
                progressPercent: nil,
                note: note ?? "Reviewed playfield image"
            )
            return selectedGameID
        case .practice:
            let trimmedMinutes = practiceMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedMinutes.isEmpty,
               (Int(trimmedMinutes) == nil || Int(trimmedMinutes) ?? 0 <= 0) {
                validationMessage = "Practice minutes must be a whole number greater than 0 when entered."
                return nil
            }
            let composedNote: String?
            if let minutes = Int(trimmedMinutes), minutes > 0 {
                let prefix = "Practice session: \(minutes) minute\(minutes == 1 ? "" : "s")"
                composedNote = note.map { "\(prefix). \($0)" } ?? prefix
            } else {
                composedNote = note ?? "Practice session"
            }
            store.addGameTaskEntry(
                gameID: selectedGameID,
                task: .practice,
                progressPercent: nil,
                note: composedNote
            )
            if let note, !note.isEmpty {
                store.addNote(gameID: selectedGameID, category: practiceCategory, detail: nil, note: note)
            }
            return selectedGameID
        case .mechanics:
            let skill = mechanicsSkill.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawNote = mechanicsNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = skill.isEmpty ? "#mechanics" : "#\(skill.replacingOccurrences(of: " ", with: ""))"
            let composed = rawNote.isEmpty
                ? "\(prefix) competency \(Int(mechanicsCompetency))/5."
                : "\(prefix) competency \(Int(mechanicsCompetency))/5. \(rawNote)"
            let targetGameID = selectedGameID.isEmpty ? (store.games.first?.id ?? "") : selectedGameID
            guard !targetGameID.isEmpty else {
                validationMessage = "Add at least one game in the library before logging mechanics."
                return nil
            }
            store.addNote(gameID: targetGameID, category: .general, detail: skill.isEmpty ? nil : skill, note: composed)
            return targetGameID
        }
    }

    private var noteCategories: [PracticeCategory] {
        [.general, .shots, .modes, .multiball, .strategy]
    }

    private func validatedVideoValue(value raw: String, kind: VideoProgressInputKind) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .clock:
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0,
                  (0...59).contains(seconds) else {
                return nil
            }
            return "\(minutes):\(String(format: "%02d", seconds))"
        case .percent:
            guard let percent = Int(trimmed), (0...100).contains(percent) else {
                return nil
            }
            return "\(percent)"
        }
    }
}

private struct GroupProgressWheel: View {
    let taskProgress: [StudyTaskKind: Int]

    private let taskColors: [StudyTaskKind: Color] = [
        .playfield: .cyan,
        .rulesheet: .blue,
        .tutorialVideo: .orange,
        .gameplayVideo: .purple,
        .practice: .green
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size / 2) - 3
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let tasks = StudyTaskKind.allCases
            let segment = 360.0 / Double(tasks.count)
            let gap = 6.0

            ZStack {
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    let start = -90.0 + (Double(index) * segment) + (gap / 2)
                    let end = -90.0 + (Double(index + 1) * segment) - (gap / 2)
                    let progress = Double(taskProgress[task] ?? 0) / 100.0
                    let fillEnd = start + ((end - start) * progress)

                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(start),
                            endAngle: .degrees(end),
                            clockwise: false
                        )
                    }
                    .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 5, lineCap: .round))

                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(start),
                            endAngle: .degrees(fillEnd),
                            clockwise: false
                        )
                    }
                    .stroke((taskColors[task] ?? .gray).opacity(progress > 0 ? 0.95 : 0.2), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
        }
    }
}

private struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct HeadToHeadGameRow: View {
    let game: HeadToHeadGameStats

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.gameName)
                .font(.footnote.weight(.semibold))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mean")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(formatted(game.yourMean)) vs \(formatted(game.opponentMean))")
                        .font(.caption)
                }
                Spacer()
                Text(game.meanDelta >= 0 ? "+\(formatted(abs(game.meanDelta)))" : "-\(formatted(abs(game.meanDelta)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(game.meanDelta >= 0 ? .green : .orange)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct MechanicsTrendSparkline: View {
    let logs: [MechanicsSkillLog]

    var body: some View {
        GeometryReader { geo in
            let values = logs.compactMap(\.comfort).map(Double.init)
            if values.count < 2 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Text("Need 2+ comfort logs for trend")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            } else {
                let minV = values.min() ?? 1
                let maxV = values.max() ?? 5
                let span = max(0.1, maxV - minV)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    Path { path in
                        for (idx, value) in values.enumerated() {
                            let x = geo.size.width * CGFloat(idx) / CGFloat(max(values.count - 1, 1))
                            let yNorm = (value - minV) / span
                            let y = geo.size.height - (geo.size.height * CGFloat(yNorm))
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.green.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct ScoreTrendSparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            if values.count < 2 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Text("Need 2+ scores for trend")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            } else {
                let maxV = values.max() ?? 1
                let intervals = 6
                let step = niceStep(maxV / Double(intervals))
                let top = max(step * Double(intervals), step)
                let highlightedTick = floor(maxV / step) * step
                let ticks = (0...intervals).map { Double($0) * step }
                let leftAxisWidth: CGFloat = 56
                let edgePadding: CGFloat = 8
                let pointInset: CGFloat = 4
                let plotWidth = max(20, geo.size.width - leftAxisWidth - (edgePadding * 2) - (pointInset * 2))
                let plotHeight = max(20, geo.size.height - (edgePadding * 2))

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    ForEach(Array(ticks.enumerated()), id: \.offset) { _, tickValue in
                        let y = edgePadding + plotHeight - (plotHeight * CGFloat(tickValue / top))
                        let isHighlight = abs(tickValue - highlightedTick) < 0.0001 && tickValue > 0 && tickValue < top

                        Path { path in
                            path.move(to: CGPoint(x: edgePadding + leftAxisWidth, y: y))
                            path.addLine(to: CGPoint(x: edgePadding + leftAxisWidth + plotWidth, y: y))
                        }
                        .stroke(
                            isHighlight ? Color.white.opacity(0.30) : Color.white.opacity(0.16),
                            style: StrokeStyle(lineWidth: isHighlight ? 1.2 : 0.8)
                        )

                        Path { path in
                            let tickLength: CGFloat = isHighlight ? 10 : 6
                            path.move(to: CGPoint(x: edgePadding + leftAxisWidth - tickLength, y: y))
                            path.addLine(to: CGPoint(x: edgePadding + leftAxisWidth, y: y))
                        }
                        .stroke(
                            isHighlight ? Color.white.opacity(0.75) : Color.white.opacity(0.45),
                            style: StrokeStyle(lineWidth: isHighlight ? 1.4 : 1.0, lineCap: .round)
                        )

                        Text(axisLabel(for: tickValue))
                            .font(.caption2)
                            .foregroundStyle(isHighlight ? .primary : .secondary)
                            .frame(width: leftAxisWidth - 10, alignment: .trailing)
                            .position(x: edgePadding + (leftAxisWidth - 10) / 2, y: y)
                    }

                    Path { path in
                        for (idx, value) in values.enumerated() {
                            let x = edgePadding + leftAxisWidth + pointInset + (plotWidth * CGFloat(idx) / CGFloat(max(values.count - 1, 1)))
                            let yNorm = min(1, max(0, value / top))
                            let y = edgePadding + plotHeight - (plotHeight * CGFloat(yNorm))
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.cyan.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                        let x = edgePadding + leftAxisWidth + pointInset + (plotWidth * CGFloat(idx) / CGFloat(max(values.count - 1, 1)))
                        let yNorm = min(1, max(0, value / top))
                        let y = edgePadding + plotHeight - (plotHeight * CGFloat(yNorm))
                        Circle()
                            .fill(Color.cyan.opacity(0.95))
                            .frame(width: 3.5, height: 3.5)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private func niceStep(_ raw: Double) -> Double {
        let safeRaw = max(1, raw)
        let magnitude = pow(10, floor(log10(safeRaw)))
        let normalized = safeRaw / magnitude
        let niceNormalized: Double
        if normalized <= 1 {
            niceNormalized = 1
        } else if normalized <= 2 {
            niceNormalized = 2
        } else if normalized <= 5 {
            niceNormalized = 5
        } else {
            niceNormalized = 10
        }
        return niceNormalized * magnitude
    }

    private func axisLabel(for value: Double) -> String {
        if value >= 1_000_000_000 {
            let billions = value / 1_000_000_000
            let rounded = abs(billions.rounded() - billions) < 0.05 ? String(Int(billions.rounded())) : String(format: "%.1f", billions)
            return "\(rounded) bil"
        }
        if value >= 1_000_000 {
            let millions = value / 1_000_000
            let rounded = abs(millions.rounded() - millions) < 0.05 ? String(Int(millions.rounded())) : String(format: "%.1f", millions)
            return "\(rounded) mil"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}

private struct HeadToHeadDeltaBars: View {
    let games: [HeadToHeadGameStats]

    var body: some View {
        GeometryReader { geo in
            let maxDelta = max(1, games.map { abs($0.meanDelta) }.max() ?? 1)
            let rowSpacing: CGFloat = 6
            let rowHeight = max(16, (geo.size.height - (CGFloat(max(games.count - 1, 0)) * rowSpacing)) / CGFloat(max(games.count, 1)))
            let totalWidth = geo.size.width
            let nameWidth = totalWidth * 0.34
            let valueWidth = totalWidth * 0.16
            let plotWidth = max(40, totalWidth - nameWidth - valueWidth - 12)
            let halfPlot = plotWidth / 2

            VStack(spacing: rowSpacing) {
                ForEach(games) { game in
                    HStack(spacing: 6) {
                        Text(game.gameName)
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(width: nameWidth, alignment: .leading)

                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: plotWidth, height: rowHeight)

                            Rectangle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 1, height: rowHeight)
                                .offset(x: 0)

                            let ratio = min(1, abs(game.meanDelta) / maxDelta)
                            let deltaWidth = max(2, halfPlot * ratio)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(game.meanDelta >= 0 ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                                .frame(width: deltaWidth, height: rowHeight)
                                .offset(x: game.meanDelta >= 0 ? (deltaWidth / 2) : -(deltaWidth / 2))
                        }
                        .frame(width: plotWidth, alignment: .center)

                        Text(shortSigned(game.meanDelta))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(game.meanDelta >= 0 ? .green : .orange)
                            .frame(width: valueWidth, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func shortSigned(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "-" : "")
        return "\(sign)\(shortScore(abs(value)))"
    }

    private func shortScore(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return "\(String(format: "%.1f", value / 1_000_000_000))B"
        }
        if value >= 1_000_000 {
            return "\(String(format: "%.1f", value / 1_000_000))M"
        }
        if value >= 1_000 {
            return "\(String(format: "%.0f", value / 1_000))K"
        }
        return "\(Int(value.rounded()))"
    }
}

private enum GroupCreationTemplateSource: String, CaseIterable, Identifiable {
    case none
    case bank
    case duplicate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .bank: return "Bank Template"
        case .duplicate: return "Duplicate Group"
        }
    }
}

private enum GroupEditorDateField {
    case start
    case end
}

private struct GroupEditorScreen: View {
    @ObservedObject var store: PracticeUpgradeStore
    let editingGroupID: UUID?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedGameIDs: [String] = []
    @State private var isActive = true
    @State private var isPriority = false
    @State private var type: GroupType = .custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var hasStartDate = false
    @State private var hasEndDate = false
    @State private var validationMessage: String?
    @State private var didSeedFromEditingGroup = false
    @State private var showingDeleteGroupConfirmation = false
    @State private var pendingDeleteGameID: String?
    @State private var draggingGameID: String?
    @State private var templateSource: GroupCreationTemplateSource = .none
    @State private var selectedTemplateBank: Int = 0
    @State private var selectedDuplicateGroupID: UUID?
    @State private var showingTitleSelector = false
    @State private var showingScheduleCalendar = false
    @State private var editingScheduleField: GroupEditorDateField = .start
    @State private var createGroupPosition: Int = 1

    private var editingGroup: CustomGameGroup? {
        guard let editingGroupID else { return nil }
        return store.state.customGroups.first(where: { $0.id == editingGroupID })
    }

    private var selectedGames: [PinballGame] {
        let byID = Dictionary(uniqueKeysWithValues: store.games.map { ($0.id, $0) })
        return selectedGameIDs.compactMap { byID[$0] }
    }

    private var availableBanks: [Int] {
        Array(Set(store.games.compactMap(\.bank))).sorted()
    }

    private var duplicateCandidates: [CustomGameGroup] {
        store.state.customGroups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard("Name") {
                    TextField("Group name", text: $name)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .appControlStyle()
                }

                if editingGroup == nil {
                    sectionCard("Templates") {
                        Picker("Template", selection: $templateSource) {
                            ForEach(GroupCreationTemplateSource.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        switch templateSource {
                        case .none:
                            Text("Choose a template to prefill this group.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .bank:
                            if availableBanks.isEmpty {
                                Text("No bank data found in library.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("Bank", selection: $selectedTemplateBank) {
                                    ForEach(availableBanks, id: \.self) { bank in
                                        Text("Bank \(bank)").tag(bank)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button("Apply Bank Template") {
                                    applyBankTemplate(bank: selectedTemplateBank)
                                }
                                .buttonStyle(.glass)
                            }
                        case .duplicate:
                            if duplicateCandidates.isEmpty {
                                Text("No existing groups to duplicate.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("Group", selection: Binding<UUID?>(
                                    get: { selectedDuplicateGroupID ?? duplicateCandidates.first?.id },
                                    set: { selectedDuplicateGroupID = $0 }
                                )) {
                                    ForEach(duplicateCandidates) { group in
                                        Text(group.name).tag(Optional(group.id))
                                    }
                                }
                                .pickerStyle(.menu)

                                Button("Apply Duplicate Group") {
                                    applyDuplicateTemplate(groupID: selectedDuplicateGroupID ?? duplicateCandidates.first?.id)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }

                sectionCard("Titles") {
                    Button {
                        showingTitleSelector = true
                    } label: {
                        HStack {
                            Text(selectedGameIDs.isEmpty ? "Select games" : "\(selectedGameIDs.count) selected")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .appControlStyle()
                    }
                    .buttonStyle(.plain)

                    if selectedGames.isEmpty {
                        Text("No games selected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedGames) { game in
                                    SelectedGameMiniCard(game: game)
                                        .onDrag {
                                            draggingGameID = game.id
                                            return NSItemProvider(object: game.id as NSString)
                                        }
                                        .onDrop(
                                            of: [UTType.text],
                                            delegate: SelectedGameReorderDropDelegate(
                                                targetGameID: game.id,
                                                selectedGameIDs: $selectedGameIDs,
                                                draggingGameID: $draggingGameID
                                            )
                                        )
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                pendingDeleteGameID = game.id
                                            } label: {
                                                Label("Delete Title", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .onDrop(of: [UTType.text], delegate: SelectedGameReorderContainerDropDelegate(draggingGameID: $draggingGameID))
                        }

                        Text("Long-press a title card to reorder or delete.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                sectionCard("Status, Priority & Type") {
                    HStack {
                        Text("Active")
                        Spacer()
                        Toggle("", isOn: $isActive)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                    HStack {
                        Text("Priority")
                        Spacer()
                        Toggle("", isOn: $isPriority)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                    Picker("Type", selection: $type) {
                        ForEach(GroupType.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                positionSection

                sectionCard("Schedule") {
                    HStack {
                        Toggle("Start Date", isOn: $hasStartDate)
                            .toggleStyle(.switch)
                        Spacer()
                        if hasStartDate {
                            Button {
                                editingScheduleField = .start
                                showingScheduleCalendar = true
                            } label: {
                                Text(formatEditorScheduleDate(startDate))
                                    .font(.caption2)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                    HStack {
                        Toggle("End Date", isOn: $hasEndDate)
                            .toggleStyle(.switch)
                        Spacer()
                        if hasEndDate {
                            Button {
                                editingScheduleField = .end
                                showingScheduleCalendar = true
                            } label: {
                                Text(formatEditorScheduleDate(endDate))
                                    .font(.caption2)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()
                }

                if let validationMessage {
                    sectionCard("Validation") {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(AppBackground())
        .navigationTitle(editingGroup == nil ? "Create Group" : "Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onSaved()
                    dismiss()
                }
            }

            if editingGroup != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteGroupConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(editingGroup == nil ? "Create" : "Save") {
                    if save() {
                        onSaved()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { populateFromEditingGroupIfNeeded() }
        .sheet(isPresented: $showingTitleSelector) {
            NavigationStack {
                GroupGameSelectionScreen(store: store, selectedGameIDs: $selectedGameIDs)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingTitleSelector = false
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingScheduleCalendar) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        editingScheduleField == .start ? "Start Date" : "End Date",
                        selection: activeScheduleDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)

                    HStack {
                        Button("Clear", role: .destructive) {
                            if editingScheduleField == .start {
                                hasStartDate = false
                            } else {
                                hasEndDate = false
                            }
                            showingScheduleCalendar = false
                        }
                        .buttonStyle(.glass)

                        Spacer()

                        Button("Save") {
                            showingScheduleCalendar = false
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppBackground())
                .navigationTitle(editingScheduleField == .start ? "Set Start Date" : "Set End Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingScheduleCalendar = false
                        }
                    }
                }
            }
        }
        .confirmationDialog("Delete this group?", isPresented: $showingDeleteGroupConfirmation, titleVisibility: .visible) {
            Button("Delete Group", role: .destructive) {
                guard let group = editingGroup else { return }
                store.deleteGroup(id: group.id)
                onSaved()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the group and its title list.")
        }
        .confirmationDialog(
            "Remove this title from the group?",
            isPresented: Binding(
                get: { pendingDeleteGameID != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteGameID = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Title", role: .destructive) {
                removePendingGameIfNeeded()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteGameID = nil
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func populateFromEditingGroupIfNeeded() {
        guard !didSeedFromEditingGroup else { return }
        defer { didSeedFromEditingGroup = true }

        if selectedTemplateBank == 0 {
            selectedTemplateBank = availableBanks.first ?? 1
        }
        selectedDuplicateGroupID = duplicateCandidates.first?.id
        createGroupPosition = store.state.customGroups.count + 1

        guard let group = editingGroup else { return }
        name = group.name
        selectedGameIDs = group.gameIDs
        isActive = group.isActive
        isPriority = group.isPriority
        type = group.type
        hasStartDate = group.startDate != nil
        hasEndDate = group.endDate != nil
        if let start = group.startDate {
            startDate = start
        }
        if let end = group.endDate {
            endDate = end
        }
    }

    private func save() -> Bool {
        validationMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Group name is required."
            return false
        }
        guard !selectedGameIDs.isEmpty else {
            validationMessage = "Select at least one game."
            return false
        }
        let start = hasStartDate ? startDate : nil
        let end = hasEndDate ? endDate : nil
        if let start, let end, end < start {
            validationMessage = "End date must be on or after start date."
            return false
        }

        if let group = editingGroup {
            store.updateGroup(
                id: group.id,
                name: trimmed,
                gameIDs: selectedGameIDs,
                type: type,
                isActive: isActive,
                isPriority: isPriority,
                replaceStartDate: true,
                startDate: start,
                replaceEndDate: true,
                endDate: end
            )
            store.setSelectedGroup(id: group.id)
        } else if let newID = store.createGroup(
            name: trimmed,
            gameIDs: selectedGameIDs,
            type: type,
            isActive: isActive,
            isPriority: isPriority,
            startDate: start,
            endDate: end
        ) {
            if let createdIndex = store.state.customGroups.firstIndex(where: { $0.id == newID }) {
                let maxIndex = max(0, store.state.customGroups.count - 1)
                let desiredIndex = max(0, min(createGroupPosition - 1, maxIndex))
                if desiredIndex != createdIndex {
                    store.reorderGroups(fromOffsets: IndexSet(integer: createdIndex), toOffset: desiredIndex)
                }
            }
            store.setSelectedGroup(id: newID)
        }
        return true
    }

    private func reorderSelectedGames(sourceID: String, targetID: String) {
        guard sourceID != targetID else { return }
        guard let sourceIndex = selectedGameIDs.firstIndex(of: sourceID),
              let targetIndex = selectedGameIDs.firstIndex(of: targetID) else { return }
        let moving = selectedGameIDs.remove(at: sourceIndex)
        selectedGameIDs.insert(moving, at: targetIndex)
    }

    private func removePendingGameIfNeeded() {
        guard let gameID = pendingDeleteGameID else { return }
        selectedGameIDs.removeAll { $0 == gameID }
        pendingDeleteGameID = nil
    }

    private func formatEditorScheduleDate(_ date: Date) -> String {
        Self.editorScheduleDateFormatter.string(from: date)
    }

    private static let editorScheduleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    private func applyBankTemplate(bank: Int) {
        let games = store.games
            .filter { $0.bank == bank }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedGameIDs = games.map(\.id)
        type = .bank
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = "Bank \(bank) Focus"
        }
    }

    private func applyDuplicateTemplate(groupID: UUID?) {
        guard let groupID,
              let source = duplicateCandidates.first(where: { $0.id == groupID }) else { return }
        selectedGameIDs = source.gameIDs
        type = source.type
        isPriority = source.isPriority
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = "Copy of \(source.name)"
        }
        hasStartDate = source.startDate != nil
        hasEndDate = source.endDate != nil
        if let start = source.startDate {
            startDate = start
        }
        if let end = source.endDate {
            endDate = end
        }
    }

    private var positionSection: some View {
        sectionCard("Position") {
            HStack {
                Text("Position")
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        moveGroupPosition(up: true)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveGroupUp)
                    .foregroundStyle(canMoveGroupUp ? Color.primary : Color.secondary.opacity(0.4))

                    Text("\(groupPosition)")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 28)

                    Button {
                        moveGroupPosition(up: false)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveGroupDown)
                    .foregroundStyle(canMoveGroupDown ? Color.primary : Color.secondary.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .appControlStyle()
            }
        }
    }

    private var editedGroupIndex: Int? {
        guard let editingGroupID else { return nil }
        return store.state.customGroups.firstIndex(where: { $0.id == editingGroupID })
    }

    private var editedGroupPosition: Int {
        guard let editedGroupIndex else { return 1 }
        return editedGroupIndex + 1
    }

    private var groupPosition: Int {
        if editingGroup != nil {
            return editedGroupPosition
        }
        return max(1, min(createGroupPosition, store.state.customGroups.count + 1))
    }

    private var maxCreateGroupPosition: Int {
        max(1, store.state.customGroups.count + 1)
    }

    private var canMoveEditedGroupUp: Bool {
        guard let editedGroupIndex else { return false }
        return editedGroupIndex > 0
    }

    private var canMoveEditedGroupDown: Bool {
        guard let editedGroupIndex else { return false }
        return editedGroupIndex < (store.state.customGroups.count - 1)
    }

    private var canMoveGroupUp: Bool {
        if editingGroup != nil {
            return canMoveEditedGroupUp
        }
        return groupPosition > 1
    }

    private var canMoveGroupDown: Bool {
        if editingGroup != nil {
            return canMoveEditedGroupDown
        }
        return groupPosition < maxCreateGroupPosition
    }

    private func moveGroupPosition(up: Bool) {
        if editingGroup != nil {
            moveEditedGroup(up: up)
            return
        }
        if up {
            guard createGroupPosition > 1 else { return }
            createGroupPosition -= 1
        } else {
            guard createGroupPosition < maxCreateGroupPosition else { return }
            createGroupPosition += 1
        }
    }

    private func moveEditedGroup(up: Bool) {
        guard let editedGroupIndex else { return }
        if up {
            guard editedGroupIndex > 0 else { return }
            store.reorderGroups(fromOffsets: IndexSet(integer: editedGroupIndex), toOffset: editedGroupIndex - 1)
        } else {
            guard editedGroupIndex < (store.state.customGroups.count - 1) else { return }
            store.reorderGroups(fromOffsets: IndexSet(integer: editedGroupIndex), toOffset: editedGroupIndex + 2)
        }
    }

    private var activeScheduleDateBinding: Binding<Date> {
        Binding(
            get: { editingScheduleField == .start ? startDate : endDate },
            set: { newValue in
                if editingScheduleField == .start {
                    startDate = newValue
                } else {
                    endDate = newValue
                }
            }
        )
    }
}

private struct GroupGameSelectionScreen: View {
    @ObservedObject var store: PracticeUpgradeStore
    @Binding var selectedGameIDs: [String]

    @State private var searchText: String = ""

    private var filteredGames: [PinballGame] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return store.games
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var grouped: [(letter: String, games: [PinballGame])] {
        let buckets = Dictionary(grouping: filteredGames) { game in
            String(game.name.prefix(1)).uppercased()
        }
        return buckets.keys.sorted().map { letter in
            (letter, buckets[letter] ?? [])
        }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.letter) { section in
                Section(section.letter) {
                    ForEach(section.games) { game in
                        Button {
                            toggle(game.id)
                        } label: {
                            HStack {
                                Text(game.name)
                                Spacer()
                                Image(systemName: isSelected(game.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isSelected(game.id) ? .orange : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search titles")
        .navigationTitle("Select Titles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ gameID: String) {
        if isSelected(gameID) {
            selectedGameIDs.removeAll { $0 == gameID }
        } else {
            selectedGameIDs.append(gameID)
        }
    }

    private func isSelected(_ gameID: String) -> Bool {
        selectedGameIDs.contains(gameID)
    }
}

private struct SelectedGameMiniCard: View {
    let game: PinballGame
    private let cardWidth: CGFloat = 122

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FallbackAsyncImageView(
                candidates: game.miniPlayfieldCandidates,
                emptyMessage: nil,
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(game.name)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, alignment: .leading)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SelectedGameReorderDropDelegate: DropDelegate {
    let targetGameID: String
    @Binding var selectedGameIDs: [String]
    @Binding var draggingGameID: String?

    func dropEntered(info: DropInfo) {
        guard let draggingGameID else { return }
        guard draggingGameID != targetGameID else { return }
        guard let fromIndex = selectedGameIDs.firstIndex(of: draggingGameID),
              let toIndex = selectedGameIDs.firstIndex(of: targetGameID) else {
            return
        }
        if fromIndex == toIndex { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            selectedGameIDs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingGameID = nil
        return true
    }
}

private struct SelectedGameReorderContainerDropDelegate: DropDelegate {
    @Binding var draggingGameID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingGameID = nil
        return true
    }
}

private struct PracticeHubMiniCard: View {
    let destination: PracticeHubDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: destination.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(destination.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Text(destination.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 72, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .appPanelStyle()
    }
}

#Preview {
    PracticeUpgradeTab()
}
