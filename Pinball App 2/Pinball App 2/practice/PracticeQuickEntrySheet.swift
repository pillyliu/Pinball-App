import SwiftUI

let quickEntryAllGamesLibraryID = "__all_games__"
private let preferredLibrarySourceDefaultsKey = "preferred-library-source-id"

struct PracticeQuickEntrySheet: View {
    let kind: QuickEntrySheet
    @ObservedObject var store: PracticeStore
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
    @State private var selectedVideoSource: String = ""
    @State private var videoWatchedTime: String = ""
    @State private var videoTotalTime: String = ""
    @State private var videoPercent: Double = 100
    @State private var practiceMinutes: String = ""
    @State private var mechanicsSkill: String = ""
    @State private var mechanicsCompetency: Double = 3
    @State private var mechanicsNote: String = ""
    @State private var noteText: String = ""
    @State private var validationMessage: String?
    @State private var selectedLibraryFilterID: String = ""

    private var availableActivities: [QuickEntryActivity] {
        switch kind {
        case .score:
            return [.score]
        case .study:
            return [.rulesheet, .tutorialVideo, .gameplayVideo, .playfield]
        case .practice:
            return [.practice]
        case .mechanics:
            return [.mechanics]
        }
    }

    private var showsActivityPicker: Bool {
        kind == .study
    }

    private var selectedGame: PinballGame? {
        store.gameForAnyID(selectedGameID)
    }

    private var allLibraryGamesForPicker: [PinballGame] {
        store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames
    }

    private var availableLibrarySources: [PinballLibrarySource] {
        store.librarySources.isEmpty ? inferPracticeLibrarySources(from: allLibraryGamesForPicker) : store.librarySources
    }

    private var filteredGamesForPicker: [PinballGame] {
        let selected = selectedLibraryFilterID.trimmingCharacters(in: .whitespacesAndNewlines)
        if selected.isEmpty || selected == quickEntryAllGamesLibraryID {
            return allLibraryGamesForPicker
        }
        return allLibraryGamesForPicker.filter { $0.sourceId == selected }
    }

    private var videoSourceOptions: [String] {
        guard selectedActivity == .tutorialVideo || selectedActivity == .gameplayVideo else { return [] }
        let task: StudyTaskKind = selectedActivity == .tutorialVideo ? .tutorialVideo : .gameplayVideo
        return practiceVideoSourceOptions(game: selectedGame, task: task)
    }

