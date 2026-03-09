package com.pillyliu.pinprofandroid.practice

import androidx.compose.ui.platform.UriHandler
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.hasRulesheetResource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class PracticeScreenActions(
    private val store: PracticeStore,
    private val uiState: PracticeScreenState,
    private val scope: CoroutineScope,
    private val uriHandler: UriHandler,
    private val selectedGame: PinballGame?,
) {
    fun selectPracticeGame(slug: String) {
        uiState.navigation.selectedGameSlug = slug
        store.markPracticeViewedGame(slug)
    }

    fun openPracticeGame(slug: String) {
        selectPracticeGame(slug)
        uiState.navigateTo(PracticeRoute.Game)
    }

    fun selectLibrarySource(sourceId: String) {
        store.setPreferredLibrarySource(normalizePracticeLibrarySourceId(sourceId))
        if (uiState.navigation.selectedGameSlug != null &&
            findGameByPracticeLookupKey(store.games, uiState.navigation.selectedGameSlug) == null
        ) {
            uiState.navigation.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    fun openQuickEntry(activity: QuickActivity, origin: QuickEntryOrigin, fromGameView: Boolean) {
        uiState.openQuickEntryFor(activity, origin, fromGameView)
    }

    fun navigateTo(route: PracticeRoute) {
        uiState.navigateTo(route)
    }

    fun toggleJournalSelectionMode() {
        uiState.journal.selectedRowIds = emptySet()
        uiState.journal.selectionMode = !uiState.journal.selectionMode
    }

    fun createGroup() {
        uiState.navigation.editingGroupID = null
        uiState.navigateTo(PracticeRoute.GroupEditor)
    }

    fun editGroup(groupId: String) {
        uiState.navigation.editingGroupID = groupId
        uiState.navigateTo(PracticeRoute.GroupEditor)
    }

    fun openGroupDatePicker(groupId: String?, field: GroupDashboardDateField, initialMs: Long?) {
        uiState.presentation.groupDateDialogGroupID = groupId
        uiState.presentation.groupDateDialogField = field
        uiState.presentation.groupDatePickerInitialMs = initialMs
        uiState.presentation.openGroupDateDialog = true
    }

    fun selectInsightsOpponent(selected: String) {
        uiState.insights.opponentName = selected
        store.updateComparisonPlayerName(selected)
    }

    suspend fun refreshHeadToHeadComparison() {
        if (store.playerName.isBlank() || uiState.insights.opponentName.isBlank()) {
            uiState.insights.headToHead = null
            return
        }
        uiState.insights.isLoadingHeadToHead = true
        uiState.insights.headToHead = store.comparePlayers(store.playerName, uiState.insights.opponentName)
        uiState.insights.isLoadingHeadToHead = false
    }

    fun refreshHeadToHead() {
        scope.launch {
            refreshHeadToHeadComparison()
        }
    }

    fun openDeadFlipTutorials() {
        uriHandler.openUri("https://www.deadflip.com/tutorials")
    }

    fun importLplCsv() {
        scope.launch {
            uiState.presentation.importStatus = store.importLeagueScoresFromCsv()
        }
    }

    fun openResetDialog() {
        uiState.presentation.openResetDialog = true
    }

    fun openRulesheet(source: RulesheetRemoteSource?) {
        if (selectedGame?.hasRulesheetResource != true) return
        uiState.navigation.selectedRulesheetSource = source
        uiState.navigation.selectedExternalRulesheetUrl = null
        uiState.navigateTo(PracticeRoute.Rulesheet)
    }

    fun openExternalRulesheet(url: String) {
        if (selectedGame == null) return
        uiState.navigation.selectedRulesheetSource = null
        uiState.navigation.selectedExternalRulesheetUrl = url
        uiState.navigateTo(PracticeRoute.Rulesheet)
    }

    fun openPlayfield(urls: List<String>) {
        uiState.navigation.selectedPlayfieldUrls = urls
        uiState.navigateTo(PracticeRoute.Playfield)
    }
}
