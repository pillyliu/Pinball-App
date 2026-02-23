import SwiftUI
import WebKit

private enum PracticeGameSubview: String, CaseIterable, Identifiable {
    case summary
    case input
    case log

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: return "Summary"
        case .input: return "Input"
        case .log: return "Log"
        }
    }
}

private func inferPracticeLibrarySourcesForWorkspace(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    var out: [PinballLibrarySource] = []
    for game in games {
        if seen.insert(game.sourceId).inserted {
            out.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
        }
    }
    return out
}

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String
    var onGameViewed: ((String) -> Void)? = nil

    @State private var subview: PracticeGameSubview = .summary
    @State private var entryTask: StudyTaskKind?
    @State private var showingScoreSheet = false
    @State private var saveBanner: String?
    @State private var activeVideoID: String?
    @State private var gameSummaryDraft: String = ""

    private var selectedGame: PinballGame? {
        store.gameForAnyID(selectedGameID)
    }

    private var playableVideos: [PinballGame.PlayableVideo] {
        guard let game = selectedGame else { return [] }
        return game.videos.compactMap { video in
            guard let rawURL = video.url,
                  let id = PinballGame.youtubeID(from: rawURL) else {
                return nil
            }
            return PinballGame.PlayableVideo(id: id, label: video.label ?? "Video")
        }
    }

    private var availableLibrarySources: [PinballLibrarySource] {
        store.librarySources.isEmpty ? inferPracticeLibrarySourcesForWorkspace(from: store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames) : store.librarySources
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    screenshotSection

                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Mode", selection: $subview) {
                            ForEach(PracticeGameSubview.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        Group {
                            switch subview {
                            case .summary:
                                gameSummaryView
                            case .input:
                                gameInputView
                            case .log:
                                gameLogView
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .appPanelStyle()

                    gameSummaryCard

                    gameResourceCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle(selectedGame?.name ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if availableLibrarySources.count > 1 {
                        Picker(
                            "Library",
                            selection: Binding(
                                get: { store.defaultPracticeSourceID ?? "" },
                                set: { newValue in
                                    store.selectPracticeLibrarySource(id: newValue)
                                    let canonical = store.canonicalPracticeGameID(selectedGameID)
                                    if !canonical.isEmpty,
                                       store.games.contains(where: { $0.canonicalPracticeKey == canonical }) {
                                        selectedGameID = canonical
                                    } else {
                                        selectedGameID = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first?.canonicalPracticeKey ?? ""
                                    }
                                }
                            )
                        ) {
                            ForEach(availableLibrarySources) { source in
                                Text(source.name).tag(source.id)
                            }
                        }
                    }
                    Picker("Game", selection: $selectedGameID) {
                        if store.games.isEmpty {
                            Text("No game data").tag("")
                        } else {
                            ForEach(orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true, limit: 41)) { game in
                                Text(game.name).tag(game.canonicalPracticeKey)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay(alignment: .top) {
            if let saveBanner {
                Text(saveBanner)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: saveBanner)
        .onAppear {
            if selectedGameID.isEmpty, let first = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first {
                selectedGameID = first.canonicalPracticeKey
            }
            if !selectedGameID.isEmpty {
                store.markGameBrowsed(gameID: selectedGameID)
                onGameViewed?(selectedGameID)
                gameSummaryDraft = store.gameSummaryNote(for: selectedGameID)
            }
        }
        .onChange(of: selectedGameID) { _, newValue in
            store.markGameBrowsed(gameID: newValue)
            if !newValue.isEmpty {
                onGameViewed?(newValue)
            }
            gameSummaryDraft = store.gameSummaryNote(for: newValue)
        }
        .sheet(item: $entryTask) { task in
            GameTaskEntrySheet(
                task: task,
                gameID: selectedGameID,
                store: store,
                onSaved: { message in
                    showSaveBanner(message)
                }
            )
            .practiceEntrySheetStyle()
        }
        .sheet(isPresented: $showingScoreSheet) {
            GameScoreEntrySheet(
                gameID: selectedGameID,
                store: store,
                onSaved: {
                    showSaveBanner("Score logged")
                }
            )
            .practiceEntrySheetStyle()
        }
    }

    private var gameSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Note")
                .font(.headline)
            Text("Freeform summary of how this game is going.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextEditor(text: $gameSummaryDraft)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .appControlStyle()

            HStack {
                Spacer()
                Button("Save Note") {
                    store.updateGameSummaryNote(gameID: selectedGameID, note: gameSummaryDraft)
                    showSaveBanner("Game note saved")
                }
                .buttonStyle(.glass)
                .disabled(selectedGameID.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var screenshotSection: some View {
        Group {
            if let game = selectedGame {
                Rectangle()
                    .fill(Color.clear)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        FallbackAsyncImageView(
                            candidates: game.gamePlayfieldCandidates,
                            emptyMessage: "No image",
                            contentMode: .fill
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                    .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .overlay {
                        Text("Select a game")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var gameResourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let game = selectedGame {
                HStack(alignment: .center, spacing: 8) {
                    Text(game.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let variant = game.variant?.trimmingCharacters(in: .whitespacesAndNewlines), !variant.isEmpty {
                        Text(variant)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .secondarySystemFill), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 0.8)
                            )
                    }
                    Spacer(minLength: 0)
                }
            }
            Text("Game Resources")
                .font(.headline)

            if let game = selectedGame {
                let hasRulesheet = !game.rulesheetPathCandidates.isEmpty
                Text(game.metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if hasRulesheet {
                        NavigationLink("Rulesheet") {
                            RulesheetScreen(slug: game.practiceKey, gameName: game.name, pathCandidates: game.rulesheetPathCandidates)
                        }
                        .buttonStyle(.glass)
                    } else {
                        Text("Rulesheet")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(.secondary)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    if !game.fullscreenPlayfieldCandidates.isEmpty {
                        NavigationLink("Playfield") {
                            HostedImageView(imageCandidates: game.fullscreenPlayfieldCandidates)
                        }
                        .buttonStyle(.glass)
                    }
                }

                if playableVideos.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
                            )
                        Text("No videos listed.")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                } else {
                    if let activeVideoID {
                        PracticeEmbeddedYouTubeView(videoID: activeVideoID)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(playableVideos) { video in
                            Button {
                                activeVideoID = video.id
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    PracticeYouTubeThumbnailView(candidates: video.thumbnailCandidates)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Text(video.label)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    activeVideoID == video.id
                                        ? Color(uiColor: .secondarySystemFill)
                                        : Color(uiColor: .tertiarySystemFill)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(uiColor: .separator).opacity(activeVideoID == video.id ? 0.8 : 0.5), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("Select a game to load rulesheet, playfield, and videos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
        .onAppear {
            if activeVideoID == nil {
                activeVideoID = playableVideos.first?.id
            }
        }
        .onChange(of: selectedGameID) { _, _ in
            activeVideoID = playableVideos.first?.id
        }
    }

    private var gameLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let logs = store.gameJournalEntries(for: selectedGameID)
            if logs.isEmpty {
                Text("No actions logged yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(logs) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.journalSummary(for: entry))
                                    .font(.footnote)
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if entry.id != logs.last?.id {
                                Divider().overlay(.white.opacity(0.14))
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var gameInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task-specific logging")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(StudyTaskKind.allCases) { task in
                Button {
                    entryTask = task
                } label: {
                    HStack {
                        Text(task.label)
                        Spacer()
                        Image(systemName: "plus.circle")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
            }

            Button {
                showingScoreSheet = true
            } label: {
                HStack {
                    Text("Log score")
                    Spacer()
                    Image(systemName: "plus.circle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.glass)
        }
    }

    private var gameSummaryView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let group = store.activeGroup(for: selectedGameID) {
                let taskProgress = Dictionary(
                    uniqueKeysWithValues: StudyTaskKind.allCases.map { task in
                        (
                            task,
                            store.latestTaskProgress(
                                gameID: selectedGameID,
                                task: task,
                                startDate: group.startDate,
                                endDate: group.endDate
                            )
                        )
                    }
                )
                HStack(spacing: 10) {
                    GroupProgressWheel(
                        taskProgress: taskProgress
                    )
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.footnote.weight(.semibold))
                        Text(wheelProgressSummary(taskProgress: taskProgress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let next = nextAction(gameID: selectedGameID) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Action")
                        .font(.footnote.weight(.semibold))
                    Text(next)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            let alerts = store.dashboardAlerts(for: selectedGameID)
            if !alerts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alerts")
                        .font(.footnote.weight(.semibold))
                    ForEach(alerts) { alert in
                        Text("• \(alert.message)")
                            .font(.footnote)
                            .foregroundStyle(alertColor(alert.severity))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Consistency")
                    .font(.footnote.weight(.semibold))

                if let summary = store.scoreSummary(for: selectedGameID), summary.median > 0 {
                    let spreadRatio = (summary.p75 - summary.floor) / summary.median
                    Text(
                        spreadRatio >= 0.6
                            ? "High variance: raise floor through repeatable safe scoring paths."
                            : "Stable spread: keep pressure on median improvements."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Log more scores to unlock floor/variance guidance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Score Stats")
                        .font(.footnote.weight(.semibold))

                    if let stats = scoreStats(for: selectedGameID) {
                        statRow("High", formatScore(stats.high), color: AppTheme.statsHigh)
                        statRow("Low", formatScore(stats.low), color: AppTheme.statsLow)
                        statRow("Mean", formatScore(stats.mean), color: AppTheme.statsMeanMedian)
                        statRow("Median", formatScore(stats.median), color: AppTheme.statsMeanMedian)
                        statRow("St Dev", formatScore(stats.stdev), color: .secondary)
                    } else {
                        Text("Log scores to unlock.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Scores")
                        .font(.footnote.weight(.semibold))

                    if let targets = store.leagueTargetScores(for: selectedGameID) {
                        statRow("2nd", formatScore(targets.great), color: AppTheme.targetGreat)
                        statRow("4th", formatScore(targets.main), color: AppTheme.targetMain)
                        statRow("8th", formatScore(targets.floor), color: AppTheme.targetFloor)
                    } else {
                        Text("No target data yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(color)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func wheelProgressSummary(taskProgress: [StudyTaskKind: Int]) -> String {
        let ordered = StudyTaskKind.allCases.map { task in
            let label: String
            switch task {
            case .playfield: label = "Playfield"
            case .rulesheet: label = "Rules"
            case .tutorialVideo: label = "Tutorial"
            case .gameplayVideo: label = "Gameplay"
            case .practice: label = "Practice"
            }
            return "\(label) \(taskProgress[task] ?? 0)%"
        }
        return ordered.joined(separator: "  •  ")
    }

    private struct ScoreStats {
        let high: Double
        let low: Double
        let mean: Double
        let median: Double
        let stdev: Double
    }

    private func scoreStats(for gameID: String) -> ScoreStats? {
        let values = store.recentScores(for: gameID, limit: 10_000).map(\.score).sorted()
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let median: Double
        if values.count % 2 == 0 {
            let upper = values.count / 2
            median = (values[upper - 1] + values[upper]) / 2
        } else {
            median = values[values.count / 2]
        }
        let variance = values.reduce(0) { partial, value in
            let delta = value - mean
            return partial + (delta * delta)
        } / Double(values.count)

        return ScoreStats(
            high: values.last ?? mean,
            low: values.first ?? mean,
            mean: mean,
            median: median,
            stdev: variance.squareRoot()
        )
    }

    private func formatScore(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    private func nextAction(gameID: String) -> String? {
        let rows = store.gameTaskSummary(for: gameID)
        if let missing = rows.first(where: { $0.count == 0 }) {
            return "Start with \(missing.task.label.lowercased()) for this game."
        }

        let stale = rows.compactMap { row -> (StudyTaskKind, Int)? in
            guard let ts = row.lastTimestamp else { return nil }
            let days = Calendar.current.dateComponents([.day], from: ts, to: Date()).day ?? 0
            return (row.task, days)
        }
        .max(by: { $0.1 < $1.1 })

        if let stale, stale.1 >= 14 {
            return "Refresh \(stale.0.label.lowercased()) - last update was \(stale.1) days ago."
        }

        return "Continue practice and add a fresh score to track trend changes."
    }

    private func alertColor(_ severity: PracticeDashboardAlert.Severity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .caution:
            return .yellow
        }
    }

    private func showSaveBanner(_ message: String) {
        saveBanner = message
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if saveBanner == message {
                saveBanner = nil
            }
        }
    }
}

struct GameScoreEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 420) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Score", text: formattedScoreBinding)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        Picker("Context", selection: $scoreContext) {
                            ForEach(ScoreContext.allCases) { context in
                                Text(context.label).tag(context)
                            }
                        }
                        .pickerStyle(.segmented)

                        if scoreContext == .tournament {
                            TextField("Tournament name", text: $tournamentName)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .appControlStyle()
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Log Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
    }

    private func save() -> Bool {
        validationMessage = nil
        let normalized = scoreText.replacingOccurrences(of: ",", with: "")
        guard let score = Double(normalized), score > 0 else {
            validationMessage = "Enter a valid score above 0."
            return false
        }
        store.addScore(gameID: gameID, score: score, context: scoreContext, tournamentName: tournamentName)
        return true
    }

    private var formattedScoreBinding: Binding<String> {
        Binding(
            get: { scoreText },
            set: { scoreText = formatScoreInputWithCommas($0) }
        )
    }
}

private func formatScoreInputWithCommas(_ raw: String) -> String {
    let digits = raw.filter(\.isNumber)
    guard !digits.isEmpty else { return "" }
    var grouped: [String] = []
    var remaining = String(digits)
    while remaining.count > 3 {
        let cut = remaining.index(remaining.endIndex, offsetBy: -3)
        grouped.insert(String(remaining[cut...]), at: 0)
        remaining = String(remaining[..<cut])
    }
    grouped.insert(remaining, at: 0)
    return grouped.joined(separator: ",")
}

struct GameNoteEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var category: PracticeCategory = .general
    @State private var detail: String = ""
    @State private var note: String = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 460) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Category", selection: $category) {
                            ForEach(noteCategories) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Optional detail (mode/shot/skill)", text: $detail)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        TextField("Note", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        let detectedTags = store.detectedMechanicsTags(in: "\(detail) \(note)")
                        if !detectedTags.isEmpty {
                            Text("Detected mechanics: \(detectedTags.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
    }

    private var noteCategories: [PracticeCategory] {
        [.general, .shots, .modes, .multiball, .strategy]
    }

    private func save() -> Bool {
        validationMessage = nil
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Note cannot be empty."
            return false
        }
        store.addNote(gameID: gameID, category: category, detail: detail, note: trimmed)
        return true
    }
}

struct GameTaskEntrySheet: View {
    let task: StudyTaskKind
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rulesheetProgress: Double = 0
    @State private var videoKind: VideoProgressInputKind = .clock
    @State private var selectedVideoSource: String = ""
    @State private var videoWatchedTime: String = ""
    @State private var videoTotalTime: String = ""
    @State private var videoPercent: Double = 100
    @State private var practiceMinutes: String = ""
    @State private var noteText: String = ""
    @State private var validationMessage: String?

    private var selectedGame: PinballGame? {
        store.games.first(where: { $0.id == gameID })
    }

    private var videoSourceOptions: [String] {
        guard task == .tutorialVideo || task == .gameplayVideo else { return [] }
        return practiceVideoSourceOptions(game: selectedGame, task: task)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionCard("Task") {
                                Text(task.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }

                            sectionCard("Details") {
                                switch task {
                                case .rulesheet:
                                    sliderRow(title: "Rulesheet progress", value: $rulesheetProgress)
                                    styledTextField("Optional note", text: $noteText, axis: .vertical)
                                case .tutorialVideo, .gameplayVideo:
                                    Picker("Video", selection: $selectedVideoSource) {
                                        ForEach(videoSourceOptions, id: \.self) { source in
                                            Text(source).tag(source)
                                        }
                                    }
                                    .pickerStyle(.menu)

                                    Picker("Input mode", selection: $videoKind) {
                                        ForEach(VideoProgressInputKind.allCases) { kind in
                                            Text(kind.label).tag(kind)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    if videoKind == .clock {
                                        styledTextField(
                                            "Amount watched (hh:mm:ss)",
                                            text: $videoWatchedTime,
                                            keyboard: .numbersAndPunctuation
                                        )
                                        styledTextField(
                                            "Total length (hh:mm:ss)",
                                            text: $videoTotalTime,
                                            keyboard: .numbersAndPunctuation
                                        )
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
                                    styledTextField("Optional note", text: $noteText, axis: .vertical)
                                }
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() {
                            onSaved("\(task.label) saved")
                            dismiss()
                        }
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
        .onAppear {
            if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                selectedVideoSource = videoSourceOptions.first ?? ""
            }
        }
        .onChange(of: task) { _, _ in
            if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                selectedVideoSource = videoSourceOptions.first ?? ""
            }
        }
        .onChange(of: gameID) { _, _ in
            if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                selectedVideoSource = videoSourceOptions.first ?? ""
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

    @discardableResult
    private func save() -> Bool {
        validationMessage = nil
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmedNote.isEmpty ? nil : trimmedNote

        switch task {
        case .rulesheet:
            store.addGameTaskEntry(
                gameID: gameID,
                task: .rulesheet,
                progressPercent: Int(rulesheetProgress.rounded()),
                note: note
            )
            return true

        case .tutorialVideo, .gameplayVideo:
            guard let videoDraft = buildVideoLogDraft(
                inputKind: videoKind,
                sourceLabel: selectedVideoSource,
                watchedTime: videoWatchedTime,
                totalTime: videoTotalTime,
                percentValue: videoPercent
            ) else {
                validationMessage = "Use valid hh:mm:ss watched/total values (or leave both blank for 100%)."
                return false
            }

            let action: JournalActionType = task == .tutorialVideo ? .tutorialWatch : .gameplayWatch
            store.addManualVideoProgress(
                gameID: gameID,
                action: action,
                kind: videoDraft.kind,
                value: videoDraft.value,
                progressPercent: videoDraft.progressPercent,
                note: note
            )
            return true

        case .playfield:
            store.addGameTaskEntry(
                gameID: gameID,
                task: .playfield,
                progressPercent: nil,
                note: note ?? "Reviewed playfield image"
            )
            return true

        case .practice:
            let trimmedMinutes = practiceMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedMinutes.isEmpty,
               (Int(trimmedMinutes) == nil || Int(trimmedMinutes) ?? 0 <= 0) {
                validationMessage = "Practice minutes must be a whole number greater than 0 when entered."
                return false
            }

            let composedNote: String?
            if let minutes = Int(trimmedMinutes), minutes > 0 {
                let prefix = "Practice session: \(minutes) minute\(minutes == 1 ? "" : "s")"
                if let note {
                    composedNote = "\(prefix). \(note)"
                } else {
                    composedNote = prefix
                }
            } else {
                composedNote = note ?? "Practice session"
            }

            store.addGameTaskEntry(
                gameID: gameID,
                task: .practice,
                progressPercent: nil,
                note: composedNote
            )
            return true
        }
    }
}

private struct PracticeEmbeddedYouTubeView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1" />
          <style>
            html, body { margin: 0; padding: 0; background: #000; height: 100%; }
            iframe { border: 0; width: 100%; height: 100%; }
          </style>
        </head>
        <body>
          <iframe
            src="https://www.youtube-nocookie.com/embed/\(videoID)"
            title="YouTube video player"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen>
          </iframe>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
}

private struct PracticeYouTubeThumbnailView: View {
    let candidates: [URL]
    @State private var index = 0

    var body: some View {
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil

        AsyncImage(url: currentURL) { phase in
            switch phase {
            case .empty:
                Color(uiColor: .tertiarySystemBackground)
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                if index + 1 < candidates.count {
                    Color(uiColor: .tertiarySystemBackground)
                        .task { index += 1 }
                } else {
                    Color(uiColor: .tertiarySystemBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            @unknown default:
                Color(uiColor: .tertiarySystemBackground)
            }
        }
    }
}
