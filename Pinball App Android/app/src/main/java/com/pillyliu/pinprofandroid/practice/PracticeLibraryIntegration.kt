package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class PracticeLibraryStoreState(
    val visibleGames: List<PinballGame>,
    val allGames: List<PinballGame>,
    val sources: List<LibrarySource>,
    val defaultSourceId: String?,
)

internal class PracticeLibraryIntegration(
    private val context: Context,
    private val preferredSourceId: () -> String?,
    private val savePreferredSourceId: (String?) -> Unit,
) {
    fun applySelectedSource(
        sourceId: String?,
        sources: List<LibrarySource>,
        allGames: List<PinballGame>,
    ): PracticeLibrarySourceSelectionResult {
        return applyPracticeLibrarySourceSelection(
            sourceId = sourceId,
            sources = sources,
            allGames = allGames,
        )
    }

    fun persistSelectedSource(sourceId: String?) {
        savePreferredSourceId(sourceId)
        LibrarySourceStateStore.setSelectedSource(context, sourceId)
    }

    suspend fun loadLibraryState(): PracticeLibraryStoreState {
        val loaded = loadPracticeGamesFromLibrary(context)
        val preferredSource = resolvePreferredPracticeSource(loaded, preferredSourceId())
        val selection = applyPracticeLibrarySourceSelection(
            sourceId = preferredSource?.id,
            sources = loaded.sources,
            allGames = loaded.allGames,
        )
        return PracticeLibraryStoreState(
            visibleGames = selection.visibleGames.ifEmpty { loaded.games },
            allGames = loaded.allGames,
            sources = loaded.sources,
            defaultSourceId = selection.selectedSourceId ?: loaded.defaultSourceId,
        )
    }
}
