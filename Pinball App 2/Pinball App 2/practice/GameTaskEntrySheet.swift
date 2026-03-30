import SwiftUI

struct GameTaskEntrySheet: View {
    let task: StudyTaskKind
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rulesheetProgress: Double = 0
    @State private var videoKind: VideoProgressInputKind = defaultPracticeVideoInputKind
    @State private var selectedVideoSource: String = ""
    @State private var videoWatchedTime: String = ""
    @State private var videoTotalTime: String = ""
    @State private var videoPercent: Double = 100
    @State private var practiceMinutes: String = ""
    @State private var practiceCategory: PracticeCategory = .general
    @State private var noteText: String = ""
    @State private var validationMessage: String?

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
        practiceQuickEntryCategoryLabel(practiceCategory)
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
                                practiceEntrySliderRow(title: "Rulesheet progress", value: $rulesheetProgress)
                                practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)
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
                                    ForEach(practiceVideoInputKindOptions) { kind in
                                        Text(practiceVideoInputKindLabel(kind)).tag(kind)
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
                                    practiceEntrySliderRow(title: "Percent watched", value: $videoPercent)
                                }

                                practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)
                            case .playfield:
                                practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)
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

                                practiceEntryStyledTextField("Practice minutes (optional)", text: $practiceMinutes, keyboard: .numberPad)
                                practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)
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
            syncSelectedVideoSource()
        }
        .onChange(of: task) { _, _ in
            syncSelectedVideoSource()
        }
        .onChange(of: gameID) { _, _ in
            syncSelectedVideoSource()
        }
    }

    private func syncSelectedVideoSource() {
        if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
            selectedVideoSource = videoSourceOptions.first ?? ""
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

            let focusLine: String? = practiceCategory == .general ? nil : "Focus: \(practiceQuickEntryCategoryLabel(practiceCategory))"

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
