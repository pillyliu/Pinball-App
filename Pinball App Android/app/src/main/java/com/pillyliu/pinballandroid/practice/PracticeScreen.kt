package com.pillyliu.pinballandroid.practice

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.core.content.edit
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.library.PlayfieldScreen
import com.pillyliu.pinballandroid.library.RulesheetScreen
import com.pillyliu.pinballandroid.library.fullscreenPlayfieldCandidates
import com.pillyliu.pinballandroid.library.youtubeId
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import kotlinx.coroutines.launch
import java.util.Locale

internal enum class PracticeRoute {
    Home,
    GroupDashboard,
    GroupEditor,
    Journal,
    Insights,
    Mechanics,
    Settings,
    Game,
    Rulesheet,
    Playfield,
}

internal enum class PracticeGameSubview(val label: String) {
    Summary("Summary"),
    Input("Input"),
    Log("Log"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PracticeScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val store = remember { PracticeStore(context) }
    val prefs = remember { context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE) }
    val scope = rememberCoroutineScope()
    val uiState = rememberPracticeScreenState(prefs)

    suspend fun refreshHeadToHeadComparison() {
        if (store.playerName.isBlank() || uiState.insightsOpponentName.isBlank()) {
            uiState.headToHead = null
            return
        }
        uiState.isLoadingHeadToHead = true
        uiState.headToHead = store.comparePlayers(store.playerName, uiState.insightsOpponentName)
        uiState.isLoadingHeadToHead = false
    }

