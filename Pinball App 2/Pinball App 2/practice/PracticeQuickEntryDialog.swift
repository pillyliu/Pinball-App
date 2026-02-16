import SwiftUI

struct PracticeQuickEntryDialog: View {
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
    @State private var videoValue: String = ""
    @State private var videoPercent: Double = 0
    @State private var practiceMinutes: String = ""
    @State private var practiceCategory: PracticeCategory = .general
    @State private var mechanicsSkill: String = ""
    @State private var mechanicsCompetency: Double = 3
    @State private var mechanicsNote: String = ""
    @State private var noteText: String = ""
    @State private var validationMessage: String?

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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Game", selection: $selectedGameID) {
                            if kind == .mechanics {
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
