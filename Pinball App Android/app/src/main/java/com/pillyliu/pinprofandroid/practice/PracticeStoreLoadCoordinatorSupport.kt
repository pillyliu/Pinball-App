package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.library.PinballGame

internal class PracticeStoreLoadCoordinator(
    private val context: Context,
    private val libraryIntegration: PracticeLibraryIntegration,
    private val applyLibraryState: (PracticeLibraryStoreState) -> Unit,
    private val updateSearchCatalogGames: (List<PinballGame>) -> Unit,
    private val updateBankTemplateGames: (List<PinballGame>) -> Unit,
    private val saveHomeBootstrapSnapshot: () -> Unit,
    private val ensureLeagueTargetsLoaded: suspend () -> Unit,
) {
    var isLoadingSearchCatalog by mutableStateOf(false)
        private set

    var isLoadingAllLibraryGames by mutableStateOf(false)
        private set

    var isLoadingLeagueTargets by mutableStateOf(false)
        private set

    var didLoadLeagueTargets by mutableStateOf(false)
        private set

    var isBootstrapping by mutableStateOf(true)
        private set

    var hasRestoredHomeBootstrapSnapshot by mutableStateOf(false)
        private set

    var didLoadAllLibraryGames = false
        private set

    var leagueCatalogGames: List<PinballGame> = emptyList()
        private set

    private var isLoadingBankTemplateGames = false
    private var isLoadingLeagueCatalogGames = false

    fun finishBootstrapping() {
        isBootstrapping = false
    }

    fun setDidLoadAllLibraryGames(value: Boolean) {
        didLoadAllLibraryGames = value
    }

    fun recordHomeBootstrapRestore(hasUsableSnapshot: Boolean) {
        hasRestoredHomeBootstrapSnapshot = hasUsableSnapshot
    }

    suspend fun loadGames() {
        applyLibraryState(libraryIntegration.loadInitialLibraryState())
        saveHomeBootstrapSnapshot()
    }

    suspend fun ensureAllLibraryGamesLoaded() {
        if (didLoadAllLibraryGames || isLoadingAllLibraryGames) return
        isLoadingAllLibraryGames = true
        try {
            applyLibraryState(libraryIntegration.loadFullLibraryState())
            saveHomeBootstrapSnapshot()
        } finally {
            isLoadingAllLibraryGames = false
        }
    }

    suspend fun ensureSearchCatalogGamesLoaded(currentGames: List<PinballGame>) {
        if (currentGames.isNotEmpty() || isLoadingSearchCatalog) return
        isLoadingSearchCatalog = true
        try {
            updateSearchCatalogGames(loadPracticeSearchCatalogGames(context))
            saveHomeBootstrapSnapshot()
        } finally {
            isLoadingSearchCatalog = false
        }
    }

    suspend fun ensureLeagueCatalogGamesLoaded() {
        if (leagueCatalogGames.isNotEmpty() || isLoadingLeagueCatalogGames) return
        isLoadingLeagueCatalogGames = true
        try {
            leagueCatalogGames = loadPracticeLeagueCatalogGames(context)
        } finally {
            isLoadingLeagueCatalogGames = false
        }
    }

    suspend fun ensureBankTemplateGamesLoaded(currentGames: List<PinballGame>) {
        if (currentGames.isNotEmpty() || isLoadingBankTemplateGames) return
        isLoadingBankTemplateGames = true
        try {
            updateBankTemplateGames(loadPracticeBankTemplateGamesForStore())
            saveHomeBootstrapSnapshot()
        } finally {
            isLoadingBankTemplateGames = false
        }
    }

    suspend fun ensureLeagueTargetsLoaded() {
        if (didLoadLeagueTargets || isLoadingLeagueTargets) return
        isLoadingLeagueTargets = true
        try {
            ensureLeagueTargetsLoaded.invoke()
            didLoadLeagueTargets = true
        } finally {
            isLoadingLeagueTargets = false
        }
    }
}
