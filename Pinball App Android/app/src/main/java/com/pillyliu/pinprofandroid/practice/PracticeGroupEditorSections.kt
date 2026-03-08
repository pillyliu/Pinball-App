package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppDestructiveButton
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors
import java.util.Locale

@Composable
internal fun GroupEditorActionRow(
    isEditing: Boolean,
    onCancel: () -> Unit,
    onDelete: () -> Unit,
    onSave: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppSecondaryButton(
            onClick = onCancel,
            modifier = Modifier.weight(1f),
        ) { Text("Cancel") }
        if (isEditing) {
            AppDestructiveButton(
                onClick = onDelete,
                modifier = Modifier.weight(1f),
            ) { Text("Delete") }
        }
        AppPrimaryButton(
            onClick = onSave,
            modifier = Modifier.weight(1f),
        ) { Text(if (isEditing) "Save" else "Create") }
    }
}

@Composable
internal fun GroupEditorTemplateCard(
    isEditing: Boolean,
    name: String,
    onNameChange: (String) -> Unit,
    templateSource: String,
    onTemplateSourceChange: (String) -> Unit,
    availableBanks: List<Int>,
    selectedTemplateBank: Int,
    onSelectedTemplateBankChange: (Int) -> Unit,
    onApplyBankTemplate: () -> Unit,
    duplicateCandidates: List<PracticeGroup>,
    selectedDuplicateGroupID: String,
    onSelectedDuplicateGroupIDChange: (String) -> Unit,
    onApplyDuplicateTemplate: () -> Unit,
) {
    CardContainer {
        OutlinedTextField(
            value = name,
            onValueChange = onNameChange,
            label = { Text("Group name") },
            modifier = Modifier.fillMaxWidth(),
        )
        if (isEditing) return@CardContainer

        SimpleMenuDropdown(
            title = "Template",
            options = listOf("none", "bank", "duplicate"),
            selected = templateSource,
            formatOptionLabel = {
                when (it) {
                    "bank" -> "Bank Template"
                    "duplicate" -> "Duplicate Group"
                    else -> "None"
                }
            },
            onSelect = onTemplateSourceChange,
        )
        when (templateSource) {
            "bank" -> {
                if (availableBanks.isEmpty()) {
                    AppPanelEmptyCard(text = "No bank data found in library.")
                } else {
                    SimpleMenuDropdown(
                        title = "Bank",
                        options = availableBanks.map { it.toString() },
                        selected = selectedTemplateBank.toString(),
                        formatOptionLabel = { "Bank $it" },
                        onSelect = { onSelectedTemplateBankChange(it.toIntOrNull() ?: selectedTemplateBank) },
                    )
                    AppSecondaryButton(onClick = onApplyBankTemplate) { Text("Apply Bank Template") }
                }
            }

            "duplicate" -> {
                if (duplicateCandidates.isEmpty()) {
                    AppPanelEmptyCard(text = "No existing groups to duplicate.")
                } else {
                    if (selectedDuplicateGroupID.isBlank()) {
                        onSelectedDuplicateGroupIDChange(duplicateCandidates.first().id)
                    }
                    SimpleMenuDropdown(
                        title = "Group",
                        options = duplicateCandidates.map { it.id },
                        selected = selectedDuplicateGroupID,
                        formatOptionLabel = { id -> duplicateCandidates.firstOrNull { it.id == id }?.name ?: id },
                        onSelect = onSelectedDuplicateGroupIDChange,
                    )
                    AppSecondaryButton(onClick = onApplyDuplicateTemplate) { Text("Apply Duplicate Group") }
                }
            }
        }
    }
}

@Composable
internal fun GroupEditorStatusCard(
    isActive: Boolean,
    onIsActiveChange: (Boolean) -> Unit,
    isPriority: Boolean,
    onIsPriorityChange: (Boolean) -> Unit,
    isArchived: Boolean,
    onIsArchivedChange: (Boolean) -> Unit,
    groupType: String,
    onGroupTypeChange: (String) -> Unit,
    isEditing: Boolean,
    editingPosition: Int,
    canMoveEditedUp: Boolean,
    canMoveEditedDown: Boolean,
    onMoveEditedUp: () -> Unit,
    onMoveEditedDown: () -> Unit,
    createGroupPosition: Int,
    maxCreatePosition: Int,
    onCreatePositionChange: (Int) -> Unit,
    hasStartDate: Boolean,
    onHasStartDateChange: (Boolean) -> Unit,
    startDateMsValue: Long,
    onOpenStartDatePicker: () -> Unit,
    hasEndDate: Boolean,
    onHasEndDateChange: (Boolean) -> Unit,
    endDateMsValue: Long,
    onOpenEndDatePicker: () -> Unit,
    validationMessage: String?,
) {
    CardContainer {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Active", modifier = Modifier.weight(1f))
            Switch(checked = isActive, onCheckedChange = onIsActiveChange)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Priority", modifier = Modifier.weight(1f))
            Switch(checked = isPriority, onCheckedChange = onIsPriorityChange)
        }
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            listOf("custom", "bank", "location").forEachIndexed { index, option ->
                SegmentedButton(
                    selected = groupType == option,
                    onClick = { onGroupTypeChange(option) },
                    colors = pinballSegmentedButtonColors(),
                    shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(index, 3),
                    icon = {},
                    label = { Text(option.replaceFirstChar { it.titlecase(Locale.US) }, maxLines = 1) },
                )
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Position", modifier = Modifier.weight(1f))
            Row(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.widthIn(min = 112.dp),
            ) {
                TextButton(
                    onClick = {
                        if (isEditing) onMoveEditedDown() else if (createGroupPosition < maxCreatePosition) onCreatePositionChange(createGroupPosition + 1)
                    },
                    enabled = if (isEditing) canMoveEditedDown else createGroupPosition < maxCreatePosition,
                ) {
                    Text("⌄", fontWeight = FontWeight.SemiBold)
                }
                Box(modifier = Modifier.width(24.dp), contentAlignment = Alignment.Center) {
                    Text(
                        if (isEditing) editingPosition.toString() else createGroupPosition.toString(),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
                TextButton(
                    onClick = {
                        if (isEditing) onMoveEditedUp() else if (createGroupPosition > 1) onCreatePositionChange(createGroupPosition - 1)
                    },
                    enabled = if (isEditing) canMoveEditedUp else createGroupPosition > 1,
                ) {
                    Text("⌃", fontWeight = FontWeight.SemiBold)
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Start Date", modifier = Modifier.weight(1f))
            AppSecondaryButton(
                onClick = {
                    if (!hasStartDate) onHasStartDateChange(true)
                    onOpenStartDatePicker()
                },
            ) {
                Text(
                    if (hasStartDate) formatShortDate(startDateMsValue) else "Select date",
                    style = MaterialTheme.typography.labelSmall,
                    color = if (hasStartDate) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(checked = hasStartDate, onCheckedChange = onHasStartDateChange)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("End Date", modifier = Modifier.weight(1f))
            AppSecondaryButton(
                onClick = {
                    if (!hasEndDate) onHasEndDateChange(true)
                    onOpenEndDatePicker()
                },
            ) {
                Text(
                    if (hasEndDate) formatShortDate(endDateMsValue) else "Select date",
                    style = MaterialTheme.typography.labelSmall,
                    color = if (hasEndDate) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(checked = hasEndDate, onCheckedChange = onHasEndDateChange)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Archived", modifier = Modifier.weight(1f))
            Switch(checked = isArchived, onCheckedChange = onIsArchivedChange)
        }
        validationMessage?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        }
    }
}
