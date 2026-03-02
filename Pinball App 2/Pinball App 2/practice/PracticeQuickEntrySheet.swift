import SwiftUI

let quickEntryAllGamesLibraryID = "__all_games__"
private let preferredLibrarySourceDefaultsKey = "preferred-library-source-id"

struct PracticeQuickEntrySheet: View {
    let kind: QuickEntrySheet
    let initialActivity: QuickEntryActivity?
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
    @State private var practiceCategory: PracticeCategory = .general
    @State private var mechanicsSkill: String = ""
    @State private var mechanicsCompetency: Double = 3
    @State private var mechanicsNote: String = ""
    @State private var noteText: String = ""
    @State private var validationMessage: String?
    @State private var selectedLibraryFilterID: String = ""

    init(
        kind: QuickEntrySheet,
        initialActivity: QuickEntryActivity? = nil,
        store: PracticeStore,
        selectedGameID: Binding<String>,
        onGameSelectionChanged: @escaping (QuickEntrySheet, String) -> Void,
        onEntrySaved: @escaping (String) -> Void
    ) {
        self.kind = kind
        self.initialActivity = initialActivity
        self.store = store
        _selectedGameID = selectedGameID
        self.onGameSelectionChanged = onGameSelectionChanged
        self.onEntrySaved = onEntrySaved
    }

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

    private var avenueLibrarySourceIDForQuickEntry: String? {
        availableLibrarySources.first(where: { $0.id == "venue--the-avenue-cafe" })?.id
            ?? availableLibrarySources.first(where: { $0.id == "the-avenue" })?.id
            ?? availableLibrarySources.first(where: { $0.name.localizedCaseInsensitiveContains("the avenue") })?.id
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
        let preferredSourceID = (selectedLibraryFilterID == quickEntryAllGamesLibraryID || selectedLibraryFilterID.isEmpty) ? nil : selectedLibraryFilterID
        return practiceVideoSourceOptions(
            store: store,
            gameID: selectedGameID,
            task: task,
            preferredSourceID: preferredSourceID
        )
    }

    private var selectedLibraryFilterLabel: String {
        if selectedLibraryFilterID.isEmpty || selectedLibraryFilterID == quickEntryAllGamesLibraryID {
            return "All games"
        }
        return availableLibrarySources.first(where: { $0.id == selectedLibraryFilterID })?.name ?? "Location"
    }

