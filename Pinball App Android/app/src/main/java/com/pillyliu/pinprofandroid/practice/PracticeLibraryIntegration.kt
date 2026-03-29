package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class PracticeLibraryStoreState(
    val visibleGames: List<PinballGame>,
    val allGames: List<PinballGame>,
    val sources: List<LibrarySource>,
    val defaultSourceId: String?,
    val isFullLibraryScope: Boolean,
)

internal class PracticeLibraryIntegration(
    private val context: Context,
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
        LibrarySourceStateStore.setSelectedSource(context, sourceId)
    }

    suspend fun loadInitialLibraryState(): PracticeLibraryStoreState {
        return PinballPerformanceTrace.measureSuspend("PracticeInitialLibraryLoad") {
            loadLibraryState(fullLibraryScope = false)
        }
    }

    suspend fun loadFullLibraryState(): PracticeLibraryStoreState {
        return PinballPerformanceTrace.measureSuspend("PracticeFullLibraryHydration") {
            loadLibraryState(fullLibraryScope = true)
        }
    }

    private suspend fun loadLibraryState(fullLibraryScope: Boolean): PracticeLibraryStoreState {
        val loaded = loadPracticeGamesFromLibrary(context, fullLibraryScope = fullLibraryScope)
        val preferredSource = resolvePreferredPracticeSource(loaded, LibrarySourceStateStore.load(context).selectedSourceId)
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
            isFullLibraryScope = loaded.isFullLibraryScope,
        )
    }
}