    var body: some View {
        let gameOptions = orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true, limit: 41)
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if availableLibrarySources.count > 1 {
                                Picker("Library", selection: $selectedLibraryFilterID) {
                                    Text("All games").tag(quickEntryAllGamesLibraryID)
                                    ForEach(availableLibrarySources) { source in
                                        Text(source.name).tag(source.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            Picker("Game", selection: $selectedGameID) {
                                if kind == .mechanics {
                                    Text("None").tag("")
                                }
                                if filteredGamesForPicker.isEmpty {
                                    Text("No game data").tag("")
                                } else {
                                    ForEach(gameOptions) { game in
                                        Text(game.name).tag(game.canonicalPracticeKey)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: gameOptions.count) { _, _ in
                                if kind != .mechanics,
                                   selectedGameID.isEmpty,
                                   let first = orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true).first {
                                    selectedGameID = first.canonicalPracticeKey
                                }
                            }

                            if showsActivityPicker {
                                Picker("Activity", selection: $selectedActivity) {
                                    ForEach(availableActivities) { activity in
                                        Text(activity.label).tag(activity)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            sectionCard("Details") {
                                switch selectedActivity {
                                case .score:
                                    styledTextField("Score", text: formattedScoreBinding, keyboard: .numberPad)

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
                                        styledTextField("Amount watched (hh:mm:ss)", text: $videoWatchedTime, keyboard: .numbersAndPunctuation)
                                        styledTextField("Total length (hh:mm:ss)", text: $videoTotalTime, keyboard: .numbersAndPunctuation)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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
                if selectedLibraryFilterID.isEmpty {
                    if kind == .mechanics {
                        selectedLibraryFilterID = quickEntryAllGamesLibraryID
                    } else {
                        let savedPreferredLibraryID = UserDefaults.standard.string(forKey: preferredLibrarySourceDefaultsKey)
                        selectedLibraryFilterID =
                            (savedPreferredLibraryID.flatMap { id in availableLibrarySources.contains(where: { $0.id == id }) ? id : nil })
                            ?? store.defaultPracticeSourceID
                            ?? availableLibrarySources.first(where: { $0.id == "venue--the-avenue-cafe" })?.id
                            ?? availableLibrarySources.first(where: { $0.id == "the-avenue" })?.id
                            ?? availableLibrarySources.first?.id
                            ?? quickEntryAllGamesLibraryID
                    }
                }
                if kind == .mechanics {
                    selectedGameID = ""
                } else if selectedGameID.isEmpty, let first = orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true).first {
                    selectedGameID = first.canonicalPracticeKey
                }
                if mechanicsSkill.isEmpty {
                    mechanicsSkill = store.allTrackedMechanicsSkills().first ?? ""
                }
            }
            .onChange(of: selectedGameID) { _, newValue in
                onGameSelectionChanged(kind, store.canonicalPracticeGameID(newValue))
            }
            .onChange(of: selectedActivity) { _, _ in
                if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                    selectedVideoSource = videoSourceOptions.first ?? ""
                }
            }
            .onChange(of: selectedGameID) { _, _ in
                if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                    selectedVideoSource = videoSourceOptions.first ?? ""
                }
            }
            .onChange(of: selectedLibraryFilterID) { _, _ in
                if !selectedLibraryFilterID.isEmpty, selectedLibraryFilterID != quickEntryAllGamesLibraryID {
                    UserDefaults.standard.set(selectedLibraryFilterID, forKey: preferredLibrarySourceDefaultsKey)
                }
                guard kind != .mechanics else { return }
                let filtered = orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true)
                if let selected = store.gameForAnyID(selectedGameID),
                   filtered.contains(where: { $0.canonicalPracticeKey == selected.canonicalPracticeKey }) {
                    return
                }
                selectedGameID = filtered.first?.canonicalPracticeKey ?? ""
            }
            .onAppear {
                if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                    selectedVideoSource = videoSourceOptions.first ?? ""
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

    private var formattedScoreBinding: Binding<String> {
        Binding(
            get: { scoreText },
            set: { scoreText = formatScoreInputWithCommas($0) }
        )
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
            guard let videoDraft = buildVideoLogDraft(
                inputKind: videoKind,
                sourceLabel: selectedVideoSource,
                watchedTime: videoWatchedTime,
                totalTime: videoTotalTime,
                percentValue: videoPercent
            ) else {
                validationMessage = "Use valid hh:mm:ss watched/total values (or leave both blank for 100%)."
                return nil
            }

            let action: JournalActionType = selectedActivity == .tutorialVideo ? .tutorialWatch : .gameplayWatch
            store.addManualVideoProgress(
                gameID: selectedGameID,
                action: action,
                kind: videoDraft.kind,
                value: videoDraft.value,
                progressPercent: videoDraft.progressPercent,
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
            return selectedGameID
        case .mechanics:
            let skill = mechanicsSkill.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawNote = mechanicsNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = skill.isEmpty ? "#mechanics" : "#\(skill.replacingOccurrences(of: " ", with: ""))"
            let composed = rawNote.isEmpty
                ? "\(prefix) competency \(Int(mechanicsCompetency))/5."
                : "\(prefix) competency \(Int(mechanicsCompetency))/5. \(rawNote)"
            let targetGameID = store.canonicalPracticeGameID(selectedGameID)
            store.addNote(gameID: targetGameID, category: .general, detail: skill.isEmpty ? nil : skill, note: composed)
            return targetGameID
        }
    }

}

private func inferPracticeLibrarySources(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    var out: [PinballLibrarySource] = []
    for game in games {
        if seen.insert(game.sourceId).inserted {
            out.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
        }
    }
    return out
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
