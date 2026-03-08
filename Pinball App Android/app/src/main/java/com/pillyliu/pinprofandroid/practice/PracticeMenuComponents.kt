package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.DropdownOption

@Composable
internal fun SimpleMenuDropdown(
    title: String,
    options: List<String>,
    selected: String,
    selectedLabel: String = selected,
    formatOptionLabel: (String) -> String = { it },
    onSelect: (String) -> Unit,
) {
    AnchoredDropdownFilter(
        selectedText = selectedLabel,
        options = options.map { option ->
            DropdownOption(value = option, label = formatOptionLabel(option))
        },
        onSelect = onSelect,
        modifier = Modifier.fillMaxWidth(),
        label = title,
    )
}

@Composable
internal fun InsightsMenuDropdown(
    selectedLabel: String,
    options: List<Pair<String, String>>,
    onSelect: (Pair<String, String>) -> Unit,
) {
    AnchoredDropdownFilter(
        selectedText = selectedLabel,
        options = options.map { option ->
            DropdownOption(value = option.first, label = option.second)
        },
        onSelect = { selection ->
            options.firstOrNull { it.first == selection }?.let(onSelect)
        },
        modifier = Modifier.fillMaxWidth(),
    )
}
