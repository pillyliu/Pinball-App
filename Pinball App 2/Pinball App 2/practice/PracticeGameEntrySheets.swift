import SwiftUI

struct GameScoreEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var validationMessage: String?
    @State private var showingScoreScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 420) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Score", text: $scoreText)
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

                        Button {
                            showingScoreScanner = true
                        } label: {
                            Label("Scan Score", systemImage: "viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .appControlStyle()

                        Picker("Context", selection: $scoreContext) {
                            ForEach(ScoreContext.allCases) { context in
                                Text(context.label).tag(context)
                            }
                        }
                        .appSegmentedControlStyle()

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
            .fullScreenCover(isPresented: $showingScoreScanner) {
                ScoreScannerView(
                    onUseReading: { score in
                        scoreText = ScoreParsingService.formattedScore(score: score)
                        validationMessage = nil
                        showingScoreScanner = false
                    },
                    onClose: {
                        showingScoreScanner = false
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: gameID.isEmpty) {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
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
                    AppToolbarCancelAction {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: gameID.isEmpty) {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
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
    @State private var practiceCategory: PracticeCategory = .general
    @State private var noteText: String = ""
    @State private var validationMessage: String?

    private var selectedGame: PinballGame? {
        store.games.first(where: { $0.id == gameID })
    }

    private var videoSourceOptions: [String] {
        guard task == .tutorialVideo || task == .gameplayVideo else { return [] }
        return practiceVideoSourceOptions(store: store, gameID: gameID, task: task)
    }

    private var quickPracticeCategories: [PracticeCategory] {
        [.general, .modes, .multiball, .shots]
    }

    private var selectedVideoSourceLabel: String {
        let trimmed = selectedVideoSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Video" : trimmed
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
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            switch task {
                            case .rulesheet:
                                sliderRow(title: "Rulesheet progress", value: $rulesheetProgress)
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .tutorialVideo, .gameplayVideo:
                                Menu {
                                    ForEach(videoSourceOptions, id: \.self) { source in
                                        Button {
                                            selectedVideoSource = source
                                        } label: {
                                            AppSelectableMenuRow(text: source, isSelected: selectedVideoSource == source)
                                        }
                                }
                                } label: {
                                    AppCompactDropdownLabel(text: selectedVideoSourceLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Video")

                                Picker("Input mode", selection: $videoKind) {
                                    ForEach(VideoProgressInputKind.allCases) { kind in
                                        Text(kind.label).tag(kind)
                                    }
                                }
                                .appSegmentedControlStyle()

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
                                            AppSelectableMenuRow(
                                                text: category == .general ? "General" : category.label,
                                                isSelected: practiceCategory == category
                                            )
                                        }
                                    }
                                } label: {
                                    AppCompactDropdownLabel(text: selectedPracticeCategoryLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Practice type")

                                styledTextField("Practice minutes (optional)", text: $practiceMinutes, keyboard: .numberPad)
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            }

                            if let validationMessage {
                                Text(validationMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
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
                    AppToolbarCancelAction {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: gameID.isEmpty) {
                        if save() {
                            onSaved("\(task.label) saved")
                            dismiss()
                        }
                    }
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

            let practiceTypeLabel: String = switch practiceCategory {
            case .general: "General"
            case .modes: "Modes"
            case .multiball: "Multiball"
            case .shots: "Shots"
            case .strategy: "Strategy"
            }
            let focusLine: String? = practiceCategory == .general ? nil : "Focus: \(practiceTypeLabel)"

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
                gameID: gameID,
                task: .practice,
                progressPercent: nil,
                note: composedNote
            )
            return true
        }
    }
}
