import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct GroupProgressWheel: View {
    let taskProgress: [StudyTaskKind: Int]
    @Environment(\.colorScheme) private var colorScheme

    private let taskColors: [StudyTaskKind: Color] = [
        .playfield: .cyan,
        .rulesheet: .blue,
        .tutorialVideo: .orange,
        .gameplayVideo: .purple,
        .practice: .green
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size / 2) - 3
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let tasks = StudyTaskKind.allCases
            let segment = 360.0 / Double(tasks.count)
            let gap = 6.0
            let trackColor = colorScheme == .dark
                ? AppTheme.brandInk.opacity(0.26)
                : AppTheme.brandInk.opacity(0.30)

            ZStack {
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    let start = -90.0 + (Double(index) * segment) + (gap / 2)
                    let end = -90.0 + (Double(index + 1) * segment) - (gap / 2)
                    let progress = Double(taskProgress[task] ?? 0) / 100.0
                    let fillEnd = start + ((end - start) * progress)

                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(start),
                            endAngle: .degrees(end),
                            clockwise: false
                        )
                    }
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))

                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(start),
                            endAngle: .degrees(fillEnd),
                            clockwise: false
                        )
                    }
                    .stroke((taskColors[task] ?? .gray).opacity(progress > 0 ? 0.95 : 0.2), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
        }
    }
}

enum GroupCreationTemplateSource: String, CaseIterable, Identifiable {
    case none
    case bank
    case duplicate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .bank: return "LPL Bank Template"
        case .duplicate: return "Duplicate Group"
        }
    }
}

enum GroupEditorDateField {
    case start
    case end
}

struct GroupEditorScreen: View {
    @ObservedObject var store: PracticeStore
    let editingGroupID: UUID?
    let onSaved: () -> Void

    @State private var name: String = ""
    @State private var selectedGameIDs: [String] = []
    @State private var isActive = true
    @State private var isPriority = false
    @State private var isArchived = false
    @State private var type: GroupType = .custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var hasStartDate = false
    @State private var hasEndDate = false
    @State private var validationMessage: String?
    @State private var didSeedFromEditingGroup = false
    @State private var showingDeleteGroupConfirmation = false
    @State private var pendingDeleteGameID: String?
    @State private var draggingGameID: String?
    @State private var templateSource: GroupCreationTemplateSource = .none
    @State private var selectedTemplateBank: Int = 0
    @State private var selectedDuplicateGroupID: UUID?
    @State private var showingTitleSelector = false
    @State private var createGroupPosition: Int = 1
    @State private var inlineDateEditorField: GroupEditorDateField?

    private var editingGroup: CustomGameGroup? {
        guard let editingGroupID else { return nil }
        return store.state.customGroups.first(where: { $0.id == editingGroupID })
    }

    private var selectedGames: [PinballGame] {
        selectedGameIDs.compactMap { store.gameForAnyID($0) }
    }

    private var availableBanks: [Int] {
        let templateGames = store.bankTemplateGames.isEmpty ? store.games : store.bankTemplateGames
        return Array(Set(templateGames.compactMap(\.bank))).sorted()
    }

    private var duplicateCandidates: [CustomGameGroup] {
        store.state.customGroups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nameSection
            if editingGroup == nil {
                templatesSection
            }
            titlesSection
            settingsSection
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                AppToolbarCancelAction {
                    onSaved()
                }
            }

