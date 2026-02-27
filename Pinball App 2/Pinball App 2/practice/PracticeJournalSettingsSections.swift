import SwiftUI

struct PracticeJournalItem: Identifiable {
    let id: String
    let gameID: String
    let summary: String
    let icon: String
    let timestamp: Date
    let journalEntry: JournalEntry?

    var isEditablePracticeEntry: Bool {
        guard let journalEntry else { return false }
        switch journalEntry.action {
        case .gameBrowse:
            return false
        case .rulesheetRead, .tutorialWatch, .gameplayWatch, .playfieldViewed, .practiceSession, .scoreLogged, .noteAdded:
            return true
        }
    }
}

struct PracticeJournalSectionView: View {
    @Binding var journalFilter: JournalFilter
    let items: [PracticeJournalItem]
    @Binding var isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void
    @State private var revealedSwipeItemID: String?
    @State private var suppressNextRowTap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Filter", selection: $journalFilter) {
                ForEach(JournalFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if isEditingEntries {
                HStack(spacing: 8) {
                    Button("Edit") {
                        guard let entry = selectedJournalEntries.first, selectedJournalEntries.count == 1 else { return }
                        onEditJournalEntry(entry)
                    }
                    .buttonStyle(.glass)
                    .disabled(selectedEditableJournalEntries.count != 1)

                    Button("Delete", role: .destructive) {
                        guard !selectedEditableJournalEntries.isEmpty else { return }
                        onDeleteJournalEntries(selectedEditableJournalEntries)
                    }
                    .buttonStyle(.glass)
                    .disabled(selectedEditableJournalEntries.isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if items.isEmpty {
                    Text("No matching journal events.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.timestamp) }
                    let days = grouped.keys.sorted(by: >)

                    List {
                        ForEach(days, id: \.self) { day in
                            Section {
                                ForEach(grouped[day] ?? []) { entry in
                                    journalRow(entry)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                }
                            } header: {
                                HStack {
                                    Text(day.formatted(date: .abbreviated, time: .omitted))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.cyan.opacity(0.95))
                                        .textCase(nil)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(AppTheme.panel.opacity(0.95))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, -16)
                                .padding(.top, 1)
                                .padding(.bottom, 1)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .listSectionSpacing(0)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .contentMargins(.top, 0, for: .scrollIndicators)
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 1)
                    .environment(\.defaultMinListHeaderHeight, 1)
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            if revealedSwipeItemID != nil {
                                revealedSwipeItemID = nil
                                suppressNextRowTap = true
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedJournalEntries: [JournalEntry] {
        items
            .filter { selectedItemIDs.contains($0.id) }
            .compactMap(\.journalEntry)
    }

    private var selectedEditableJournalEntries: [JournalEntry] {
        items
            .filter { selectedItemIDs.contains($0.id) && $0.isEditablePracticeEntry }
            .compactMap(\.journalEntry)
    }

    @ViewBuilder
    private func journalRow(_ entry: PracticeJournalItem) -> some View {
        let rowContent = journalRowContent(entry)

        if !isEditingEntries, entry.isEditablePracticeEntry, let journal = entry.journalEntry {
            JournalSwipeRevealRow(
                id: entry.id,
                revealedID: $revealedSwipeItemID,
                onEdit: { onEditJournalEntry(journal) },
                onDelete: { onDeleteJournalEntries([journal]) }
            ) {
                rowContent
            }
        } else if entry.isEditablePracticeEntry {
            JournalStaticEditableRow {
                rowContent
            }
        } else {
            rowContent
        }
    }

    @ViewBuilder
    private func journalRowContent(_ entry: PracticeJournalItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if isEditingEntries {
                if entry.isEditablePracticeEntry {
                    Image(systemName: selectedItemIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedItemIDs.contains(entry.id) ? .orange : .secondary)
                        .font(.body)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.clear)
                        .font(.body)
                }
            }

            Image(systemName: entry.icon)
                .font(.caption)
                .frame(width: 14)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                styledPracticeJournalSummary(entry.summary)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if suppressNextRowTap {
                suppressNextRowTap = false
                return
            }
            if revealedSwipeItemID != nil {
                revealedSwipeItemID = nil
                suppressNextRowTap = true
                return
            }
            if isEditingEntries {
                guard entry.isEditablePracticeEntry else { return }
                if selectedItemIDs.contains(entry.id) { selectedItemIDs.remove(entry.id) }
                else { selectedItemIDs.insert(entry.id) }
                return
            }
            onTapItem(entry.gameID)
        }
        .matchedTransitionSource(id: "\(entry.gameID)-\(entry.id)", in: gameTransition)
    }
}

struct JournalSwipeRevealRow<Content: View>: View {
    let id: String
    @Binding var revealedID: String?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let content: Content

    @State private var offsetX: CGFloat = 0
    @State private var dragStartX: CGFloat = 0
    @State private var isDragging = false
    @State private var draggingHorizontally = false
    @State private var dragRejectedAsVertical = false

    private let actionWidth: CGFloat = 116
    private let minRowHeight: CGFloat = 34

    init(
        id: String,
        revealedID: Binding<String?>,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        _revealedID = revealedID
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button(action: {
                    onEdit()
                    revealedID = nil
                    withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.blue.opacity(0.16))

                Button(action: {
                    onDelete()
                    revealedID = nil
                    withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.16))
            }
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .frame(minHeight: minRowHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(max(0, min(1, Double((-offsetX / actionWidth)))))

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: minRowHeight)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
                )
                .offset(x: offsetX)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: offsetX != 0 ? 4 : 22, coordinateSpace: .local)
                .onChanged { value in
                    if dragRejectedAsVertical {
                        return
                    }
                    if !isDragging {
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if offsetX != 0, abs(dx) > abs(dy), abs(dx) > 2 {
                            dragStartX = offsetX
                            isDragging = true
                            draggingHorizontally = true
                        } else {
                            // Let list scrolling win unless the user shows clear horizontal intent.
                            if abs(dy) >= abs(dx) || abs(dx) < 14 {
                                if abs(dy) > 10 {
                                    dragRejectedAsVertical = true
                                }
                                return
                            }
                            dragStartX = offsetX
                            isDragging = true
                            draggingHorizontally = true
                        }
                    }
                    let proposed = dragStartX + value.translation.width
                    offsetX = min(0, max(-actionWidth, proposed))
                }
                .onEnded { _ in
                    if dragRejectedAsVertical {
                        dragRejectedAsVertical = false
                        isDragging = false
                        draggingHorizontally = false
                        return
                    }
                    guard draggingHorizontally else { return }
                    isDragging = false
                    draggingHorizontally = false
                    withAnimation(.easeOut(duration: 0.18)) {
                        let shouldReveal = offsetX < (-actionWidth * 0.4)
                        offsetX = shouldReveal ? -actionWidth : 0
                        revealedID = shouldReveal ? id : nil
                    }
                }
        )
        .padding(.vertical, 1)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onChange(of: revealedID) { _, newValue in
            guard newValue != id, offsetX != 0 else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                offsetX = 0
            }
        }
    }
}

struct JournalStaticEditableRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
            )
            .padding(.vertical, 1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PracticeJournalEntryEditorSheet: View {
    let entry: JournalEntry
    @ObservedObject var store: PracticeStore
    let onSave: (JournalEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var gameID: String = ""
    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var noteCategory: PracticeCategory = .general
    @State private var noteDetail: String = ""
    @State private var noteText: String = ""
    @State private var studyProgressEnabled = false
    @State private var studyProgressPercent: Double = 0
    @State private var journalNoteText: String = ""
    @State private var videoKind: VideoProgressInputKind = .percent
    @State private var videoValue: String = ""
    @State private var validationMessage: String?

    private var gameOptions: [PinballGame] {
        store.practiceGamesDeduped()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Game") {
                    Picker("Title", selection: $gameID) {
                        ForEach(gameOptions) { game in
                            Text(game.name).tag(game.canonicalPracticeKey)
                        }
                    }
                }

                switch entry.action {
                case .scoreLogged:
                    Section("Score") {
                        TextField("Score", text: $scoreText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .onChange(of: scoreText) { _, newValue in
                                let formatted = formatJournalScoreInputWithCommas(newValue)
                                if formatted != newValue { scoreText = formatted }
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

                case .noteAdded:
                    Section("Note") {
                        Picker("Category", selection: $noteCategory) {
                            ForEach(PracticeCategory.allCases) { category in
                                Text(category.label).tag(category)
                            }
                        }
                        TextField("Detail (optional)", text: $noteDetail)
                        TextEditor(text: $noteText)
                            .frame(minHeight: 88, maxHeight: 96)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .appControlStyle()
                    }

                case .rulesheetRead, .playfieldViewed, .practiceSession:
                    Section("Entry") {
                        Toggle("Track progress", isOn: $studyProgressEnabled)
                        if studyProgressEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Progress")
                                    Spacer()
                                    Text("\(Int(studyProgressPercent.rounded()))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $studyProgressPercent, in: 0...100, step: 1)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note (optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $journalNoteText)
                                .frame(minHeight: 88, maxHeight: 96)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .appControlStyle()
                        }
                    }

                case .tutorialWatch, .gameplayWatch:
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

                        Toggle("Track progress", isOn: $studyProgressEnabled)
                        if studyProgressEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Progress")
                                    Spacer()
                                    Text("\(Int(studyProgressPercent.rounded()))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $studyProgressPercent, in: 0...100, step: 1)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note (optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $journalNoteText)
                                .frame(minHeight: 88, maxHeight: 96)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .appControlStyle()
                        }
                    }

                default:
                    Section {
                        Text("Editing is only supported for score and note entries right now.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!store.canEditJournalEntry(entry))
                }
            }
            .onAppear {
                gameID = store.canonicalPracticeGameID(entry.gameID)
                scoreText = entry.score.map { store.formatScore($0) } ?? ""
                scoreContext = entry.scoreContext ?? .practice
                tournamentName = entry.tournamentName ?? ""
                noteCategory = entry.noteCategory ?? .general
                noteDetail = entry.noteDetail ?? ""
                noteText = entry.note ?? ""
                studyProgressEnabled = entry.progressPercent != nil
                studyProgressPercent = Double(entry.progressPercent ?? 0)
                journalNoteText = entry.note ?? ""
                videoKind = entry.videoKind ?? .percent
                videoValue = entry.videoValue ?? ""
                if gameID.isEmpty {
                    gameID = gameOptions.first?.canonicalPracticeKey ?? ""
                }
            }
        }
    }

    private func save() {
        validationMessage = nil
        let canonicalGameID = store.canonicalPracticeGameID(gameID)
        guard !canonicalGameID.isEmpty else {
            validationMessage = "Select a game."
            return
        }

        switch entry.action {
        case .scoreLogged:
            let normalized = scoreText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let score = Double(normalized), score > 0 else {
                validationMessage = "Enter a valid score above 0."
                return
            }
            if scoreContext == .tournament,
               tournamentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationMessage = "Enter a tournament name."
                return
            }
            let updated = JournalEntry(
                id: entry.id,
                gameID: canonicalGameID,
                action: entry.action,
                task: entry.task,
                progressPercent: entry.progressPercent,
                videoKind: entry.videoKind,
                videoValue: entry.videoValue,
                score: score,
                scoreContext: scoreContext,
                tournamentName: scoreContext == .tournament ? tournamentName : nil,
                noteCategory: entry.noteCategory,
                noteDetail: entry.noteDetail,
                note: entry.note,
                timestamp: entry.timestamp
            )
            onSave(updated)
            dismiss()

        case .noteAdded:
            let normalizedNote = noteText.replacingOccurrences(of: "\r\n", with: "\n")
            guard !normalizedNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                validationMessage = "Note cannot be empty."
                return
            }
            let trimmedDetail = noteDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = JournalEntry(
                id: entry.id,
                gameID: canonicalGameID,
                action: entry.action,
                task: entry.task,
                progressPercent: entry.progressPercent,
                videoKind: entry.videoKind,
                videoValue: entry.videoValue,
                score: entry.score,
                scoreContext: entry.scoreContext,
                tournamentName: entry.tournamentName,
                noteCategory: noteCategory,
                noteDetail: trimmedDetail.isEmpty ? nil : trimmedDetail,
                note: normalizedNote,
                timestamp: entry.timestamp
            )
            onSave(updated)
            dismiss()

        case .rulesheetRead, .playfieldViewed, .practiceSession:
            let normalizedNote = journalNoteText.replacingOccurrences(of: "\r\n", with: "\n")
            let trimmedNote = normalizedNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = JournalEntry(
                id: entry.id,
                gameID: canonicalGameID,
                action: entry.action,
                task: entry.task,
                progressPercent: studyProgressEnabled ? Int(studyProgressPercent.rounded()) : nil,
                videoKind: entry.videoKind,
                videoValue: entry.videoValue,
                score: entry.score,
                scoreContext: entry.scoreContext,
                tournamentName: entry.tournamentName,
                noteCategory: entry.noteCategory,
                noteDetail: entry.noteDetail,
                note: trimmedNote.isEmpty ? nil : normalizedNote,
                timestamp: entry.timestamp
            )
            onSave(updated)
            dismiss()

        case .tutorialWatch, .gameplayWatch:
            let trimmedVideoValue = videoValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedVideoValue.isEmpty else {
                validationMessage = "Enter a video progress value."
                return
            }
            let normalizedNote = journalNoteText.replacingOccurrences(of: "\r\n", with: "\n")
            let trimmedNote = normalizedNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = JournalEntry(
                id: entry.id,
                gameID: canonicalGameID,
                action: entry.action,
                task: entry.task,
                progressPercent: studyProgressEnabled ? Int(studyProgressPercent.rounded()) : nil,
                videoKind: videoKind,
                videoValue: trimmedVideoValue,
                score: entry.score,
                scoreContext: entry.scoreContext,
                tournamentName: entry.tournamentName,
                noteCategory: entry.noteCategory,
                noteDetail: entry.noteDetail,
                note: trimmedNote.isEmpty ? nil : normalizedNote,
                timestamp: entry.timestamp
            )
            onSave(updated)
            dismiss()

        case .gameBrowse:
            validationMessage = "Editing is not supported for this entry type."
        }
    }
}

private func formatJournalScoreInputWithCommas(_ raw: String) -> String {
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

struct PracticeSettingsSectionView: View {
    @Binding var playerName: String
    @Binding var leaguePlayerName: String
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    @Binding var cloudSyncEnabled: Bool
    let redactName: (String) -> String
    let onSaveProfile: () -> Void
    let onImportLeagueCSV: () -> Void
    let onCloudSyncChanged: (Bool) -> Void
    let onResetPracticeLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Practice Profile")
                    .font(.headline)

                TextField("Player name", text: $playerName)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                Button("Save Profile", action: onSaveProfile)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("League Import")
                    .font(.headline)

                Menu {
                    Button("Select league player") {
                        leaguePlayerName = ""
                    }
                    if leaguePlayerOptions.isEmpty {
                        Text("No player names found")
                    } else {
                        ForEach(leaguePlayerOptions, id: \.self) { name in
                            Button(redactName(name)) {
                                leaguePlayerName = name
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(leaguePlayerName.isEmpty ? "Select league player" : redactName(leaguePlayerName))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appControlStyle()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Used when you tap Import LPL CSV.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Import LPL CSV", action: onImportLeagueCSV)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.glass)
                    .disabled(leaguePlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !leagueImportStatus.isEmpty {
                    Text(leagueImportStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Defaults")
                    .font(.headline)

                Toggle("Enable optional cloud sync", isOn: $cloudSyncEnabled)
                    .onChange(of: cloudSyncEnabled) { _, newValue in
                        onCloudSyncChanged(newValue)
                    }
                Text("Placeholder for Phase 2 sync to pillyliu.com. Data stays on-device today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reset")
                    .font(.headline)

                Text("Erase the full local Practice log state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Practice Log", role: .destructive, action: onResetPracticeLog)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.red)
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
