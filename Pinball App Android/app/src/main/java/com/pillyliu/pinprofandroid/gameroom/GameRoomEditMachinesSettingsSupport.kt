package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppCompactIconButton
import com.pillyliu.pinprofandroid.ui.AppDestructiveButton
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.DropdownOptionGroup
import com.pillyliu.pinprofandroid.ui.GroupedAnchoredDropdownFilter

@Composable
internal fun GameRoomAreaSettingsCard(
    context: GameRoomEditSettingsContext,
) {
    CardContainer {
        SectionHeader(
            title = "Areas",
            expanded = context.areasExpanded,
            onToggle = { context.onAreasExpandedChange(!context.areasExpanded) },
        )
        if (context.areasExpanded) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = context.areaNameDraft,
                    onValueChange = context.onAreaNameDraftChange,
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("Area Name") },
                )
                OutlinedTextField(
                    value = context.areaOrderDraft,
                    onValueChange = context.onAreaOrderDraftChange,
                    modifier = Modifier.width(120.dp),
                    singleLine = true,
                    label = { Text("Area Order") },
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppPrimaryButton(
                    onClick = {
                        context.onSaveArea()
                        context.onShowSaveFeedback("Area saved")
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Save") }
            }
            context.store.state.areas.forEach { area ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { context.onEditArea(area) }
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "${area.name} (${area.areaOrder})",
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    AppCompactIconButton(
                        icon = Icons.Outlined.Delete,
                        contentDescription = "Delete area",
                        onClick = {
                            context.onDeleteArea(area.id)
                            context.onShowSaveFeedback("Area deleted")
                        },
                        destructive = true,
                    )
                }
            }
        }
    }
}

@Composable
internal fun GameRoomEditMachinesSettingsCard(
    context: GameRoomEditSettingsContext,
) {
    CardContainer {
        SectionHeader(
            title = "Edit Machines (${context.store.activeMachines.size})",
            expanded = context.editMachinesExpanded,
            onToggle = { context.onEditMachinesExpandedChange(!context.editMachinesExpanded) },
        )
        if (context.editMachinesExpanded) {
            val machineGroups = context.allMachines
                .groupBy { machine -> context.store.area(machine.gameRoomAreaID)?.name ?: "No Area" }
                .toSortedMap(String.CASE_INSENSITIVE_ORDER)
                .map { (title, machines) ->
                    DropdownOptionGroup(
                        title = title,
                        options = machines.sortedWith(
                            compareBy<OwnedMachine> { it.displayTitle.lowercase() }
                                .thenBy { it.id },
                        ).map { machine ->
                            DropdownOption(
                                value = machine.id,
                                label = editMachineLabel(machine),
                            )
                        },
                    )
                }
            if (context.selectedEditMachine == null) {
                GroupedAnchoredDropdownFilter(
                    selectedText = "Select Machine",
                    groups = machineGroups,
                    onSelect = context.onSelectedEditMachineChange,
                )
            }
            if (context.selectedEditMachine != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    GroupedAnchoredDropdownFilter(
                        selectedText = editMachineLabel(context.selectedEditMachine),
                        groups = machineGroups,
                        onSelect = context.onSelectedEditMachineChange,
                        modifier = Modifier.weight(1f),
                    )
                    VariantPillDropdown(
                        selectedLabel = context.draftVariant,
                        options = context.variantOptions,
                        onSelect = context.onDraftVariantChange,
                        modifier = Modifier.weight(0.52f),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AnchoredDropdownFilter(
                        selectedText = context.store.area(context.draftAreaID)?.name ?: "No area",
                        options = buildList {
                            add(DropdownOption(value = "", label = "No area"))
                            addAll(context.store.state.areas.map { DropdownOption(it.id, it.name) })
                        },
                        onSelect = { context.onDraftAreaIDChange(it.ifBlank { null }) },
                        modifier = Modifier.weight(1f),
                    )
                    AnchoredDropdownFilter(
                        selectedText = context.draftStatus.replaceFirstChar { it.uppercase() },
                        options = OwnedMachineStatus.entries.map {
                            DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                        },
                        onSelect = context.onDraftStatusChange,
                        modifier = Modifier.weight(1f),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = context.draftGroup,
                        onValueChange = context.onDraftGroupChange,
                        label = { Text("Group") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.draftPosition,
                        onValueChange = context.onDraftPositionChange,
                        label = { Text("Position") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                    )
                }
                OutlinedTextField(
                    value = context.draftPurchaseSource,
                    onValueChange = context.onDraftPurchaseSourceChange,
                    label = { Text("Purchase Source") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = context.draftSerialNumber,
                    onValueChange = context.onDraftSerialNumberChange,
                    label = { Text("Serial Number") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = context.draftOwnershipNotes,
                    onValueChange = context.onDraftOwnershipNotesChange,
                    label = { Text("Ownership Notes") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    AppPrimaryButton(
                        onClick = {
                            context.onSaveMachine()
                            context.onShowSaveFeedback("Machine details saved")
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("Save") }
                    AppDestructiveButton(
                        onClick = {
                            context.onDeleteMachine()
                            context.onShowSaveFeedback("Machine deleted")
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("Delete") }
                    if (context.onArchiveMachine != null) {
                        AppSecondaryButton(
                            onClick = {
                                context.onArchiveMachine.invoke()
                                context.onShowSaveFeedback("Machine archived")
                            },
                            modifier = Modifier.weight(1f),
                        ) { Text("Archive") }
                    }
                }
            }
        }
    }
}

internal fun editMachineLabel(machine: OwnedMachine): String {
    return if (machine.status == OwnedMachineStatus.active) {
        machine.displayTitle
    } else {
        "${machine.displayTitle} (${machine.status.name.replaceFirstChar { it.uppercase() }})"
    }
}
