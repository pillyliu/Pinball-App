package com.pillyliu.pinprofandroid.practice

import android.content.Context
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.loadPracticeCatalogGames
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

internal data class PracticeInitialStoreLoad(
    val libraryState: PracticeLibraryStoreState,
    val loadedState: LoadedPracticeStatePayload?,
)

internal suspend fun loadInitialPracticeStoreState(
    libraryIntegration: PracticeLibraryIntegration,
    persistenceIntegration: PracticePersistenceIntegration,
): PracticeInitialStoreLoad = coroutineScope {
    val initialLibraryState = async { libraryIntegration.loadInitialLibraryState() }
    val loadedState = async { persistenceIntegration.loadState() }
    PracticeInitialStoreLoad(
        libraryState = initialLibraryState.await(),
        loadedState = loadedState.await(),
    )
}

internal suspend fun loadPracticeSearchCatalogGames(context: Context): List<PinballGame> {
    return PinballPerformanceTrace.measureSuspend("PracticeSearchCatalogLoad") {
        loadPracticeCatalogGames(context)
    }
}

internal suspend fun loadPracticeLeagueCatalogGames(context: Context): List<PinballGame> {
    return try {
        PinballPerformanceTrace.measureSuspend("PracticeLeagueCatalogLoad") {
            loadPracticeCatalogGames(context)
        }
    } catch (_: Throwable) {
        emptyList()
    }
}

internal suspend fun loadPracticeBankTemplateGamesForStore(): List<PinballGame> {
    return PinballPerformanceTrace.measureSuspend("PracticeBankTemplateLoad") {
        loadPracticeAvenueBankTemplateGames()
    }
}
