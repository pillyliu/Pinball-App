import SwiftUI

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

    private var selectedGameItems: [GroupEditorSelectedGameItem] {
        selectedGameIDs.compactMap { selectionID in
            guard let game = store.gameForAnyID(selectionID) else { return nil }
            return GroupEditorSelectedGameItem(selectionID: selectionID, game: game)
        }
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
            GroupEditorNameSection(name: $name)
            if editingGroup == nil {
                GroupEditorTemplatesSection(
                    templateSource: $templateSource,
                    availableBanks: availableBanks,
                    selectedTemplateBank: $selectedTemplateBank,
                    duplicateCandidates: duplicateCandidates,
                    selectedDuplicateGroupID: $selectedDuplicateGroupID,
                    onApplyBankTemplate: applyBankTemplate(bank:),
                    onApplyDuplicateTemplate: applyDuplicateTemplate(groupID:)
                )
            }
            GroupEditorTitlesSection(
                selectedGameItems: selectedGameItems,
                showingTitleSelector: $showingTitleSelector,
                pendingDeleteGameID: $pendingDeleteGameID,
                draggingGameID: $draggingGameID,
                selectedGameIDs: $selectedGameIDs,
                onRemovePendingGame: removePendingGameIfNeeded
            )
            GroupEditorSettingsSection(
                isActive: $isActive,
                isPriority: $isPriority,
                type: $type,
                groupPosition: groupPosition,
                canMoveGroupUp: canMoveGroupUp,
                canMoveGroupDown: canMoveGroupDown,
                onMoveGroupPosition: moveGroupPosition(up:),
                hasStartDate: $hasStartDate,
                startDate: $startDate,
                hasEndDate: $hasEndDate,
                endDate: $endDate,
                inlineDateEditorField: $inlineDateEditorField,
                isArchived: $isArchived,
                validationMessage: validationMessage
            )
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
        .onChange(of: availableBanks) { _, _ in
            syncTemplateDefaultsToAvailableData()
        }
        .onChange(of: store.state.customGroups.map(\.id)) { _, _ in
            syncTemplateDefaultsToAvailableData()
        }
        .onChange(of: selectedGameIDs) { oldValue, newValue in
            let oldSet = Set(oldValue)
            let newSet = Set(newValue)
            if oldSet != newSet {
                draggingGameID = nil
            }
            if let pendingDeleteGameID, !newValue.contains(pendingDeleteGameID) {
                self.pendingDeleteGameID = nil
            }
        }
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
        let defaults = practiceGroupEditorTemplateDefaults(
            availableBanks: availableBanks,
            selectedTemplateBank: selectedTemplateBank,
            duplicateCandidates: duplicateCandidates,
            selectedDuplicateGroupID: selectedDuplicateGroupID
        )
        selectedTemplateBank = defaults.selectedTemplateBank
        selectedDuplicateGroupID = defaults.selectedDuplicateGroupID
    }

    private func save() -> Bool {
        let result = savePracticeGroupEditor(
            store: store,
            editingGroup: editingGroup,
            name: name,
            selectedGameIDs: selectedGameIDs,
            type: type,
            isActive: isActive,
            isArchived: isArchived,
            isPriority: isPriority,
            hasStartDate: hasStartDate,
            startDate: startDate,
            hasEndDate: hasEndDate,
            endDate: endDate,
            createGroupPosition: createGroupPosition
        )
        validationMessage = result.validationMessage
        return result.succeeded
    }

    private func removePendingGameIfNeeded() {
        guard let gameID = pendingDeleteGameID else { return }
        selectedGameIDs.removeAll { $0 == gameID }
        pendingDeleteGameID = nil
        draggingGameID = nil
    }

    private func applyBankTemplate(bank: Int) {
        let templateGames = store.bankTemplateGames.isEmpty ? store.games : store.bankTemplateGames
        let application = applyPracticeGroupBankTemplate(
            bank: bank,
            templateGames: templateGames,
            currentName: name
        )
        selectedGameIDs = application.selectedGameIDs
        draggingGameID = nil
        type = application.type
        if let suggestedName = application.suggestedName {
            name = suggestedName
        }
    }

    private func applyDuplicateTemplate(groupID: UUID?) {
        guard let application = applyPracticeGroupDuplicateTemplate(
            groupID: groupID,
            duplicateCandidates: duplicateCandidates,
            currentName: name
        ) else {
            return
        }
        selectedGameIDs = application.selectedGameIDs
        draggingGameID = nil
        type = application.type
        isPriority = application.isPriority
        isArchived = application.isArchived
        if let suggestedName = application.suggestedName {
            name = suggestedName
        }
        hasStartDate = application.hasStartDate
        hasEndDate = application.hasEndDate
        if let start = application.startDate {
            startDate = start
        }
        if let end = application.endDate {
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

}
