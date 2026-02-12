import SwiftUI

private enum PracticePrimarySubview: String, CaseIterable, Identifiable {
    case overview
    case game

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .game: return "Game"
        }
    }
}

struct PracticeUpgradeTab: View {
    @StateObject private var store = PracticeUpgradeStore()
    @State private var primarySubview: PracticePrimarySubview = .overview

    @State private var selectedGameID: String = ""
    @State private var selectedTask: StudyTaskKind = .rulesheet
    @State private var studyProgressValue: Double = 0

    @State private var videoKind: VideoProgressInputKind = .clock
    @State private var videoValue: String = ""

    @State private var scoreValue: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""

    @State private var noteCategory: PracticeCategory = .general
    @State private var noteDetail: String = ""
    @State private var noteText: String = ""

    @State private var leaguePlayerName: String = ""
    @State private var leagueAutoFill = false

    @State private var cloudSyncEnabled = false
    @State private var useMedian = true
    @State private var gapMode: ChartGapMode = .compressInactive

    @State private var newGroupName: String = ""
    @State private var selectedGroupGameIDs: Set<String> = []
    @State private var selectedBankTemplate: Int = 1

    private var selectedGame: PinballGame? {
        store.games.first(where: { $0.id == selectedGameID })
    }

    private var availableBanks: [Int] {
        Array(Set(store.games.compactMap(\.bank))).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if store.isLoadingGames {
                    ProgressView("Loading practice scaffold...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Practice section", selection: $primarySubview) {
                                ForEach(PracticePrimarySubview.allCases) { item in
                                    Text(item.label).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)

                            if primarySubview == .overview {
                                philosophySection
                                scopeSection
                                storageSection
                                studyTrackingSection
                                journalSection
                                videoSection
                                scoreLoggingSection
                                leagueSection
                                analyticsSection
                                timeSeriesSection
                                gameDashboardSection
                                notesSection
                                groupsSection
                                uiStructureSection
                                longTermSection
                            } else {
                                PracticeGameWorkspace(store: store, selectedGameID: $selectedGameID)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("Practice")
            .task {
                await store.loadIfNeeded()
                applyDefaultsAfterLoad()
            }
        }
    }

    private var philosophySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Core Philosophy")
                .font(.headline)

            Text("Tool, not prescription. Every feature is optional, discoverable, and non-blocking.")
                .font(.subheadline)

            Text("This tab is scaffolded for both 5-minute weekly use and deep-dive sessions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scope & Data Anchors")
                .font(.headline)
            Text("Initial scope: 41 Avenue machines, keyed to existing library JSON.")
            Text("Loaded machines: \(store.games.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Storage Roadmap")
                .font(.headline)

            Toggle("Enable optional cloud sync to pillyliu.com", isOn: $cloudSyncEnabled)
                .onChange(of: cloudSyncEnabled) { _, newValue in
                    store.updateSyncSettings(cloudSyncEnabled: newValue)
                }

            Text(store.state.syncSettings.phaseLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var studyTrackingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study Tracking (Per Game)")
                .font(.headline)

            gamePicker

            Picker("Checklist item", selection: $selectedTask) {
                ForEach(StudyTaskKind.allCases) { task in
                    Text(task.label).tag(task)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text("Progress")
                Spacer()
                Text("\(Int(studyProgressValue))%")
                    .foregroundStyle(.secondary)
            }

            Slider(value: $studyProgressValue, in: 0 ... 100, step: 1)

            Button("Save progress event") {
                guard !selectedGameID.isEmpty else { return }
                store.updateStudyProgress(
                    gameID: selectedGameID,
                    task: selectedTask,
                    progressPercent: Int(studyProgressValue)
                )
            }
            .buttonStyle(.glass)

            Text("History is append-only and timestamped. Rulesheet/video resume hooks are scaffolded next.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !selectedGameID.isEmpty {
                ForEach(store.studyHistory(gameID: selectedGameID, task: selectedTask).prefix(3)) { event in
                    Text("• \(event.progressPercent)% on \(event.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Global Activity Journal")
                .font(.headline)

            Text("Single chronological timeline for study, browsing, practice, scores, and notes.")
                .font(.subheadline)

            ForEach(store.recentJournalEntries(limit: 8)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.journalSummary(for: entry))
                        .font(.footnote)
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Video Progress Tracking")
                .font(.headline)

            Picker("Input mode", selection: $videoKind) {
                ForEach(VideoProgressInputKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            TextField(videoKind == .clock ? "mm:ss (example: 12:45)" : "Percent watched (example: 40)", text: $videoValue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Button("Save manual video progress") {
                guard !selectedGameID.isEmpty else { return }
                guard !videoValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                store.addManualVideoProgress(gameID: selectedGameID, kind: videoKind, value: videoValue)
                videoValue = ""
            }
            .buttonStyle(.glass)

            Text("Planned side task: script all YouTube links, fetch durations, store locally.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var scoreLoggingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Score Logging")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Score", text: $scoreValue)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                Picker("Context", selection: $scoreContext) {
                    ForEach(ScoreContext.allCases) { context in
                        Text(context.label).tag(context)
                    }
                }
                .pickerStyle(.menu)
            }

            if scoreContext == .tournament {
                TextField("Tournament name (optional)", text: $tournamentName)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()
            }

            Button("Log score") {
                guard !selectedGameID.isEmpty else { return }
                let normalized = scoreValue.replacingOccurrences(of: ",", with: "")
                guard let score = Double(normalized), score > 0 else { return }
                store.addScore(gameID: selectedGameID, score: score, context: scoreContext, tournamentName: tournamentName)
                scoreValue = ""
                tournamentName = ""
            }
            .buttonStyle(.glass)

            if let selectedGameID = selectedGame?.id {
                let recent = store.recentScores(for: selectedGameID)
                if !recent.isEmpty {
                    Text("Recent")
                        .font(.footnote.weight(.semibold))
                    ForEach(recent.prefix(4)) { entry in
                        Text("• \(entry.context.label): \(formattedScore(entry.score))")
                            .font(.footnote)
                    }
                }
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var leagueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("League Integration (Placeholder)")
                .font(.headline)

            TextField("Your league player name", text: $leaguePlayerName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Toggle("Enable CSV auto-fill for League scores", isOn: $leagueAutoFill)
                .onChange(of: leagueAutoFill) { _, newValue in
                    store.updateLeagueSettings(playerName: leaguePlayerName, csvAutoFillEnabled: newValue)
                }

            HStack(spacing: 10) {
                Button("Save league identity") {
                    store.updateLeagueSettings(playerName: leaguePlayerName, csvAutoFillEnabled: leagueAutoFill)
                }
                .buttonStyle(.glass)

                Button("Attempt LPL CSV import") {
                    store.markLeagueImportAttempt()
                }
                .buttonStyle(.glass)
            }

            Text("Current state: matching + import UI scaffolded; parser wiring is next.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Score Analysis & Targets")
                .font(.headline)

            Toggle("Use median in summaries", isOn: $useMedian)
                .onChange(of: useMedian) { _, newValue in
                    store.updateAnalyticsSettings(gapMode: gapMode, useMedian: newValue)
                }

            if let gameID = selectedGame?.id,
               let summary = store.scoreSummary(for: gameID) {
                Text("Average: \(formattedScore(summary.average))")
                Text("Median: \(formattedScore(summary.median))")
                Text("Floor: \(formattedScore(summary.floor))")
                Text("IQR (25-75): \(formattedScore(summary.p25)) to \(formattedScore(summary.p75))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log scores to unlock average/median/floor/distribution scaffold.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("LPL target and division cutoff overlays are scaffolded as next chart layer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var timeSeriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time-Series Visualization")
                .font(.headline)

            Picker("Gap handling", selection: $gapMode) {
                ForEach(ChartGapMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: gapMode) { _, newValue in
                store.updateAnalyticsSettings(gapMode: newValue, useMedian: useMedian)
            }

            Text("Selected: \(gapMode.label)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var gameDashboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Game Dashboard")
                .font(.headline)

            if let game = selectedGame {
                Text(game.name)
                    .font(.subheadline.weight(.semibold))

                Text("Study status")
                    .font(.footnote.weight(.semibold))
                ForEach(StudyTaskKind.allCases) { task in
                    Text("• \(task.label): \(store.studyProgress(gameID: game.id, task: task))%")
                        .font(.footnote)
                }

                Text("Alerts")
                    .font(.footnote.weight(.semibold))
                Text("• Rulesheet last read recency: placeholder")
                    .font(.footnote)
                Text("• Practice gap detection: placeholder")
                    .font(.footnote)
                Text("• High variance warning: placeholder")
                    .font(.footnote)
            } else {
                Text("Select a game to view dashboard summary scaffold.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Practice Notes")
                .font(.headline)

            Picker("Category", selection: $noteCategory) {
                ForEach(PracticeCategory.allCases) { category in
                    Text(category.label).tag(category)
                }
            }
            .pickerStyle(.menu)

            TextField("Optional detail (shot/mode name)", text: $noteDetail)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            TextField("Add note", text: $noteText, axis: .vertical)
                .lineLimit(2 ... 5)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Button("Save note") {
                guard !selectedGameID.isEmpty else { return }
                store.addNote(gameID: selectedGameID, category: noteCategory, detail: noteDetail, note: noteText)
                noteDetail = ""
                noteText = ""
            }
            .buttonStyle(.glass)

            if let gameID = selectedGame?.id {
                let notes = store.recentNotes(for: gameID)
                if !notes.isEmpty {
                    ForEach(notes.prefix(3)) { note in
                        Text("• [\(note.category.label)] \(note.note)")
                            .font(.footnote)
                    }
                }
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Grouped Game Views")
                .font(.headline)

            TextField("Group name", text: $newGroupName)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            if !store.games.isEmpty {
                Menu("Pick games (\(selectedGroupGameIDs.count))") {
                    ForEach(store.games.prefix(41)) { game in
                        Button {
                            if selectedGroupGameIDs.contains(game.id) {
                                selectedGroupGameIDs.remove(game.id)
                            } else {
                                selectedGroupGameIDs.insert(game.id)
                            }
                        } label: {
                            HStack {
                                Text(game.name)
                                if selectedGroupGameIDs.contains(game.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Create custom group") {
                    store.createGroup(name: newGroupName, gameIDs: Array(selectedGroupGameIDs))
                    newGroupName = ""
                    selectedGroupGameIDs.removeAll()
                }
                .buttonStyle(.glass)

                if !availableBanks.isEmpty {
                    Menu("Bank template: \(selectedBankTemplate)") {
                        ForEach(availableBanks, id: \.self) { bank in
                            Button("Bank \(bank)") {
                                selectedBankTemplate = bank
                            }
                        }
                    }

                    Button("Add template") {
                        store.applyBankTemplate(bank: selectedBankTemplate, into: "Bank \(selectedBankTemplate)")
                    }
                    .buttonStyle(.glass)
                }
            }

            if !store.state.customGroups.isEmpty {
                Text("Group dashboard preview")
                    .font(.footnote.weight(.semibold))
                ForEach(store.state.customGroups.suffix(3)) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(group.name) (\(group.gameIDs.count) games)")
                            .font(.footnote.weight(.semibold))

                        let topCandidates = store.groupPriorityCandidates(group: group).prefix(2)
                        if topCandidates.isEmpty {
                            Text("• Add scores/notes to get priority recommendations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(topCandidates), id: \.id) { game in
                                Text("• Start with \(game.name)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var uiStructureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UI Structure")
                .font(.headline)

            Text("This scaffolding includes library linkage, journal timeline, game dashboard blocks, and group focus blocks in one iOS-first tab.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .appPanelStyle()
    }

    private var longTermSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Long-Term Vision")
                .font(.headline)

            Text("Built to support reflection, improvement, and curiosity without punishing partial usage.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .appPanelStyle()
    }

    private var gamePicker: some View {
        Picker("Game", selection: $selectedGameID) {
            if store.games.isEmpty {
                Text("No game data").tag("")
            } else {
                ForEach(store.games.prefix(41)) { game in
                    Text(game.name).tag(game.id)
                }
            }
        }
        .pickerStyle(.menu)
    }

    private func applyDefaultsAfterLoad() {
        if selectedGameID.isEmpty, let first = store.games.first {
            selectedGameID = first.id
        }

        studyProgressValue = Double(store.studyProgress(gameID: selectedGameID, task: selectedTask))
        leaguePlayerName = store.state.leagueSettings.playerName
        leagueAutoFill = store.state.leagueSettings.csvAutoFillEnabled
        cloudSyncEnabled = store.state.syncSettings.cloudSyncEnabled
        useMedian = store.state.analyticsSettings.useMedian
        gapMode = store.state.analyticsSettings.gapMode

        if let firstBank = availableBanks.first {
            selectedBankTemplate = firstBank
        }
    }

    private func formattedScore(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}

#Preview {
    PracticeUpgradeTab()
}