    LaunchedEffect(Unit) {
        store.loadIfNeeded()
        if (store.playerName.isBlank()) {
            uiState.openNamePrompt = true
        }
        uiState.insightsOpponentName = store.comparisonPlayerName
        if (uiState.selectedGameSlug == null) {
            uiState.selectedGameSlug = store.resumeSlugFromLibraryOrPractice()
                ?: orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    LaunchedEffect(store.playerName) {
        val names = store.availableLeaguePlayers()
        val normalizedSelf = store.playerName.trim().lowercase(Locale.US)
        uiState.insightsOpponentOptions = names.filter { it.lowercase(Locale.US) != normalizedSelf }
        if (uiState.insightsOpponentName.isNotBlank() && !uiState.insightsOpponentOptions.contains(uiState.insightsOpponentName)) {
            uiState.insightsOpponentName = ""
            store.updateComparisonPlayerName("")
        }
    }

    val gameLookupPool = if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
    val selectedGame = findGameByPracticeLookupKey(gameLookupPool, uiState.selectedGameSlug)

    LaunchedEffect(uiState.selectedGameSlug, store.games, store.allLibraryGames) {
        val lookup = uiState.selectedGameSlug ?: return@LaunchedEffect
        val game = findGameByPracticeLookupKey(gameLookupPool, lookup) ?: return@LaunchedEffect
        uiState.gameSummaryDraft = store.gameSummaryNoteFor(game.practiceKey)
        uiState.activeGameVideoId = game.videos.firstNotNullOfOrNull { video -> youtubeId(video.url) }
    }

    BackHandler(enabled = uiState.route != PracticeRoute.Home) {
        uiState.goBack()
    }

    LaunchedEffect(store.playerName, uiState.insightsOpponentName, uiState.route) {
        if (uiState.route != PracticeRoute.Insights) return@LaunchedEffect
        refreshHeadToHeadComparison()
    }

    LaunchedEffect(uiState.journalFilter) {
        prefs.edit { putString(KEY_PRACTICE_JOURNAL_FILTER, uiState.journalFilter.name) }
        uiState.journalSelectionMode = false
        uiState.selectedJournalRowIds = emptySet()
    }

    when (uiState.route) {
        PracticeRoute.Rulesheet -> {
            val game = selectedGame
            if (game != null) {
                RulesheetScreen(
                    contentPadding = contentPadding,
                    slug = game.practiceKey,
                    remoteCandidates = listOfNotNull(
                        game.rulesheetLocal?.let { "https://pillyliu.com$it" },
                        "https://pillyliu.com/pinball/rulesheets/${game.practiceKey}-rulesheet.md",
                        "https://pillyliu.com/pinball/rulesheets/${game.slug}.md",
                    ),
                    onBack = uiState::goBack,
                    practiceSavedRatio = store.rulesheetSavedProgress(game.practiceKey),
                    onSavePracticeRatio = { ratio -> store.saveRulesheetProgress(game.practiceKey, ratio) },
                )
            } else {
                uiState.resetToHome()
            }
            return
        }

        PracticeRoute.Playfield -> {
            val game = selectedGame
            if (game != null) {
                PlayfieldScreen(
                    contentPadding = contentPadding,
                    title = game.name,
                    imageUrls = uiState.selectedPlayfieldUrls.ifEmpty { game.fullscreenPlayfieldCandidates() },
                    onBack = uiState::goBack,
                )
            } else {
                uiState.resetToHome()
            }
            return
        }

        else -> Unit
    }

    AppScreen(
        contentPadding = contentPadding,
        modifier = Modifier.iosEdgeSwipeBack(
            enabled = uiState.route != PracticeRoute.Home && uiState.route != PracticeRoute.Rulesheet && uiState.route != PracticeRoute.Playfield,
            onBack = uiState::goBack,
        ),
    ) {
        val bodyModifier = if (uiState.route == PracticeRoute.Journal) {
            Modifier.fillMaxSize()
        } else {
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        }
        Column(
            modifier = bodyModifier,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            PracticeTopBar(
                route = uiState.route,
                playerName = store.playerName,
                editingGroupID = uiState.editingGroupID,
                selectedGameName = selectedGame?.name,
                games = store.games,
                librarySources = store.librarySources,
                selectedLibrarySourceId = store.defaultPracticeSourceId,
                gamePickerExpanded = uiState.gamePickerExpanded,
                onGamePickerExpandedChange = { expanded -> uiState.gamePickerExpanded = expanded },
                onLibrarySourceSelected = { sourceId ->
                    val normalizedSourceId = if (sourceId == "__practice_home_all_games__" || sourceId == "__practice_topbar_all_games__") null else sourceId
                    store.setPreferredLibrarySource(normalizedSourceId)
                    if (uiState.selectedGameSlug != null && findGameByPracticeLookupKey(store.games, uiState.selectedGameSlug) == null) {
                        uiState.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
                    }
                },
                onGameSelected = { game ->
                    uiState.selectedGameSlug = game.practiceKey
                    store.markPracticeViewedGame(game.practiceKey)
                },
                onBack = uiState::goBack,
                onOpenSettings = { uiState.navigateTo(PracticeRoute.Settings) },
                isJournalSelectionMode = uiState.journalSelectionMode,
                onToggleJournalSelectionMode = if (uiState.route == PracticeRoute.Journal) {
                    {
                        uiState.selectedJournalRowIds = emptySet()
                        uiState.journalSelectionMode = !uiState.journalSelectionMode
                    }
                } else null,
            )

            val routeContentContext = PracticeRouteContentContext(
                store = store,
                selectedGame = selectedGame,
                selectedGameSlug = uiState.selectedGameSlug,
                onSelectGameSlug = { uiState.selectedGameSlug = it },
                gameSubview = uiState.gameSubview,
                onGameSubviewChange = { updated -> uiState.gameSubview = updated },
                gameSummaryDraft = uiState.gameSummaryDraft,
                onGameSummaryDraftChange = { updated -> uiState.gameSummaryDraft = updated },
                activeGameVideoId = uiState.activeGameVideoId,
                onActiveGameVideoIdChange = { updated -> uiState.activeGameVideoId = updated },
                resumeOtherExpanded = uiState.resumeOtherExpanded,
                onResumeOtherExpandedChange = { expanded -> uiState.resumeOtherExpanded = expanded },
                librarySources = store.librarySources,
                selectedLibrarySourceId = store.defaultPracticeSourceId,
                onSelectLibrarySourceId = { sourceId ->
                    val normalizedSourceId = if (sourceId == "__practice_home_all_games__" || sourceId == "__practice_topbar_all_games__") null else sourceId
                    store.setPreferredLibrarySource(normalizedSourceId)
                    if (uiState.selectedGameSlug != null && findGameByPracticeLookupKey(store.games, uiState.selectedGameSlug) == null) {
                        uiState.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
                    }
                },
                onOpenQuickEntry = { activity, origin, fromGameView ->
                    uiState.openQuickEntryFor(activity, origin, fromGameView)
                },
                onOpenGroupDashboard = { uiState.navigateTo(PracticeRoute.GroupDashboard) },
                onOpenJournal = { uiState.navigateTo(PracticeRoute.Journal) },
                onOpenInsights = { uiState.navigateTo(PracticeRoute.Insights) },
                onOpenMechanics = { uiState.navigateTo(PracticeRoute.Mechanics) },
                onOpenGameRoute = { uiState.navigateTo(PracticeRoute.Game) },
                onOpenRulesheet = {
                    if (!selectedGame?.rulesheetLocal.isNullOrBlank()) {
                        uiState.navigateTo(PracticeRoute.Rulesheet)
                    }
                },
                onOpenPlayfield = { urls ->
                    uiState.selectedPlayfieldUrls = urls
                    uiState.navigateTo(PracticeRoute.Playfield)
                },
                editingGroupID = uiState.editingGroupID,
                onEditingGroupIDChange = { uiState.editingGroupID = it },
                onNavigateGroupEditor = { uiState.navigateTo(PracticeRoute.GroupEditor) },
                onBack = uiState::goBack,
                journalFilter = uiState.journalFilter,
                onJournalFilterChange = { uiState.journalFilter = it },
                journalSelectionMode = uiState.journalSelectionMode,
                selectedJournalRowIds = uiState.selectedJournalRowIds,
                onJournalSelectionModeChange = { uiState.journalSelectionMode = it },
                onSelectedJournalRowIdsChange = { uiState.selectedJournalRowIds = it },
                journalTimelineModifier = Modifier.fillMaxSize(),
                insightsOpponentName = uiState.insightsOpponentName,
                insightsOpponentOptions = uiState.insightsOpponentOptions,
                onInsightsOpponentNameChange = { selected ->
                    uiState.insightsOpponentName = selected
                    store.updateComparisonPlayerName(selected)
                },
                headToHead = uiState.headToHead,
                isLoadingHeadToHead = uiState.isLoadingHeadToHead,
                onRefreshHeadToHead = {
                    scope.launch {
                        refreshHeadToHeadComparison()
                    }
                },
                mechanicsSelectedSkill = uiState.mechanicsSelectedSkill,
                onMechanicsSelectedSkillChange = { uiState.mechanicsSelectedSkill = it },
                mechanicsCompetency = uiState.mechanicsCompetency,
                onMechanicsCompetencyChange = { uiState.mechanicsCompetency = it },
                mechanicsNote = uiState.mechanicsNote,
                onMechanicsNoteChange = { uiState.mechanicsNote = it },
                uriHandler = uriHandler,
                importStatus = uiState.importStatus,
                onImportLplCsv = {
                    scope.launch {
                        uiState.importStatus = store.importLeagueScoresFromCsv()
                    }
                },
                onOpenResetDialog = { uiState.openResetDialog = true },
                onOpenGroupDatePicker = { groupId, field, initialMs ->
                    uiState.groupDateDialogGroupID = groupId
                    uiState.groupDateDialogField = field
                    uiState.groupDatePickerInitialMs = initialMs
                    uiState.openGroupDateDialog = true
                },
            )
            PracticeScreenRouteContent(
                route = uiState.route,
                context = routeContentContext,
            )
        }
    }

    PracticeDialogHost(
        store = store,
        openNamePrompt = uiState.openNamePrompt,
        onOpenNamePromptChange = { open -> uiState.openNamePrompt = open },
        onImportStatusChange = { status -> uiState.importStatus = status },
        openQuickEntry = uiState.openQuickEntry,
        onOpenQuickEntryChange = { open -> uiState.openQuickEntry = open },
        selectedGameSlug = uiState.selectedGameSlug,
        quickPresetActivity = uiState.quickPresetActivity,
        quickEntryOrigin = uiState.quickEntryOrigin,
        quickEntryFromGameView = uiState.quickEntryFromGameView,
        onQuickSave = { slug ->
            uiState.selectedGameSlug = slug
            store.markPracticeViewedGame(slug)
            uiState.navigateTo(PracticeRoute.Game)
        },
        openGroupDateDialog = uiState.openGroupDateDialog,
        onOpenGroupDateDialogChange = { open -> uiState.openGroupDateDialog = open },
        groupDateDialogGroupID = uiState.groupDateDialogGroupID,
        groupDateDialogField = uiState.groupDateDialogField,
        groupDatePickerInitialMs = uiState.groupDatePickerInitialMs,
        openResetDialog = uiState.openResetDialog,
        onOpenResetDialogChange = { open -> uiState.openResetDialog = open },
    )
}
