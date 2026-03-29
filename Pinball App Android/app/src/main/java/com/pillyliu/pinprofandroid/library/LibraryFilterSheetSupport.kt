package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.AppFilterSheet
import com.pillyliu.pinprofandroid.ui.CompactDropdownFilter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LibraryFilterSheet(
    browseState: LibraryBrowseState,
    onDismissRequest: () -> Unit,
    onSourceChange: (String) -> Unit,
    onSortOptionChange: (String) -> Unit,
    onBankChange: (Int?) -> Unit,
) {
    AppFilterSheet(
        title = "Library filters",
        onDismissRequest = onDismissRequest,
    ) {
        if (browseState.visibleSources.isNotEmpty()) {
            CompactDropdownFilter(
                selectedText = browseState.selectedSource?.name ?: "Library",
                options = browseState.visibleSources.map { it.name },
                onSelect = { selected ->
                    val source = browseState.visibleSources.firstOrNull { it.name == selected } ?: return@CompactDropdownFilter
                    onSourceChange(source.id)
                },
                modifier = Modifier.fillMaxWidth(),
                minHeight = 38.dp,
                textSize = 12.sp,
                itemTextSize = 12.sp,
            )
        }
        CompactDropdownFilter(
            selectedText = browseState.selectedSortLabel,
            options = browseState.sortOptions.flatMap {
                if (it == LibrarySortOption.YEAR) listOf("Sort: Year (Old-New)", "Sort: Year (New-Old)") else listOf(it.label)
            },
            onSelect = { selected ->
                when (selected) {
                    "Sort: Year (New-Old)" -> onSortOptionChange("YEAR_DESC")
                    "Sort: Year (Old-New)" -> onSortOptionChange(LibrarySortOption.YEAR.name)
                    else -> {
                        val option = browseState.sortOptions.firstOrNull { it.label == selected } ?: browseState.fallbackSort
                        onSortOptionChange(option.name)
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            minHeight = 38.dp,
            textSize = 12.sp,
            itemTextSize = 12.sp,
        )
        if (browseState.supportsBankFilter) {
            CompactDropdownFilter(
                selectedText = browseState.selectedBankLabel,
                options = listOf("All banks") + browseState.bankOptions.map { "Bank $it" },
                onSelect = { selected ->
                    val bank = selected.removePrefix("Bank ").trim().toIntOrNull()
                    onBankChange(bank)
                },
                modifier = Modifier.fillMaxWidth(),
                minHeight = 38.dp,
                textSize = 12.sp,
                itemTextSize = 12.sp,
            )
        }
    }
}