            if editingGroup != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteGroupConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                AppToolbarConfirmAction(title: editingGroup == nil ? "Create" : "Save") {
                    if save() {
                        onSaved()
                    }
                }
            }
        }
        .onAppear { populateFromEditingGroupIfNeeded() }
        .task {
            guard editingGroup == nil else { return }
            await store.ensureBankTemplateGamesLoaded()
        }
        .sheet(isPresented: $showingTitleSelector) {
            NavigationStack {
                GroupGameSelectionScreen(store: store, selectedGameIDs: $selectedGameIDs)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            AppToolbarDoneAction {
                                showingTitleSelector = false
                            }
                        }
                }
            }
        }
        .confirmationDialog("Delete this group?", isPresented: $showingDeleteGroupConfirmation, titleVisibility: .visible) {
            Button("Delete Group", role: .destructive) {
                guard let group = editingGroup else { return }
                store.deleteGroup(id: group.id)
                onSaved()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the group and its title list.")
        }
        .confirmationDialog(
            "Remove this title from the group?",
            isPresented: Binding(
                get: { pendingDeleteGameID != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteGameID = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Title", role: .destructive) {
                removePendingGameIfNeeded()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteGameID = nil
            }
        }
        .onChange(of: availableBanks) { _, _ in
            syncTemplateDefaultsToAvailableData()
        }
        .onChange(of: store.state.customGroups.map(\.id)) { _, _ in
            syncTemplateDefaultsToAvailableData()
        }
    }

    private var nameSection: some View {
        sectionCard("Name") {
            TextField("Group name", text: $name)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()
        }
    }

    private var templatesSection: some View {
        sectionCard("Templates") {
            Picker("Template", selection: $templateSource) {
                ForEach(GroupCreationTemplateSource.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)

            switch templateSource {
            case .none:
                Text("Choose a template to prefill this group.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .bank:
                if availableBanks.isEmpty {
                    AppPanelEmptyCard(text: "No LPL bank template data found.")
                } else {
                    Picker("Bank", selection: $selectedTemplateBank) {
                        ForEach(availableBanks, id: \.self) { bank in
                            Text("Bank \(bank)").tag(bank)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Apply LPL Bank Template") {
                        applyBankTemplate(bank: selectedTemplateBank)
                    }
                    .buttonStyle(AppPrimaryActionButtonStyle())
                }
            case .duplicate:
                if duplicateCandidates.isEmpty {
                    AppPanelEmptyCard(text: "No existing groups to duplicate.")
                } else {
                    Picker("Group", selection: Binding<UUID?>(
                        get: { selectedDuplicateGroupID ?? duplicateCandidates.first?.id },
                        set: { selectedDuplicateGroupID = $0 }
                    )) {
                        ForEach(duplicateCandidates) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Apply Duplicate Group") {
                        applyDuplicateTemplate(groupID: selectedDuplicateGroupID ?? duplicateCandidates.first?.id)
                    }
                    .buttonStyle(AppPrimaryActionButtonStyle())
                }
            }
        }
    }

    private var titlesSection: some View {
        sectionCard("Titles") {
            Button {
                showingTitleSelector = true
            } label: {
                HStack {
                    Text(selectedGameIDs.isEmpty ? "Select games" : "\(selectedGameIDs.count) selected")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()
            }
            .buttonStyle(.plain)

            if selectedGames.isEmpty {
                AppPanelEmptyCard(text: "No games selected.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedGames) { game in
                            SelectedGameMiniCard(game: game)
                            .onDrag {
                                let canonicalID = game.canonicalPracticeKey
                                draggingGameID = canonicalID
                                return NSItemProvider(object: canonicalID as NSString)
                            }
                            .onDrop(
                                of: [UTType.text, UTType.plainText],
                                delegate: SelectedGameReorderDropDelegate(
                                    targetGameID: game.canonicalPracticeKey,
                                    selectedGameIDs: $selectedGameIDs,
                                    draggingGameID: $draggingGameID
                                )
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDeleteGameID = game.canonicalPracticeKey
                                } label: {
                                    Label("Delete Title", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onDrop(of: [UTType.text, UTType.plainText], delegate: SelectedGameReorderContainerDropDelegate(draggingGameID: $draggingGameID))
                }

                Text("Long-press a title card to reorder or delete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsSection: some View {
        sectionCard("Settings") {
            HStack {
                Text("Active")
                Spacer()
                Toggle("", isOn: $isActive)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            HStack {
                Text("Priority")
                Spacer()
                Toggle("", isOn: $isPriority)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            Picker("Type", selection: $type) {
                ForEach(GroupType.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .appSegmentedControlStyle()

            HStack {
                Text("Position")
                Spacer()
                HStack(spacing: 8) {
                    Button { moveGroupPosition(up: true) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.plain)
                        .disabled(!canMoveGroupUp)
                        .foregroundStyle(canMoveGroupUp ? Color.primary : Color.secondary.opacity(0.4))

                    Text("\(groupPosition)")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 28)

                    Button { moveGroupPosition(up: false) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.plain)
                        .disabled(!canMoveGroupDown)
                        .foregroundStyle(canMoveGroupDown ? Color.primary : Color.secondary.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .appControlStyle()
            }

            dateToggleRow(title: "Start Date", hasDate: $hasStartDate, date: $startDate, field: .start)
            dateToggleRow(title: "End Date", hasDate: $hasEndDate, date: $endDate, field: .end)

            HStack {
                Text("Archived")
                Spacer()
                Toggle("", isOn: $isArchived)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func dateToggleRow(title: String, hasDate: Binding<Bool>, date: Binding<Date>, field: GroupEditorDateField) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Button {
                if !hasDate.wrappedValue { hasDate.wrappedValue = true }
                inlineDateEditorField = field
            } label: {
                Text(hasDate.wrappedValue ? formatEditorDate(date.wrappedValue) : "Select date")
                    .font(.caption2)
                    .foregroundStyle(hasDate.wrappedValue ? .secondary : .tertiary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .practiceAdaptivePopover(
                isPresented: Binding(
                    get: { inlineDateEditorField == field },
                    set: { isPresented in
                        if !isPresented { inlineDateEditorField = nil }
                    }
                ),
                preferredHeight: 420
            ) { availableHeight in
                editorDatePopover(
                    title: title,
                    hasDate: hasDate,
                    date: date,
                    availableHeight: availableHeight
                )
            }
            if hasDate.wrappedValue {
                Button {
                    hasDate.wrappedValue = false
                    if inlineDateEditorField == field { inlineDateEditorField = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            Toggle("", isOn: hasDate)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .appControlStyle()
    }

    private func editorDatePopover(
        title: String,
        hasDate: Binding<Bool>,
        date: Binding<Date>,
        availableHeight: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(title, selection: date, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                HStack {
                    Button("Clear", role: .destructive) {
                        hasDate.wrappedValue = false
                        inlineDateEditorField = nil
                    }
                    .buttonStyle(AppDestructiveActionButtonStyle(fillsWidth: false))

                    Spacer()

                    Button("Done") {
                        inlineDateEditorField = nil
                    }
                    .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(12)
        .frame(minWidth: 320, maxHeight: availableHeight, alignment: .top)
        .presentationCompactAdaptation(.popover)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: title)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func populateFromEditingGroupIfNeeded() {
        guard !didSeedFromEditingGroup else { return }
        defer { didSeedFromEditingGroup = true }

        syncTemplateDefaultsToAvailableData()
        createGroupPosition = store.state.customGroups.count + 1

        guard let group = editingGroup else {
            hasStartDate = true
            startDate = Date()
            return
        }
        name = group.name
        selectedGameIDs = group.gameIDs
        isActive = group.isActive
        isPriority = group.isPriority
        isArchived = group.isArchived
        type = group.type
        hasStartDate = group.startDate != nil
        hasEndDate = group.endDate != nil
        if let start = group.startDate {
            startDate = start
        }
        if let end = group.endDate {
            endDate = end
        }
    }

    private func syncTemplateDefaultsToAvailableData() {
        if let firstBank = availableBanks.first, !availableBanks.contains(selectedTemplateBank) {
            selectedTemplateBank = firstBank
        } else if availableBanks.isEmpty, selectedTemplateBank == 0 {
            selectedTemplateBank = 1
        }

        let duplicateIDs = Set(duplicateCandidates.map(\.id))
        if selectedDuplicateGroupID == nil || (selectedDuplicateGroupID != nil && !duplicateIDs.contains(selectedDuplicateGroupID!)) {
            selectedDuplicateGroupID = duplicateCandidates.first?.id
        }
    }

    private func save() -> Bool {
        validationMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Group name is required."
            return false
        }
        guard !selectedGameIDs.isEmpty else {
            validationMessage = "Select at least one game."
            return false
        }
        let start = hasStartDate ? startDate : nil
        let end = hasEndDate ? endDate : nil
        if let start, let end, end < start {
            validationMessage = "End date must be on or after start date."
            return false
        }

        if let group = editingGroup {
            store.updateGroup(
                id: group.id,
                name: trimmed,
                gameIDs: selectedGameIDs,
                type: type,
                isActive: isActive,
                isArchived: isArchived,
                isPriority: isPriority,
                replaceStartDate: true,
                startDate: start,
                replaceEndDate: true,
                endDate: end
            )
            store.setSelectedGroup(id: group.id)
        } else if let newID = store.createGroup(
            name: trimmed,
            gameIDs: selectedGameIDs,
            type: type,
            isActive: isActive,
            isArchived: isArchived,
            isPriority: isPriority,
            startDate: start,
            endDate: end
        ) {
            if let createdIndex = store.state.customGroups.firstIndex(where: { $0.id == newID }) {
                let maxIndex = max(0, store.state.customGroups.count - 1)
                let desiredIndex = max(0, min(createGroupPosition - 1, maxIndex))
                if desiredIndex != createdIndex {
                    store.reorderGroups(fromOffsets: IndexSet(integer: createdIndex), toOffset: desiredIndex)
                }
            }
            store.setSelectedGroup(id: newID)
        }
        return true
    }

    private func reorderSelectedGames(sourceID: String, targetID: String) {
        guard sourceID != targetID else { return }
        guard let sourceIndex = selectedGameIDs.firstIndex(of: sourceID),
              let targetIndex = selectedGameIDs.firstIndex(of: targetID) else { return }
        let moving = selectedGameIDs.remove(at: sourceIndex)
        selectedGameIDs.insert(moving, at: targetIndex)
    }

    private func removePendingGameIfNeeded() {
        guard let gameID = pendingDeleteGameID else { return }
        selectedGameIDs.removeAll { $0 == gameID }
        pendingDeleteGameID = nil
    }

    private func applyBankTemplate(bank: Int) {
        let templateGames = store.bankTemplateGames.isEmpty ? store.games : store.bankTemplateGames
        let games = templateGames
            .filter { $0.bank == bank }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedGameIDs = games.map(\.canonicalPracticeKey).reduce(into: [String]()) { result, id in
            if !result.contains(id) { result.append(id) }
        }
        type = .bank
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = "Bank \(bank) Focus"
        }
    }

    private func applyDuplicateTemplate(groupID: UUID?) {
        guard let groupID,
              let source = duplicateCandidates.first(where: { $0.id == groupID }) else { return }
        selectedGameIDs = source.gameIDs
        type = source.type
        isPriority = source.isPriority
        isArchived = source.isArchived
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = "Copy of \(source.name)"
        }
        hasStartDate = source.startDate != nil
        hasEndDate = source.endDate != nil
        if let start = source.startDate {
            startDate = start
        }
        if let end = source.endDate {
            endDate = end
        }
    }

    private var editedGroupIndex: Int? {
        guard let editingGroupID else { return nil }
        return store.state.customGroups.firstIndex(where: { $0.id == editingGroupID })
    }

    private var editedGroupPosition: Int {
        guard let editedGroupIndex else { return 1 }
        return editedGroupIndex + 1
    }

    private var groupPosition: Int {
        if editingGroup != nil {
            return editedGroupPosition
        }
        return max(1, min(createGroupPosition, store.state.customGroups.count + 1))
    }

    private var maxCreateGroupPosition: Int {
        max(1, store.state.customGroups.count + 1)
    }

    private var canMoveEditedGroupUp: Bool {
        guard let editedGroupIndex else { return false }
        return editedGroupIndex > 0
    }

    private var canMoveEditedGroupDown: Bool {
        guard let editedGroupIndex else { return false }
        return editedGroupIndex < (store.state.customGroups.count - 1)
    }

    private var canMoveGroupUp: Bool {
        if editingGroup != nil {
            return canMoveEditedGroupUp
        }
        return groupPosition > 1
    }

    private var canMoveGroupDown: Bool {
        if editingGroup != nil {
            return canMoveEditedGroupDown
        }
        return groupPosition < maxCreateGroupPosition
    }

    private func moveGroupPosition(up: Bool) {
        if editingGroup != nil {
            moveEditedGroup(up: up)
            return
        }
        if up {
            guard createGroupPosition > 1 else { return }
            createGroupPosition -= 1
        } else {
            guard createGroupPosition < maxCreateGroupPosition else { return }
            createGroupPosition += 1
        }
    }

    private func moveEditedGroup(up: Bool) {
        guard let editedGroupIndex else { return }
        if up {
            guard editedGroupIndex > 0 else { return }
            store.reorderGroups(fromOffsets: IndexSet(integer: editedGroupIndex), toOffset: editedGroupIndex - 1)
        } else {
            guard editedGroupIndex < (store.state.customGroups.count - 1) else { return }
            store.reorderGroups(fromOffsets: IndexSet(integer: editedGroupIndex), toOffset: editedGroupIndex + 2)
        }
    }

    private func formatEditorDate(_ date: Date) -> String {
        Self.editorDateFormatter.string(from: date)
    }

    private static let editorDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

}

struct GroupGameSelectionScreen: View {
    private static let preferredGroupPickerLibrarySourceDefaultsKey = "practice-group-picker-library-source-id"

    @ObservedObject var store: PracticeStore
    @Binding var selectedGameIDs: [String]

    @State private var searchText: String = ""
    @State private var selectedLibraryFilterID: String = ""

    private var allLibraryGamesForPicker: [PinballGame] {
        store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames
    }

    private var availableLibrarySources: [PinballLibrarySource] {
        store.librarySources.isEmpty ? inferPracticeLibrarySourcesForGroupPicker(from: allLibraryGamesForPicker) : store.librarySources
    }

    private var baseGamesForSelection: [PinballGame] {
        let selected = selectedLibraryFilterID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = allLibraryGamesForPicker
        if selected.isEmpty || selected == quickEntryAllGamesLibraryID {
            return pool
        }
        return pool.filter { $0.sourceId == selected }
    }

    private var filteredGames: [PinballGame] {
        orderedGamesForDropdown(baseGamesForSelection, collapseByPracticeIdentity: true)
            .filter { game in
                matchesSearchQuery(
                    searchText,
                    fields: [
                        game.name,
                        game.normalizedVariant,
                        game.manufacturer,
                        game.year.map(String.init)
                    ]
                )
            }
    }

    private var grouped: [(letter: String, games: [PinballGame])] {
        let buckets = Dictionary(grouping: filteredGames) { game in
            String(game.name.prefix(1)).uppercased()
        }
        return buckets.keys.sorted().map { letter in
            (letter, buckets[letter] ?? [])
        }
    }

    var body: some View {
        List {
            if availableLibrarySources.count > 1 {
                Section {
                    Picker("Library", selection: $selectedLibraryFilterID) {
                        Text("All games").tag(quickEntryAllGamesLibraryID)
                        ForEach(availableLibrarySources) { source in
                            Text(source.name).tag(source.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            ForEach(grouped, id: \.letter) { section in
                Section(section.letter) {
                    ForEach(section.games) { game in
                        Button {
                            toggle(selectionID(for: game))
                        } label: {
                            HStack {
                                Text(game.name)
                                Spacer()
                                Image(systemName: isSelected(selectionID(for: game)) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isSelected(selectionID(for: game)) ? .orange : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search titles")
        .navigationTitle("Select Titles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedLibraryFilterID.isEmpty {
                let savedPreferredLibraryID = UserDefaults.standard.string(forKey: Self.preferredGroupPickerLibrarySourceDefaultsKey)
                selectedLibraryFilterID =
                    (savedPreferredLibraryID.flatMap { id in availableLibrarySources.contains(where: { $0.id == id }) ? id : nil })
                    ?? store.defaultPracticeSourceID
                    ?? availableLibrarySources.first?.id
                    ?? quickEntryAllGamesLibraryID
            }
        }
        .onChange(of: selectedLibraryFilterID) { _, newValue in
            guard !newValue.isEmpty else { return }
            UserDefaults.standard.set(newValue, forKey: Self.preferredGroupPickerLibrarySourceDefaultsKey)
        }
    }

    private func toggle(_ gameID: String) {
        if isSelected(gameID) {
            selectedGameIDs.removeAll { $0 == gameID }
        } else {
            selectedGameIDs.append(gameID)
        }
    }

    private func isSelected(_ gameID: String) -> Bool {
        selectedGameIDs.contains(gameID)
    }

    private func selectionID(for game: PinballGame) -> String {
        let selectedSourceID = canonicalLibrarySourceID(selectedLibraryFilterID)
        if let selectedSourceID,
           selectedSourceID != quickEntryAllGamesLibraryID,
           game.sourceType == .venue,
           canonicalLibrarySourceID(game.sourceId) == selectedSourceID {
            return sourceScopedPracticeGameID(sourceID: selectedSourceID, gameID: game.canonicalPracticeKey)
        }
        return game.canonicalPracticeKey
    }
}

private func inferPracticeLibrarySourcesForGroupPicker(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    var out: [PinballLibrarySource] = []
    for game in games {
        if seen.insert(game.sourceId).inserted {
            out.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
        }
    }
    return out
}

struct SelectedGameReorderDropDelegate: DropDelegate {
    let targetGameID: String
    @Binding var selectedGameIDs: [String]
    @Binding var draggingGameID: String?

    func dropEntered(info: DropInfo) {
        guard let draggingGameID else { return }
        guard draggingGameID != targetGameID else { return }
        guard let fromIndex = selectedGameIDs.firstIndex(of: draggingGameID),
              let toIndex = selectedGameIDs.firstIndex(of: targetGameID) else {
            return
        }
        if fromIndex == toIndex { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedGameIDs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingGameID = nil
        return true
    }
}

struct SelectedGameReorderContainerDropDelegate: DropDelegate {
    @Binding var draggingGameID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingGameID = nil
        return true
    }
}

private struct PracticeAdaptivePopoverSourceFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextValue = nextValue()
        guard nextValue != .zero else { return }
        value = nextValue
    }
}

private struct PracticeAdaptivePopoverModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let preferredHeight: CGFloat
    let popoverContent: (CGFloat) -> PopoverContent

    @State private var sourceFrame: CGRect = .zero
    @State private var arrowEdge: Edge = .top
    @State private var availableHeight: CGFloat

    init(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder popoverContent: @escaping (CGFloat) -> PopoverContent
    ) {
        _isPresented = isPresented
        self.preferredHeight = preferredHeight
        self.popoverContent = popoverContent
        _availableHeight = State(initialValue: preferredHeight)
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: PracticeAdaptivePopoverSourceFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(PracticeAdaptivePopoverSourceFramePreferenceKey.self) { frame in
                guard frame != .zero else { return }
                sourceFrame = frame
                recalculatePlacement()
            }
            .popover(
                isPresented: $isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: arrowEdge
            ) {
                popoverContent(availableHeight)
            }
            .onAppear {
                recalculatePlacement()
            }
            .onChange(of: isPresented) { _, _ in
                recalculatePlacement()
            }
    }

    private func recalculatePlacement() {
        guard sourceFrame != .zero else {
            arrowEdge = .top
            availableHeight = preferredHeight
            return
        }

        let viewport = practicePopoverViewportRect()
        let spacingBuffer: CGFloat = 16
        let availableBelow = max(viewport.maxY - sourceFrame.maxY - spacingBuffer, 0)
        let availableAbove = max(sourceFrame.minY - viewport.minY - spacingBuffer, 0)
        let opensBelow = availableBelow >= preferredHeight || availableBelow >= availableAbove

        arrowEdge = opensBelow ? .top : .bottom
        availableHeight = max(opensBelow ? availableBelow : availableAbove, 0)
    }
}

extension View {
    func practiceAdaptivePopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder content: @escaping (CGFloat) -> PopoverContent
    ) -> some View {
        modifier(
            PracticeAdaptivePopoverModifier(
                isPresented: isPresented,
                preferredHeight: preferredHeight,
                popoverContent: content
            )
        )
    }
}

private func practicePopoverViewportRect() -> CGRect {
    let windowScenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
    let keyWindow = windowScenes
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)

    let fallbackRect = keyWindow?.windowScene?.screen.bounds
        ?? windowScenes.first(where: { $0.activationState == .foregroundActive })?.screen.bounds
        ?? windowScenes.first?.screen.bounds
        ?? CGRect(x: 0, y: 0, width: 1024, height: 1366)
    let baseRect = keyWindow?.bounds ?? fallbackRect
    let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
    let safeAreaHeight = max(baseRect.height - safeAreaInsets.top - safeAreaInsets.bottom, 0)
    let safeAreaRect = CGRect(
        x: baseRect.minX,
        y: baseRect.minY + safeAreaInsets.top,
        width: baseRect.width,
        height: safeAreaHeight
    )
    return safeAreaRect.insetBy(dx: 0, dy: 12)
}
