import SwiftUI

struct PracticeJournalEditorGamePickerSection: View {
    let gameOptions: [PinballGame]
    @Binding var gameID: String

    var body: some View {
        Section("Game") {
            Picker("Title", selection: $gameID) {
                ForEach(gameOptions) { game in
                    Text(game.name).tag(game.canonicalPracticeKey)
                }
            }
        }
    }
}

struct PracticeJournalEditorScoreEntrySection: View {
    @Binding var scoreText: String
    @Binding var scoreContext: ScoreContext
    @Binding var tournamentName: String

    var body: some View {
        Section("Score") {
            TextField("Score", text: $scoreText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onChange(of: scoreText) { _, newValue in
                    let formatted = formatJournalScoreInputWithCommas(newValue)
                    if formatted != newValue {
                        scoreText = formatted
                    }
                }
            Picker("Context", selection: $scoreContext) {
                ForEach(ScoreContext.allCases) { context in
                    Text(context.label).tag(context)
                }
            }
            if scoreContext == .tournament {
                TextField("Tournament name", text: $tournamentName)
            }
        }
    }
}

struct PracticeJournalEditorNoteEntrySection: View {
    @Binding var noteCategory: PracticeCategory
    @Binding var noteDetail: String
    @Binding var noteText: String

    var body: some View {
        Section("Note") {
            Picker("Category", selection: $noteCategory) {
                ForEach(PracticeCategory.allCases) { category in
                    Text(category.label).tag(category)
                }
            }
            TextField("Detail (optional)", text: $noteDetail)
            PracticeJournalStyledNoteEditor(text: $noteText)
        }
    }
}

struct PracticeJournalEditorStudyEntrySection: View {
    @Binding var studyProgressEnabled: Bool
    @Binding var studyProgressPercent: Double
    @Binding var journalNoteText: String

    var body: some View {
        Section("Entry") {
            PracticeJournalProgressFields(
                studyProgressEnabled: $studyProgressEnabled,
                studyProgressPercent: $studyProgressPercent
            )
            PracticeJournalOptionalNoteSection(text: $journalNoteText)
        }
    }
}

struct PracticeJournalEditorVideoProgressSection: View {
    @Binding var videoKind: VideoProgressInputKind
    @Binding var videoValue: String
    @Binding var studyProgressEnabled: Bool
    @Binding var studyProgressPercent: Double
    @Binding var journalNoteText: String

    var body: some View {
        Section("Video Progress") {
            Picker("Format", selection: $videoKind) {
                ForEach(VideoProgressInputKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            TextField(
                videoKind == .clock ? "Value (e.g. 00:12:34 / 00:45:00)" : "Value (e.g. 60%)",
                text: $videoValue,
                axis: .vertical
            )
            .lineLimit(1...3)

            PracticeJournalProgressFields(
                studyProgressEnabled: $studyProgressEnabled,
                studyProgressPercent: $studyProgressPercent
            )
            PracticeJournalOptionalNoteSection(text: $journalNoteText)
        }
    }
}

struct PracticeJournalEditorUnsupportedEntrySection: View {
    var body: some View {
        Section {
            Text("Editing is only supported for score and note entries right now.")
                .foregroundStyle(.secondary)
        }
    }
}

struct PracticeJournalEditorValidationSection: View {
    let validationMessage: String?

    var body: some View {
        if let validationMessage {
            Section {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct PracticeJournalProgressFields: View {
    @Binding var studyProgressEnabled: Bool
    @Binding var studyProgressPercent: Double

    var body: some View {
        Group {
            Toggle("Track progress", isOn: $studyProgressEnabled)
            if studyProgressEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text("\(roundedStudyProgress)%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $studyProgressPercent, in: 0...100, step: 1)
                }
            }
        }
    }

    private var roundedStudyProgress: Int {
        Int(studyProgressPercent.rounded())
    }
}

struct PracticeJournalOptionalNoteSection: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)
            PracticeJournalStyledNoteEditor(text: $text)
        }
    }
}

struct PracticeJournalStyledNoteEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 88, maxHeight: 96)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .appControlStyle()
    }
}

func formatJournalScoreInputWithCommas(_ raw: String) -> String {
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