    private var selectedGameLabel: String {
        if kind == .mechanics, selectedGameID.isEmpty {
            return "None"
        }
        if filteredGamesForPicker.isEmpty {
            return "No game data"
        }
        return store.gameForAnyID(selectedGameID)?.name
            ?? orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true)
                .first(where: { $0.canonicalPracticeKey == selectedGameID })?.name
            ?? "Game"
    }

    private var selectedActivityLabel: String {
        selectedActivity.label
    }

    private var selectedVideoSourceLabel: String {
        let trimmed = selectedVideoSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Video" : trimmed
    }

    private var selectedMechanicsSkillLabel: String {
        let trimmed = mechanicsSkill.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Skill" : trimmed
    }

    private var quickPracticeCategories: [PracticeCategory] {
        [.general, .modes, .multiball, .shots]
    }

    private var selectedPracticeCategoryLabel: String {
        switch practiceCategory {
        case .general: return "General"
        case .modes: return "Modes"
        case .multiball: return "Multiball"
        case .shots: return "Shots"
        case .strategy: return "Strategy"
        }
    }

    var body: some View {
        let gameOptions = orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true)
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 6) {
                                libraryFilterMenu
                                gameSelectionMenu(gameOptions: gameOptions)
                            }
                            .onChange(of: gameOptions.count) { _, _ in
                                if kind != .mechanics,
                                   selectedGameID.isEmpty,
                                   let first = orderedGamesForDropdown(filteredGamesForPicker, collapseByPracticeIdentity: true).first {
                                    selectedGameID = first.canonicalPracticeKey
                                }
                            }

                            if showsActivityPicker {
                                Menu {
                                    ForEach(availableActivities) { activity in
                                        Button {
                                            selectedActivity = activity
                                        } label: {
                                            if selectedActivity == activity {
                                                Label(activity.label, systemImage: "checkmark")
                                            } else {
                                                Text(activity.label)
                                            }
                                        }
                                    }
                                }
                                label: {
                                    compactDropdownLabel(text: selectedActivityLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Activity")
                            }

                            switch selectedActivity {
                            case .score:
                                TextField("Score", text: $scoreText)
                                    .font(.subheadline)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .monospacedDigit()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .appControlStyle()
                                    .onChange(of: scoreText) { _, newValue in
                                        let formatted = formatScoreInputWithCommas(newValue)
                                        if formatted != newValue { scoreText = formatted }
                                    }

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
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .tutorialVideo, .gameplayVideo:
                                Menu {
                                    ForEach(videoSourceOptions, id: \.self) { source in
                                        Button {
                                            selectedVideoSource = source
                                        } label: {
                                            if selectedVideoSource == source {
                                                Label(source, systemImage: "checkmark")
                                            } else {
                                                Text(source)
                                            }
                                        }
                                    }
                                }
                                label: {
                                    compactDropdownLabel(text: selectedVideoSourceLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Video")

                                Picker("Input mode", selection: $videoKind) {
                                    ForEach(VideoProgressInputKind.allCases) { kind in
                                        Text(kind.label).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if videoKind == .clock {
                                    HStack(alignment: .top, spacing: 10) {
                                        PracticeTimePopoverField(title: "Watched", value: $videoWatchedTime)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        PracticeTimePopoverField(title: "Duration", value: $videoTotalTime)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } else {
                                    sliderRow(title: "Percent watched", value: $videoPercent)
                                }

                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .playfield:
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .practice:
                                Menu {
                                    ForEach(quickPracticeCategories) { category in
                                        Button {
                                            practiceCategory = category
                                        } label: {
                                            if practiceCategory == category {
                                                Label(
                                                    category == .general ? "General" : category.label,
                                                    systemImage: "checkmark"
                                                )
                                            } else {
                                                Text(category == .general ? "General" : category.label)
                                            }
                                        }
                                    }
                                }
                                label: {
                                    compactDropdownLabel(text: selectedPracticeCategoryLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Practice type")

                                styledTextField("Practice minutes (optional)", text: $practiceMinutes, keyboard: .numberPad)
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .mechanics:
                                Menu {
                                    ForEach(store.allTrackedMechanicsSkills(), id: \.self) { skill in
                                        Button {
                                            mechanicsSkill = skill
                                        } label: {
                                            if mechanicsSkill == skill {
                                                Label(skill, systemImage: "checkmark")
                                            } else {
                                                Text(skill)
                                            }
                                        }
                                    }
                                }
                                label: {
                                    compactDropdownLabel(text: selectedMechanicsSkillLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Skill")

                                HStack {
                                    Text("Competency")
                                    Spacer()
                                    Text("\(Int(mechanicsCompetency))/5")
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                }
                                Slider(value: $mechanicsCompetency, in: 1...5, step: 1)

                                styledMultilineTextEditor("Optional notes", text: $mechanicsNote)

                                let detected = store.detectedMechanicsTags(in: mechanicsNote)
                                if !detected.isEmpty {
                                    Text("Detected tags: \(detected.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                let requestedActivity = initialActivity ?? kind.defaultActivity
                selectedActivity = availableActivities.contains(requestedActivity) ? requestedActivity : kind.defaultActivity
                if selectedLibraryFilterID.isEmpty {
                    if kind == .mechanics {
                        selectedLibraryFilterID = quickEntryAllGamesLibraryID
                    } else {
                        selectedLibraryFilterID =
                            avenueLibrarySourceIDForQuickEntry
                            ?? store.defaultPracticeSourceID
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

    private func compactDropdownLabel(text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appControlStyle()
    }

    @ViewBuilder
    private var libraryFilterMenu: some View {
        if availableLibrarySources.count > 1 {
            Menu {
                Button {
                    selectedLibraryFilterID = quickEntryAllGamesLibraryID
                } label: {
                    if selectedLibraryFilterID == quickEntryAllGamesLibraryID || selectedLibraryFilterID.isEmpty {
                        Label("All games", systemImage: "checkmark")
                    } else {
                        Text("All games")
                    }
                }
                ForEach(availableLibrarySources) { source in
                    Button {
                        selectedLibraryFilterID = source.id
                    } label: {
                        if selectedLibraryFilterID == source.id {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            }
            label: {
                compactDropdownLabel(text: selectedLibraryFilterLabel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Location")
        }
    }

    private func gameSelectionMenu(gameOptions: [PinballGame]) -> some View {
        Menu {
            if kind == .mechanics {
                Button {
                    selectedGameID = ""
                } label: {
                    if selectedGameID.isEmpty {
                        Label("None", systemImage: "checkmark")
                    } else {
                        Text("None")
                    }
                }
            }
            if filteredGamesForPicker.isEmpty {
                Text("No game data")
            } else {
                ForEach(gameOptions) { game in
                    Button {
                        selectedGameID = game.canonicalPracticeKey
                    } label: {
                        if selectedGameID == game.canonicalPracticeKey {
                            Label(game.name, systemImage: "checkmark")
                        } else {
                            Text(game.name)
                        }
                    }
                }
            }
        }
        label: {
            compactDropdownLabel(text: selectedGameLabel)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Game")
    }

    @ViewBuilder
    private func styledTextField(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        keyboard: UIKeyboardType = .default,
        textAlignment: TextAlignment = .leading,
        monospacedDigits: Bool = false
    ) -> some View {
        let field = TextField(placeholder, text: text, axis: axis)
            .font(.subheadline)
            .keyboardType(keyboard)
            .lineLimit(axis == .vertical ? 2 ... 4 : 1 ... 1)
            .multilineTextAlignment(textAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        if monospacedDigits { field.monospacedDigit() } else { field }
    }

    @ViewBuilder
    private func styledMultilineTextEditor(_ placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(minHeight: 88, maxHeight: 96)
        .appControlStyle()
    }

    private func sliderRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(.white.opacity(0.92))
                .padding(.horizontal, 2)
        }
    }

    private func save() -> String? {
        validationMessage = nil
        let normalizedNoteText = noteText.replacingOccurrences(of: "\r\n", with: "\n")
        let trimmedNote = normalizedNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmedNote.isEmpty ? nil : normalizedNoteText

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
            let focusLine: String? = practiceCategory == .general ? nil : "Focus: \(selectedPracticeCategoryLabel)"
            let composedNote: String?
            if let minutes = Int(trimmedMinutes), minutes > 0 {
                let prefix = "Practice session: \(minutes) minute\(minutes == 1 ? "" : "s")"
                let tail = [focusLine, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
                composedNote = tail.isEmpty ? prefix : "\(prefix). \(tail)"
            } else {
                let base = "Practice session"
                let tail = [focusLine, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
                composedNote = tail.isEmpty ? base : "\(base). \(tail)"
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
            let normalizedMechanicsNote = mechanicsNote.replacingOccurrences(of: "\r\n", with: "\n")
            let rawNote = normalizedMechanicsNote.trimmingCharacters(in: .whitespacesAndNewlines)
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
