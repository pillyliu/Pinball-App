import SwiftUI
import UniformTypeIdentifiers

struct GroupProgressWheel: View {
    let taskProgress: [StudyTaskKind: Int]

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
                    .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 5, lineCap: .round))

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

struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        case .bank: return "Bank Template"
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

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedGameIDs: [String] = []
    @State private var isActive = true
    @State private var isPriority = false
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
    @State private var showingScheduleCalendar = false
    @State private var editingScheduleField: GroupEditorDateField = .start
    @State private var createGroupPosition: Int = 1

    private var editingGroup: CustomGameGroup? {
        guard let editingGroupID else { return nil }
        return store.state.customGroups.first(where: { $0.id == editingGroupID })
    }

    private var selectedGames: [PinballGame] {
        let byID = Dictionary(uniqueKeysWithValues: store.games.map { ($0.id, $0) })
        return selectedGameIDs.compactMap { byID[$0] }
    }

    private var availableBanks: [Int] {
        Array(Set(store.games.compactMap(\.bank))).sorted()
    }

    private var duplicateCandidates: [CustomGameGroup] {
        store.state.customGroups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionCard("Name") {
                    TextField("Group name", text: $name)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .appControlStyle()
                }

                if editingGroup == nil {
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
                                Text("No bank data found in library.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("Bank", selection: $selectedTemplateBank) {
                                    ForEach(availableBanks, id: \.self) { bank in
                                        Text("Bank \(bank)").tag(bank)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button("Apply Bank Template") {
                                    applyBankTemplate(bank: selectedTemplateBank)
                                }
                                .buttonStyle(.glass)
                            }
                        case .duplicate:
                            if duplicateCandidates.isEmpty {
                                Text("No existing groups to duplicate.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
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
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }

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
                        Text("No games selected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedGames) { game in
                                    SelectedGameMiniCard(game: game)
                                        .onDrag {
                                            draggingGameID = game.id
                                            return NSItemProvider(object: game.id as NSString)
                                        }
                                        .onDrop(
                                            of: [UTType.text],
                                            delegate: SelectedGameReorderDropDelegate(
                                                targetGameID: game.id,
                                                selectedGameIDs: $selectedGameIDs,
                                                draggingGameID: $draggingGameID
                                            )
                                        )
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                pendingDeleteGameID = game.id
                                            } label: {
                                                Label("Delete Title", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .onDrop(of: [UTType.text], delegate: SelectedGameReorderContainerDropDelegate(draggingGameID: $draggingGameID))
                        }

                        Text("Long-press a title card to reorder or delete.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Position")
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                moveGroupPosition(up: true)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(!canMoveGroupUp)
                            .foregroundStyle(canMoveGroupUp ? Color.primary : Color.secondary.opacity(0.4))

                            Text("\(groupPosition)")
                                .font(.footnote.monospacedDigit().weight(.semibold))
                                .frame(minWidth: 28)

                            Button {
                                moveGroupPosition(up: false)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(!canMoveGroupDown)
                            .foregroundStyle(canMoveGroupDown ? Color.primary : Color.secondary.opacity(0.4))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .appControlStyle()
                    }

                    HStack {
                        Toggle("Start Date", isOn: $hasStartDate)
                            .toggleStyle(.switch)
                        Spacer()
                        if hasStartDate {
                            Button {
                                editingScheduleField = .start
                                showingScheduleCalendar = true
                            } label: {
                                Text(formatEditorScheduleDate(startDate))
                                    .font(.caption2)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                    HStack {
                        Toggle("End Date", isOn: $hasEndDate)
                            .toggleStyle(.switch)
                        Spacer()
                        if hasEndDate {
                            Button {
                                editingScheduleField = .end
                                showingScheduleCalendar = true
                            } label: {
                                Text(formatEditorScheduleDate(endDate))
                                    .font(.caption2)
                            }
                            .buttonStyle(.glass)
                        }
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(AppBackground())
        .navigationTitle(editingGroup == nil ? "Create Group" : "Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onSaved()
                    dismiss()
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
                Button(editingGroup == nil ? "Create" : "Save") {
                    if save() {
                        onSaved()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { populateFromEditingGroupIfNeeded() }
        .sheet(isPresented: $showingTitleSelector) {
            NavigationStack {
                GroupGameSelectionScreen(store: store, selectedGameIDs: $selectedGameIDs)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingTitleSelector = false
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingScheduleCalendar) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        editingScheduleField == .start ? "Start Date" : "End Date",
                        selection: activeScheduleDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)

                    HStack {
                        Button("Clear", role: .destructive) {
                            if editingScheduleField == .start {
                                hasStartDate = false
                            } else {
                                hasEndDate = false
                            }
                            showingScheduleCalendar = false
                        }
                        .buttonStyle(.glass)

                        Spacer()

                        Button("Save") {
                            showingScheduleCalendar = false
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppBackground())
                .navigationTitle(editingScheduleField == .start ? "Set Start Date" : "Set End Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingScheduleCalendar = false
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
                dismiss()
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
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func populateFromEditingGroupIfNeeded() {
        guard !didSeedFromEditingGroup else { return }
        defer { didSeedFromEditingGroup = true }

        if selectedTemplateBank == 0 {
            selectedTemplateBank = availableBanks.first ?? 1
        }
        selectedDuplicateGroupID = duplicateCandidates.first?.id
        createGroupPosition = store.state.customGroups.count + 1

        guard let group = editingGroup else { return }
        name = group.name
        selectedGameIDs = group.gameIDs
        isActive = group.isActive
        isPriority = group.isPriority
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

    private func formatEditorScheduleDate(_ date: Date) -> String {
        Self.editorScheduleDateFormatter.string(from: date)
    }

    private static let editorScheduleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    private func applyBankTemplate(bank: Int) {
        let games = store.games
            .filter { $0.bank == bank }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedGameIDs = games.map(\.id)
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

    private var activeScheduleDateBinding: Binding<Date> {
        Binding(
            get: { editingScheduleField == .start ? startDate : endDate },
            set: { newValue in
                if editingScheduleField == .start {
                    startDate = newValue
                } else {
                    endDate = newValue
                }
            }
        )
    }
}

struct GroupGameSelectionScreen: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameIDs: [String]

    @State private var searchText: String = ""

    private var filteredGames: [PinballGame] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return store.games
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
            ForEach(grouped, id: \.letter) { section in
                Section(section.letter) {
                    ForEach(section.games) { game in
                        Button {
                            toggle(game.id)
                        } label: {
                            HStack {
                                Text(game.name)
                                Spacer()
                                Image(systemName: isSelected(game.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isSelected(game.id) ? .orange : .secondary)
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
}

struct SelectedGameMiniCard: View {
    let game: PinballGame
    private let cardWidth: CGFloat = 122

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FallbackAsyncImageView(
                candidates: game.miniPlayfieldCandidates,
                emptyMessage: nil,
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .clipped()
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 8,
                    style: .continuous
                )
            )

            Text(game.name)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, alignment: .leading)
        .padding(.top, 0)
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
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

        withAnimation(.easeInOut(duration: 0.35)) {
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

