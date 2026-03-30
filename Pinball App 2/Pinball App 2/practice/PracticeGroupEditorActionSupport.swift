import Foundation

struct PracticeGroupEditorTemplateDefaults {
    let selectedTemplateBank: Int
    let selectedDuplicateGroupID: UUID?
}

struct PracticeGroupEditorSaveResult {
    let validationMessage: String?

    var succeeded: Bool { validationMessage == nil }
}

struct PracticeGroupBankTemplateApplication {
    let selectedGameIDs: [String]
    let type: GroupType
    let suggestedName: String?
}

struct PracticeGroupDuplicateTemplateApplication {
    let selectedGameIDs: [String]
    let type: GroupType
    let isPriority: Bool
    let isArchived: Bool
    let suggestedName: String?
    let hasStartDate: Bool
    let startDate: Date?
    let hasEndDate: Bool
    let endDate: Date?
}

func practiceGroupEditorTemplateDefaults(
    availableBanks: [Int],
    selectedTemplateBank: Int,
    duplicateCandidates: [CustomGameGroup],
    selectedDuplicateGroupID: UUID?
) -> PracticeGroupEditorTemplateDefaults {
    let normalizedBank: Int
    if let firstBank = availableBanks.first, !availableBanks.contains(selectedTemplateBank) {
        normalizedBank = firstBank
    } else if availableBanks.isEmpty, selectedTemplateBank == 0 {
        normalizedBank = 1
    } else {
        normalizedBank = selectedTemplateBank
    }

    let duplicateIDs = Set(duplicateCandidates.map(\.id))
    let normalizedDuplicateGroupID: UUID?
    if let selectedDuplicateGroupID, duplicateIDs.contains(selectedDuplicateGroupID) {
        normalizedDuplicateGroupID = selectedDuplicateGroupID
    } else {
        normalizedDuplicateGroupID = duplicateCandidates.first?.id
    }

    return PracticeGroupEditorTemplateDefaults(
        selectedTemplateBank: normalizedBank,
        selectedDuplicateGroupID: normalizedDuplicateGroupID
    )
}

func savePracticeGroupEditor(
    store: PracticeStore,
    editingGroup: CustomGameGroup?,
    name: String,
    selectedGameIDs: [String],
    type: GroupType,
    isActive: Bool,
    isArchived: Bool,
    isPriority: Bool,
    hasStartDate: Bool,
    startDate: Date,
    hasEndDate: Bool,
    endDate: Date,
    createGroupPosition: Int
) -> PracticeGroupEditorSaveResult {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return PracticeGroupEditorSaveResult(validationMessage: "Group name is required.")
    }
    guard !selectedGameIDs.isEmpty else {
        return PracticeGroupEditorSaveResult(validationMessage: "Select at least one game.")
    }

    let start = hasStartDate ? startDate : nil
    let end = hasEndDate ? endDate : nil
    if let start, let end, end < start {
        return PracticeGroupEditorSaveResult(validationMessage: "End date must be on or after start date.")
    }

    if let editingGroup {
        store.updateGroup(
            id: editingGroup.id,
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
        store.setSelectedGroup(id: editingGroup.id)
        return PracticeGroupEditorSaveResult(validationMessage: nil)
    }

    if let newID = store.createGroup(
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

    return PracticeGroupEditorSaveResult(validationMessage: nil)
}

func applyPracticeGroupBankTemplate(
    bank: Int,
    templateGames: [PinballGame],
    currentName: String
) -> PracticeGroupBankTemplateApplication {
    let selectedGameIDs = templateGames
        .filter { $0.bank == bank }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        .map(\.canonicalPracticeKey)
        .reduce(into: [String]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }

    return PracticeGroupBankTemplateApplication(
        selectedGameIDs: selectedGameIDs,
        type: .bank,
        suggestedName: currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Bank \(bank) Focus" : nil
    )
}

func applyPracticeGroupDuplicateTemplate(
    groupID: UUID?,
    duplicateCandidates: [CustomGameGroup],
    currentName: String
) -> PracticeGroupDuplicateTemplateApplication? {
    guard let groupID,
          let source = duplicateCandidates.first(where: { $0.id == groupID }) else {
        return nil
    }

    return PracticeGroupDuplicateTemplateApplication(
        selectedGameIDs: source.gameIDs,
        type: source.type,
        isPriority: source.isPriority,
        isArchived: source.isArchived,
        suggestedName: currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Copy of \(source.name)" : nil,
        hasStartDate: source.startDate != nil,
        startDate: source.startDate,
        hasEndDate: source.endDate != nil,
        endDate: source.endDate
    )
}

func formatPracticeGroupEditorDate(_ date: Date) -> String {
    practiceGroupEditorDateFormatter.string(from: date)
}

private let practiceGroupEditorDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MM/dd/yy"
    return formatter
}()
