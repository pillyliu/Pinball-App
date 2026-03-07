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
        uiState.selectedGameSlug = slug
        store.markPracticeViewedGame(slug)
    }

    fun openPracticeGame(slug: String) {
        selectPracticeGame(slug)
        uiState.navigateTo(PracticeRoute.Game)
    }

    fun selectLibrarySource(sourceId: String) {
        store.setPreferredLibrarySource(normalizePracticeLibrarySourceId(sourceId))
        if (uiState.selectedGameSlug != null && findGameByPracticeLookupKey(store.games, uiState.selectedGameSlug) == null) {
            uiState.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    fun openQuickEntry(activity: QuickActivity, origin: QuickEntryOrigin, fromGameView: Boolean) {
        uiState.openQuickEntryFor(activity, origin, fromGameView)
    }

    fun navigateTo(route: PracticeRoute) {
        uiState.navigateTo(route)
    }

    fun toggleJournalSelectionMode() {
        uiState.selectedJournalRowIds = emptySet()
        uiState.journalSelectionMode = !uiState.journalSelectionMode
    }

    fun createGroup() {
        uiState.editingGroupID = null
        uiState.navigateTo(PracticeRoute.GroupEditor)
    }

    fun editGroup(groupId: String) {
        uiState.editingGroupID = groupId
        uiState.navigateTo(PracticeRoute.GroupEditor)
    }

    fun openGroupDatePicker(groupId: String?, field: GroupDashboardDateField, initialMs: Long?) {
        uiState.groupDateDialogGroupID = groupId
        uiState.groupDateDialogField = field
        uiState.groupDatePickerInitialMs = initialMs
        uiState.openGroupDateDialog = true
    }

    fun selectInsightsOpponent(selected: String) {
        uiState.insightsOpponentName = selected
        store.updateComparisonPlayerName(selected)
    }

    suspend fun refreshHeadToHeadComparison() {
        if (store.playerName.isBlank() || uiState.insightsOpponentName.isBlank()) {
            uiState.headToHead = null
            return
        }
        uiState.isLoadingHeadToHead = true
        uiState.headToHead = store.comparePlayers(store.playerName, uiState.insightsOpponentName)
        uiState.isLoadingHeadToHead = false
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
            uiState.importStatus = store.importLeagueScoresFromCsv()
        }
    }

    fun openResetDialog() {
        uiState.openResetDialog = true
    }

    fun openRulesheet(source: RulesheetRemoteSource?) {
        if (selectedGame?.hasRulesheetResource != true) return
        uiState.selectedRulesheetSource = source
        uiState.selectedExternalRulesheetUrl = null
        uiState.navigateTo(PracticeRoute.Rulesheet)
    }

    fun openExternalRulesheet(url: String) {
        if (selectedGame == null) return
        uiState.selectedRulesheetSource = null
        uiState.selectedExternalRulesheetUrl = url
        uiState.navigateTo(PracticeRoute.Rulesheet)
    }

    fun openPlayfield(urls: List<String>) {
        uiState.selectedPlayfieldUrls = urls
        uiState.navigateTo(PracticeRoute.Playfield)
    }
}
