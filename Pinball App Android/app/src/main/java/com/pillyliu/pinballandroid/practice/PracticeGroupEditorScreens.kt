package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer
import java.util.Locale

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GroupEditorScreen(
    store: PracticeStore,
    editingGroupID: String?,
    onCancel: () -> Unit,
    onSaved: () -> Unit,
) {
    val editing = store.groups.firstOrNull { it.id == editingGroupID }
    var name by remember(editingGroupID) { mutableStateOf(editing?.name ?: "") }
    val selected = remember(editingGroupID) { mutableStateListOf<String>().apply { addAll(editing?.gameSlugs ?: emptyList()) } }
    var isActive by remember(editingGroupID) { mutableStateOf(editing?.isActive ?: true) }
    var isPriority by remember(editingGroupID) { mutableStateOf(editing?.isPriority ?: false) }
    var isArchived by remember(editingGroupID) { mutableStateOf(editing?.isArchived ?: false) }
    var groupType by remember(editingGroupID) { mutableStateOf(editing?.type ?: "custom") }
    var startDateMsValue by remember(editingGroupID) { mutableLongStateOf(editing?.startDateMs ?: System.currentTimeMillis()) }
    var endDateMsValue by remember(editingGroupID) { mutableLongStateOf(editing?.endDateMs ?: System.currentTimeMillis()) }
    var hasStartDate by remember(editingGroupID) { mutableStateOf(if (editing == null) true else editing.startDateMs != null) }
    var hasEndDate by remember(editingGroupID) { mutableStateOf(editing?.endDateMs != null) }
    var createGroupPosition by remember(editingGroupID) { mutableIntStateOf((store.groups.size + 1).coerceAtLeast(1)) }
    val allGamesPool = remember(store.games, store.allLibraryGames) {
        if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
    }
    var templateSource by remember(editingGroupID) { mutableStateOf("none") }
    var selectedTemplateBank by remember(editingGroupID, allGamesPool) { mutableIntStateOf(allGamesPool.mapNotNull { it.bank }.distinct().sorted().firstOrNull() ?: 1) }
    var selectedDuplicateGroupID by remember(editingGroupID) { mutableStateOf(store.groups.firstOrNull()?.id.orEmpty()) }
    var titleSearchText by remember(editingGroupID) { mutableStateOf("") }
    var showingTitleSelector by remember(editingGroupID) { mutableStateOf(false) }
    var validationMessage by remember(editingGroupID) { mutableStateOf<String?>(null) }
    var openDeleteGroupConfirm by remember(editingGroupID) { mutableStateOf(false) }
    var pendingDeleteSlug by remember(editingGroupID) { mutableStateOf<String?>(null) }
    var openScheduleDateDialog by remember(editingGroupID) { mutableStateOf(false) }
    var scheduleDateDialogField by remember(editingGroupID) { mutableStateOf(GroupEditorDateField.Start) }
    var scheduleDatePickerInitialMs by remember(editingGroupID) { mutableLongStateOf(System.currentTimeMillis()) }

    val availableBanks = remember(allGamesPool) { allGamesPool.mapNotNull { it.bank }.distinct().sorted() }
    val duplicateCandidates = remember(store.groups) { store.groups.sortedBy { it.name.lowercase(Locale.US) } }
    val editingIndex = editing?.let { group -> store.groups.indexOfFirst { it.id == group.id } } ?: -1
    val editingPosition = if (editingIndex >= 0) editingIndex + 1 else 1
    val canMoveEditedUp = editing != null && editingIndex > 0
    val canMoveEditedDown = editing != null && editingIndex in 0 until (store.groups.size - 1)
    val maxCreatePosition = (store.groups.size + 1).coerceAtLeast(1)
    val selectedGamesBySlug = remember(store.games, store.allLibraryGames) {
        val pool = if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
        gamesByPracticeLookupKey(pool)
    }

    if (showingTitleSelector) {
        GroupGameSelectionScreen(
            games = store.games,
            allGames = store.allLibraryGames,
            librarySources = store.librarySources,
            defaultSourceId = store.defaultPracticeSourceId,
            selectedSlugs = selected,
            searchText = titleSearchText,
            onSearchChange = { titleSearchText = it },
            onDone = { showingTitleSelector = false },
        )
        return
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        GroupEditorActionRow(
            isEditing = editing != null,
            onCancel = onCancel,
            onDelete = { openDeleteGroupConfirm = true },
            onSave = {
                validationMessage = null
                val outcome = saveGroupFromEditor(
                    store = store,
                    editing = editing,
                    name = name,
                    selectedSlugs = selected.toList(),
                    isActive = isActive,
                    isArchived = isArchived,
                    isPriority = isPriority,
                    groupType = groupType,
                    hasStartDate = hasStartDate,
                    startDateMsValue = startDateMsValue,
                    hasEndDate = hasEndDate,
                    endDateMsValue = endDateMsValue,
                    createGroupPosition = createGroupPosition,
                )
                if (outcome.validationMessage != null) {
                    validationMessage = outcome.validationMessage
                    return@GroupEditorActionRow
                }
                onSaved()
            },
        )

        GroupEditorTemplateCard(
            isEditing = editing != null,
            name = name,
            onNameChange = { name = it },
            templateSource = templateSource,
            onTemplateSourceChange = { templateSource = it },
            availableBanks = availableBanks,
            selectedTemplateBank = selectedTemplateBank,
            onSelectedTemplateBankChange = { selectedTemplateBank = it },
            onApplyBankTemplate = {
                val bankGames = bankTemplateSlugs(allGamesPool, selectedTemplateBank)
                selected.clear()
                selected.addAll(bankGames)
                groupType = "bank"
                if (name.isBlank()) name = "Bank $selectedTemplateBank Focus"
            },
            duplicateCandidates = duplicateCandidates,
            selectedDuplicateGroupID = selectedDuplicateGroupID,
            onSelectedDuplicateGroupIDChange = { selectedDuplicateGroupID = it },
            onApplyDuplicateTemplate = {
                val source = duplicateCandidates.firstOrNull { it.id == selectedDuplicateGroupID } ?: return@GroupEditorTemplateCard
                val applied = applyDuplicateGroupTemplate(
                    source = source,
                    currentName = name,
                    currentStartDateMsValue = startDateMsValue,
                    currentEndDateMsValue = endDateMsValue,
                )
                selected.clear()
                selected.addAll(applied.selectedSlugs)
                groupType = applied.groupType
                isPriority = applied.isPriority
                hasStartDate = applied.hasStartDate
                hasEndDate = applied.hasEndDate
                startDateMsValue = applied.startDateMsValue
                endDateMsValue = applied.endDateMsValue
                applied.suggestedName?.let { suggested -> name = suggested }
            },
        )

        CardContainer {
            OutlinedButton(
                onClick = { showingTitleSelector = true },
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        if (selected.isEmpty()) "Select titles" else "${selected.size} selected",
                        modifier = Modifier.weight(1f),
                    )
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null)
                }
            }

            if (selected.isNotEmpty()) {
                NativeReorderSelectedCardsStrip(
                    selectedSlugs = selected,
                    gamesBySlug = selectedGamesBySlug,
                    onRequestDelete = { slug -> pendingDeleteSlug = slug },
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    "Long-press and drag to reorder. Tap a card to remove.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        GroupEditorStatusCard(
            isActive = isActive,
            onIsActiveChange = {
                isActive = it
            },
            isPriority = isPriority,
            onIsPriorityChange = { isPriority = it },
            isArchived = isArchived,
            onIsArchivedChange = { isArchived = it },
            groupType = groupType,
            onGroupTypeChange = { groupType = it },
            isEditing = editing != null,
            editingPosition = editingPosition,
            canMoveEditedUp = canMoveEditedUp,
            canMoveEditedDown = canMoveEditedDown,
            onMoveEditedUp = { editing?.let { group -> store.moveGroup(group.id, up = true) } },
            onMoveEditedDown = { editing?.let { group -> store.moveGroup(group.id, up = false) } },
            createGroupPosition = createGroupPosition,
            maxCreatePosition = maxCreatePosition,
            onCreatePositionChange = { createGroupPosition = it },
            hasStartDate = hasStartDate,
            onHasStartDateChange = {
                hasStartDate = it
                if (it && startDateMsValue <= 0L) startDateMsValue = System.currentTimeMillis()
            },
            startDateMsValue = startDateMsValue,
            onOpenStartDatePicker = {
                scheduleDateDialogField = GroupEditorDateField.Start
                scheduleDatePickerInitialMs = startDateMsValue
                openScheduleDateDialog = true
            },
            hasEndDate = hasEndDate,
            onHasEndDateChange = {
                hasEndDate = it
                if (it && endDateMsValue <= 0L) endDateMsValue = System.currentTimeMillis()
            },
            endDateMsValue = endDateMsValue,
            onOpenEndDatePicker = {
                scheduleDateDialogField = GroupEditorDateField.End
                scheduleDatePickerInitialMs = endDateMsValue
                openScheduleDateDialog = true
            },
            validationMessage = validationMessage,
        )
    }

    if (openScheduleDateDialog) {
        GroupEditorScheduleDateSheet(
            field = scheduleDateDialogField,
            initialSelectedDateMillis = scheduleDatePickerInitialMs,
            onSave = { selectedDate, field ->
                if (field == GroupEditorDateField.Start) {
                    startDateMsValue = selectedDate
                    hasStartDate = true
                } else {
                    endDateMsValue = selectedDate
                    hasEndDate = true
                }
            },
            onClear = { field ->
                if (field == GroupEditorDateField.Start) {
                    hasStartDate = false
                } else {
                    hasEndDate = false
                }
            },
            onDismiss = { openScheduleDateDialog = false },
        )
    }

    if (openDeleteGroupConfirm && editing != null) {
        DeleteGroupConfirmSheet(
            onConfirmDelete = {
                store.deleteGroup(editing.id)
                openDeleteGroupConfirm = false
                onSaved()
            },
            onDismiss = { openDeleteGroupConfirm = false },
        )
    }

    if (pendingDeleteSlug != null) {
        DeleteTitleConfirmSheet(
            onConfirmDelete = {
                pendingDeleteSlug?.let { slug -> selected.remove(slug) }
                pendingDeleteSlug = null
            },
            onDismiss = { pendingDeleteSlug = null },
        )
    }
}
