import SwiftUI

let quickEntryAllGamesLibraryID = "__all_games__"

func resolveInitialQuickEntryLibraryFilterID(
    kind: QuickEntrySheet,
    currentSelectedGameSourceID: String,
    preferredLibrarySourceID: String,
    avenueLibrarySourceID: String,
    defaultPracticeSourceID: String,
    availableLibrarySourceIDs: [String]
) -> String {
    func validSourceID(_ sourceID: String) -> String {
        let trimmed = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return availableLibrarySourceIDs.contains(trimmed) ? trimmed : ""
    }

    if kind == .mechanics {
        return quickEntryAllGamesLibraryID
    }

    return validSourceID(currentSelectedGameSourceID)
        .nonEmpty(or: validSourceID(preferredLibrarySourceID))
        .nonEmpty(or: validSourceID(avenueLibrarySourceID))
        .nonEmpty(or: validSourceID(defaultPracticeSourceID))
        .nonEmpty(or: availableLibrarySourceIDs.first ?? "")
        .nonEmpty(or: quickEntryAllGamesLibraryID)
}

private extension String {
    func nonEmpty(or fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }
}

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
    @State private var videoKind: VideoProgressInputKind = defaultPracticeVideoInputKind
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
    @State private var showingScoreScanner = false
    @State private var pendingScoreScannerPresentation = false
    @FocusState private var scoreFieldFocused: Bool

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
        store.librarySources.isEmpty ? libraryInferSources(from: allLibraryGamesForPicker) : store.librarySources
    }

    private var avenueLibrarySourceIDForQuickEntry: String? {
        availableLibrarySources.first(where: { isAvenueLibrarySourceID($0.id) })?.id
            ?? availableLibrarySources.first(where: { $0.name.localizedCaseInsensitiveContains("the avenue") })?.id
    }

    private var selectedGameSourceIDForQuickEntry: String {
        selectedGame?.sourceId ?? ""
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
                                            AppSelectableMenuRow(text: activity.label, isSelected: selectedActivity == activity)
                                        }
                                    }
                                }
                                label: {
                                    AppCompactDropdownLabel(text: selectedActivityLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Activity")
                            }

                            PracticeQuickEntryModeFields(
                                selectedActivity: selectedActivity,
                                videoSourceOptions: videoSourceOptions,
                                mechanicsSkills: store.allTrackedMechanicsSkills(),
                                detectedMechanicsTags: store.detectedMechanicsTags(in: mechanicsNote),
                                scoreFieldFocused: $scoreFieldFocused,
                                onOpenScoreScanner: presentScoreScanner,
                                scoreText: $scoreText,
                                scoreContext: $scoreContext,
                                tournamentName: $tournamentName,
                                rulesheetProgress: $rulesheetProgress,
                                videoKind: $videoKind,
                                selectedVideoSource: $selectedVideoSource,
                                videoWatchedTime: $videoWatchedTime,
                                videoTotalTime: $videoTotalTime,
                                videoPercent: $videoPercent,
                                practiceMinutes: $practiceMinutes,
                                practiceCategory: $practiceCategory,
                                mechanicsSkill: $mechanicsSkill,
                                mechanicsCompetency: $mechanicsCompetency,
                                mechanicsNote: $mechanicsNote,
                                noteText: $noteText
                            )

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
                    AppToolbarConfirmAction(
                        title: "Save",
                        isDisabled: selectedGameID.isEmpty && selectedActivity != .mechanics
                    ) {
                        if let savedGameID = save() {
                            onEntrySaved(savedGameID)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                let requestedActivity = initialActivity ?? kind.defaultActivity
                selectedActivity = availableActivities.contains(requestedActivity) ? requestedActivity : kind.defaultActivity
                if selectedLibraryFilterID.isEmpty {
                    selectedLibraryFilterID = resolveInitialQuickEntryLibraryFilterID(
                        kind: kind,
                        currentSelectedGameSourceID: selectedGameSourceIDForQuickEntry,
                        preferredLibrarySourceID: PinballLibrarySourceStateStore.load().selectedSourceID ?? "",
                        avenueLibrarySourceID: avenueLibrarySourceIDForQuickEntry ?? "",
                        defaultPracticeSourceID: store.defaultPracticeSourceID ?? "",
                        availableLibrarySourceIDs: availableLibrarySources.map(\.id)
                    )
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
                    PinballLibrarySourceStateStore.setSelectedSourceID(selectedLibraryFilterID)
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
            .onChange(of: scoreFieldFocused) { _, isFocused in
                guard !isFocused, pendingScoreScannerPresentation else { return }
                pendingScoreScannerPresentation = false
                Task { @MainActor in
                    await Task.yield()
                    showingScoreScanner = true
                }
            }
        }
    }

    private func presentScoreScanner() {
        validationMessage = nil
        guard !showingScoreScanner else { return }
        if scoreFieldFocused {
            pendingScoreScannerPresentation = true
            scoreFieldFocused = false
        } else {
            showingScoreScanner = true
        }
    }

    @ViewBuilder
    private var libraryFilterMenu: some View {
        if availableLibrarySources.count > 1 {
            Menu {
                Button {
                    selectedLibraryFilterID = quickEntryAllGamesLibraryID
                } label: {
                    AppSelectableMenuRow(
                        text: "All games",
                        isSelected: selectedLibraryFilterID == quickEntryAllGamesLibraryID || selectedLibraryFilterID.isEmpty
                    )
                }
                ForEach(availableLibrarySources) { source in
                    Button {
                        selectedLibraryFilterID = source.id
                    } label: {
                        AppSelectableMenuRow(text: source.name, isSelected: selectedLibraryFilterID == source.id)
                    }
                }
            }
            label: {
                AppCompactDropdownLabel(text: selectedLibraryFilterLabel)
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
                    AppSelectableMenuRow(text: "None", isSelected: selectedGameID.isEmpty)
                }
            }
            if filteredGamesForPicker.isEmpty {
                Text("No game data")
            } else {
                ForEach(gameOptions) { game in
                    Button {
                        selectedGameID = game.canonicalPracticeKey
                    } label: {
                        AppSelectableMenuRow(text: game.name, isSelected: selectedGameID == game.canonicalPracticeKey)
                    }
                }
            }
        }
        label: {
            AppCompactDropdownLabel(text: selectedGameLabel)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Game")
    }

    private func save() -> String? {
        let result = savePracticeQuickEntry(
            store: store,
            activity: selectedActivity,
            selectedGameID: selectedGameID,
            scoreText: scoreText,
            scoreContext: scoreContext,
            tournamentName: tournamentName,
            rulesheetProgress: rulesheetProgress,
            videoKind: videoKind,
            selectedVideoSource: selectedVideoSource,
            videoWatchedTime: videoWatchedTime,
            videoTotalTime: videoTotalTime,
            videoPercent: videoPercent,
            practiceMinutes: practiceMinutes,
            practiceCategory: practiceCategory,
            mechanicsSkill: mechanicsSkill,
            mechanicsCompetency: mechanicsCompetency,
            mechanicsNote: mechanicsNote,
            noteText: noteText
        )
        validationMessage = result.validationMessage
        return result.savedGameID
    }

}
