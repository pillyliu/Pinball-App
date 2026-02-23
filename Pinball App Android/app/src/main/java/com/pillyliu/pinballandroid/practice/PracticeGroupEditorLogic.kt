package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame
import java.util.Locale

internal data class GroupEditorDuplicateApplyResult(
    val selectedSlugs: List<String>,
    val groupType: String,
    val isPriority: Boolean,
    val hasStartDate: Boolean,
    val hasEndDate: Boolean,
    val startDateMsValue: Long,
    val endDateMsValue: Long,
    val suggestedName: String?,
)

internal data class GroupEditorSaveOutcome(
    val validationMessage: String? = null,
)

internal fun groupEditorValidationMessage(
    name: String,
    selectedSlugs: List<String>,
    startDateMs: Long?,
    endDateMs: Long?,
): String? {
    val trimmedName = name.trim()
    if (trimmedName.isEmpty()) return "Group name is required."
    if (selectedSlugs.isEmpty()) return "Select at least one title."
    if (startDateMs != null && endDateMs != null && endDateMs < startDateMs) {
        return "End date must be on or after start date."
    }
    return null
}

internal fun bankTemplateSlugs(games: List<PinballGame>, selectedTemplateBank: Int): List<String> {
    return games
        .filter { it.bank == selectedTemplateBank }
        .sortedBy { it.name.lowercase(Locale.US) }
        .map { it.practiceKey }
        .distinct()
}

internal fun applyDuplicateGroupTemplate(
    source: PracticeGroup,
    currentName: String,
    currentStartDateMsValue: Long,
    currentEndDateMsValue: Long,
): GroupEditorDuplicateApplyResult {
    return GroupEditorDuplicateApplyResult(
        selectedSlugs = source.gameSlugs,
        groupType = source.type,
        isPriority = source.isPriority,
        hasStartDate = source.startDateMs != null,
        hasEndDate = source.endDateMs != null,
        startDateMsValue = source.startDateMs ?: currentStartDateMsValue,
        endDateMsValue = source.endDateMs ?: currentEndDateMsValue,
        suggestedName = if (currentName.isBlank()) "Copy of ${source.name}" else null,
    )
}

internal fun saveGroupFromEditor(
    store: PracticeStore,
    editing: PracticeGroup?,
    name: String,
    selectedSlugs: List<String>,
    isActive: Boolean,
    isArchived: Boolean,
    isPriority: Boolean,
    groupType: String,
    hasStartDate: Boolean,
    startDateMsValue: Long,
    hasEndDate: Boolean,
    endDateMsValue: Long,
    createGroupPosition: Int,
): GroupEditorSaveOutcome {
    val startDateMs = if (hasStartDate) startDateMsValue else null
    val endDateMs = if (hasEndDate) endDateMsValue else null
    val validation = groupEditorValidationMessage(
        name = name,
        selectedSlugs = selectedSlugs,
        startDateMs = startDateMs,
        endDateMs = endDateMs,
    )
    if (validation != null) return GroupEditorSaveOutcome(validationMessage = validation)

    val trimmedName = name.trim()
    if (editing == null) {
        val createdID = store.createGroup(
            name = trimmedName,
            gameSlugs = selectedSlugs,
            isActive = isActive,
            isArchived = isArchived,
            isPriority = isPriority,
            type = groupType,
            startDateMs = startDateMs,
            endDateMs = endDateMs,
            insertAt = (createGroupPosition - 1).coerceAtLeast(0),
        )
        store.setSelectedGroup(createdID)
        return GroupEditorSaveOutcome()
    }

    store.updateGroup(
        editing.copy(
            name = trimmedName,
            gameSlugs = selectedSlugs.distinct(),
            type = groupType,
            isActive = isActive,
            isArchived = isArchived,
            isPriority = isPriority,
            startDateMs = startDateMs,
            endDateMs = endDateMs,
        ),
    )
    store.setSelectedGroup(editing.id)
    return GroupEditorSaveOutcome()
}
