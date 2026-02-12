import SwiftUI

private enum PracticeGameSubview: String, CaseIterable, Identifiable {
    case log
    case input
    case summary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .log: return "Log"
        case .input: return "Input"
        case .summary: return "Summary"
        }
    }
}

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeUpgradeStore
    @Binding var selectedGameID: String

    @State private var subview: PracticeGameSubview = .log
    @State private var entryTask: StudyTaskKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game")
                .font(.headline)

            gamePicker

            Picker("Mode", selection: $subview) {
                ForEach(PracticeGameSubview.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch subview {
                case .log:
                    gameLogView
                case .input:
                    gameInputView
                case .summary:
                    gameSummaryView
                }
            }
        }
        .padding(12)
        .appPanelStyle()
        .onAppear {
            if selectedGameID.isEmpty, let first = store.games.first {
                selectedGameID = first.id
            }
        }
        .sheet(item: $entryTask) { task in
            GameTaskEntrySheet(task: task, gameID: selectedGameID, store: store)
        }
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

    private var gameLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let logs = store.gameJournalEntries(for: selectedGameID)
            if logs.isEmpty {
                Text("No actions logged yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs.prefix(30)) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.journalSummary(for: entry))
                            .font(.footnote)
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var gameInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap a task to add a timestamped entry")
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
        }
    }

    private var gameSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summarized by key tasks")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(store.gameTaskSummary(for: selectedGameID)) { row in
                VStack(alignment: .leading, spacing: 2) {
                    let progressLabel = row.latestProgress.map { "\($0)%" } ?? "n/a"
                    Text("\(row.task.label): \(row.count) entries • latest progress \(progressLabel)")
                        .font(.footnote)

                    if let ts = row.lastTimestamp {
                        Text("Last update: \(ts.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Last update: none")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct GameTaskEntrySheet: View {
    let task: StudyTaskKind
    let gameID: String
    @ObservedObject var store: PracticeUpgradeStore

    @Environment(\.dismiss) private var dismiss

    @State private var progressText: String = ""
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    Text(task.label)
                }

                Section("Details") {
                    TextField("Progress percent (optional)", text: $progressText)
                        .keyboardType(.numberPad)
                    TextField("Note (optional)", text: $noteText, axis: .vertical)
                        .lineLimit(2 ... 4)
                }

                Section {
                    Text("Saving adds a timestamped log entry for this game.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmedNote.isEmpty ? nil : trimmedNote

        if let progress = Int(progressText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            store.addGameTaskEntry(gameID: gameID, task: task, progressPercent: progress, note: note)
        } else {
            store.addGameTaskEntry(gameID: gameID, task: task, progressPercent: nil, note: note)
        }
    }
}
