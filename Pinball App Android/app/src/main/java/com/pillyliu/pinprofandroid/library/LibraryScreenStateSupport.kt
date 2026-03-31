package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.PinballPerformanceTrace

internal data class LibraryScreenLoadedState(
    val games: List<PinballGame>,
    val sources: List<LibrarySource>,
    val sourceState: LibrarySourceState,
    val selection: LibrarySelectionResolution?,
)

internal data class LibraryScreenSortSelection(
    val sortOptionName: String,
    val yearSortDescending: Boolean,
    val sourceState: LibrarySourceState,
)

internal suspend fun loadLibraryScreenState(
    context: Context,
    currentSelectedSourceId: String,
): LibraryScreenLoadedState {
    return PinballPerformanceTrace.measureSuspend("LibraryScreenLoad") {
        val extraction = loadLibraryExtraction(context)
        val payload = extraction.payload
        val sourceState = extraction.state
        LibraryScreenLoadedState(
            games = payload.games,
            sources = payload.sources,
            sourceState = sourceState,
            selection = resolveLibrarySelection(
                payload = payload,
                sourceState = sourceState,
                currentSelectedSourceId = currentSelectedSourceId,
            ),
        )
    }
}

internal fun resolveLibraryScreenSourceSelection(
    sourceId: String,
    sources: List<LibrarySource>,
    games: List<PinballGame>,
    sourceState: LibrarySourceState,
): LibrarySelectionResolution? {
    val source = sources.firstOrNull { it.id == sourceId } ?: return null
    return resolveLibrarySelectionForSource(
        source = source,
        games = games,
        sourceState = sourceState,
    )
}

internal fun persistLibraryScreenSelection(
    context: Context,
    sourceState: LibrarySourceState,
    selection: LibrarySelectionResolution,
): LibrarySourceState {
    LibrarySourceStateStore.setSelectedSource(context, selection.selectedSourceId)
    return sourceState.copy(selectedSourceId = selection.selectedSourceId)
}

internal fun persistLibraryScreenSortSelection(
    context: Context,
    sourceState: LibrarySourceState,
    sourceId: String,
    sortOptionName: String,
    yearSortDescending: Boolean,
): LibraryScreenSortSelection {
    val persistedSort = if (sortOptionName == LibrarySortOption.YEAR.name && yearSortDescending) {
        "YEAR_DESC"
    } else {
        sortOptionName
    }
    LibrarySourceStateStore.setSelectedSort(context, sourceId, persistedSort)
    return LibraryScreenSortSelection(
        sortOptionName = sortOptionName,
        yearSortDescending = yearSortDescending,
        sourceState = sourceState.copy(
            selectedSortBySource = sourceState.selectedSortBySource.toMutableMap().apply {
                this[sourceId] = persistedSort
            },
        ),
    )
}

internal fun persistLibraryScreenBankSelection(
    context: Context,
    sourceState: LibrarySourceState,
    sourceId: String,
    selectedBank: Int?,
): LibrarySourceState {
    LibrarySourceStateStore.setSelectedBank(context, sourceId, selectedBank)
    return sourceState.copy(
        selectedBankBySource = sourceState.selectedBankBySource.toMutableMap().apply {
            if (selectedBank == null) {
                remove(sourceId)
            } else {
                this[sourceId] = selectedBank
            }
        },
    )
}
