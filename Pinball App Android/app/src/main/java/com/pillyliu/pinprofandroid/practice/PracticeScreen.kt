package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.PlayfieldScreen
import com.pillyliu.pinprofandroid.library.RulesheetScreen
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.ExternalRulesheetWebScreen
import com.pillyliu.pinprofandroid.library.hasLocalRulesheetResource
import com.pillyliu.pinprofandroid.library.hasRulesheetResource
import com.pillyliu.pinprofandroid.library.resolve
import com.pillyliu.pinprofandroid.library.rulesheetPathCandidates
import com.pillyliu.pinprofandroid.library.fullscreenPlayfieldCandidates
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay
import com.pillyliu.pinprofandroid.ui.AppRouteScreen

internal enum class PracticeRoute {
    Home,
    Search,
    IfpaProfile,
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
    Study("Study"),
    Log("Log"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PracticeScreen(
    contentPadding: PaddingValues,
    externalStore: PracticeStore? = null,
) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val store = externalStore ?: remember(context.applicationContext) { PracticeStore(context.applicationContext) }
    val prefs = remember { practiceSharedPreferences(context) }
    val scope = rememberCoroutineScope()
    val uiState = rememberPracticeScreenState(prefs)
    val sourceVersion by LibrarySourceEvents.version.collectAsState()

    val selectedGame = uiState.navigation.selectedGameSlug?.let(store::gameForAnyID)
    val actions = PracticeScreenActions(
        store = store,
        uiState = uiState,
        scope = scope,
        uriHandler = uriHandler,
        selectedGame = selectedGame,
    )
    PracticeLifecycleHost(
        context = PracticeLifecycleContext(
            store = store,
            uiState = uiState,
            prefs = prefs,
            sourceVersion = sourceVersion,
            onRefreshHeadToHead = actions::refreshHeadToHeadComparison,
        )
    )

    LaunchedEffect(uiState.navigation.route) {
        if (uiState.navigation.route == PracticeRoute.Search) {
            store.ensureSearchCatalogGamesLoaded()
        }
    }

    when (uiState.navigation.route) {
        PracticeRoute.Rulesheet -> {
            val game = selectedGame
            if (game != null) {
                if (!uiState.navigation.selectedExternalRulesheetUrl.isNullOrBlank()) {
                    ExternalRulesheetWebScreen(
                        contentPadding = contentPadding,
                        title = game.name,
                        url = uiState.navigation.selectedExternalRulesheetUrl!!,
                        onBack = uiState::goBack,
                    )
                } else {
                    RulesheetScreen(
                        contentPadding = contentPadding,
                        gameId = game.practiceKey,
                        pathCandidates = game.rulesheetPathCandidates.distinct(),
                        externalSource = uiState.navigation.selectedRulesheetSource,
                        onBack = uiState::goBack,
                        practiceSavedRatio = store.rulesheetSavedProgress(game.practiceKey),
                        onSavePracticeRatio = { ratio -> store.saveRulesheetProgress(game.practiceKey, ratio) },
                    )
                }
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
                    imageUrls = uiState.navigation.selectedPlayfieldUrls.ifEmpty { game.fullscreenPlayfieldCandidates() },
                    onBack = uiState::goBack,
                )
            } else {
                uiState.resetToHome()
            }
            return
        }

        else -> Unit
    }

    val showsFullscreenBootstrapOverlay = store.isBootstrapping &&
        (!store.hasRestoredHomeBootstrapSnapshot || uiState.navigation.route != PracticeRoute.Home)
    val showsHomeBootstrapShield = store.isBootstrapping &&
        store.hasRestoredHomeBootstrapSnapshot &&
        uiState.navigation.route == PracticeRoute.Home

    AppRouteScreen(
        contentPadding = contentPadding,
        canGoBack = uiState.navigation.route != PracticeRoute.Home &&
            uiState.navigation.route != PracticeRoute.Rulesheet &&
            uiState.navigation.route != PracticeRoute.Playfield,
        onBack = uiState::goBack,
    ) {
        if (showsFullscreenBootstrapOverlay) {
            AppFullscreenStatusOverlay(
                text = "Loading practice data…",
                showsProgress = true,
            )
        } else {
            Box(modifier = Modifier.fillMaxSize()) {
                val topBarGamePickerContext = PracticeTopBarGamePickerContext(
                    selectedGameName = selectedGame?.let { practiceDisplayTitleForKey(it.practiceKey, store.practiceLookupGamesForDisplay()) ?: it.name },
                    games = store.games,
                    librarySources = store.librarySources,
                    selectedLibrarySourceId = store.defaultPracticeSourceId,
                    expanded = uiState.game.pickerExpanded,
                    onExpandedChange = { expanded -> uiState.game.pickerExpanded = expanded },
                    onLibrarySourceSelected = actions::selectLibrarySource,
                    onGameSelected = { selectionKey ->
                        actions.selectPracticeGame(selectionKey)
                    },
                )
                val bodyModifier = if (
                    uiState.navigation.route == PracticeRoute.Journal ||
                    uiState.navigation.route == PracticeRoute.Search
                ) {
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
                        route = uiState.navigation.route,
                        playerName = store.playerName,
                        showsGenericGreeting = showsHomeBootstrapShield,
                        editingGroupID = uiState.navigation.editingGroupID,
                        gamePickerContext = topBarGamePickerContext,
                        onBack = uiState::goBack,
                        onOpenSearch = if (uiState.navigation.route == PracticeRoute.Home) {
                            { actions.navigateTo(PracticeRoute.Search) }
                        } else {
                            null
                        },
                        onOpenSettings = { actions.navigateTo(PracticeRoute.Settings) },
                        onOpenIfpaProfile = { actions.navigateTo(PracticeRoute.IfpaProfile) },
                        isJournalSelectionMode = uiState.journal.selectionMode,
                        onToggleJournalSelectionMode = if (uiState.navigation.route == PracticeRoute.Journal) {
                            actions::toggleJournalSelectionMode
                        } else null,
                    )

                    val homeRouteContext = PracticeHomeRouteContext(
                        store = store,
                        resumeOtherExpanded = uiState.game.resumeOtherExpanded,
                        onResumeOtherExpandedChange = { expanded -> uiState.game.resumeOtherExpanded = expanded },
                        librarySources = store.librarySources,
                        selectedLibrarySourceId = store.defaultPracticeSourceId,
                        onSelectLibrarySourceId = actions::selectLibrarySource,
                        onOpenGame = actions::openPracticeGame,
                        onOpenQuickEntry = { activity, origin ->
                            actions.openQuickEntry(activity, origin, false)
                        },
                        onOpenGroupDashboard = { actions.navigateTo(PracticeRoute.GroupDashboard) },
                        onOpenJournal = { actions.navigateTo(PracticeRoute.Journal) },
                        onOpenInsights = { actions.navigateTo(PracticeRoute.Insights) },
                        onOpenMechanics = { actions.navigateTo(PracticeRoute.Mechanics) },
                    )
                    val ifpaProfileContext = PracticeIfpaProfileContext(
                        playerName = store.playerName,
                        ifpaPlayerID = store.ifpaPlayerID,
                        prpaPlayerID = store.prpaPlayerID,
                    )
                    val groupDashboardContext = PracticeGroupDashboardContext(
                        store = store,
                        onCreateGroup = actions::createGroup,
                        onEditSelectedGroup = actions::editGroup,
                        onOpenGroupDatePicker = actions::openGroupDatePicker,
                        onOpenGame = actions::openPracticeGame,
                    )
                    val groupEditorRouteContext = PracticeGroupEditorRouteContext(
                        store = store,
                        editingGroupID = uiState.navigation.editingGroupID,
                        onBack = uiState::goBack,
                    )
                    val insightsRouteContext = PracticeInsightsRouteContext(
                        store = store,
                        selectedGameSlug = uiState.navigation.selectedGameSlug,
                        onSelectGameSlug = { uiState.navigation.selectedGameSlug = it },
                        insightsOpponentName = uiState.insights.opponentName,
                        insightsOpponentOptions = uiState.insights.opponentOptions,
                        onInsightsOpponentNameChange = actions::selectInsightsOpponent,
                        headToHead = uiState.insights.headToHead,
                        isLoadingHeadToHead = uiState.insights.isLoadingHeadToHead,
                        onRefreshHeadToHead = actions::refreshHeadToHead,
                    )
                    val mechanicsRouteContext = PracticeMechanicsRouteContext(
                        store = store,
                        mechanicsSelectedSkill = uiState.mechanics.selectedSkill,
                        onMechanicsSelectedSkillChange = { uiState.mechanics.selectedSkill = it },
                        mechanicsCompetency = uiState.mechanics.competency,
                        onMechanicsCompetencyChange = { uiState.mechanics.competency = it },
                        mechanicsNote = uiState.mechanics.note,
                        onMechanicsNoteChange = { uiState.mechanics.note = it },
                        onOpenDeadFlipTutorials = actions::openDeadFlipTutorials,
                    )
                    val settingsRouteContext = PracticeSettingsRouteContext(
                        store = store,
                        importStatus = uiState.presentation.importStatus,
                        importedLeagueScoreCount = store.importedLeagueScoreCount,
                        onImportLplCsv = actions::importLplCsv,
                        onOpenClearImportedLeagueScoresDialog = actions::openClearImportedLeagueScoresDialog,
                        onOpenResetDialog = actions::openResetDialog,
                    )
                    val journalRouteContext = PracticeJournalRouteContext(
                        store = store,
                        journalFilter = uiState.journal.filter,
                        onJournalFilterChange = { uiState.journal.filter = it },
                        journalSelectionMode = uiState.journal.selectionMode,
                        selectedJournalRowIds = uiState.journal.selectedRowIds,
                        onJournalSelectionModeChange = { uiState.journal.selectionMode = it },
                        onSelectedJournalRowIdsChange = { uiState.journal.selectedRowIds = it },
                        onOpenGame = actions::openPracticeGame,
                        timelineModifier = Modifier.fillMaxSize(),
                    )
                    val gameRouteContext = PracticeGameRouteContext(
                        store = store,
                        selectedGame = selectedGame,
                        gameSubview = uiState.game.subview,
                        onGameSubviewChange = { updated -> uiState.game.subview = updated },
                        gameSummaryDraft = uiState.game.summaryDraft,
                        onGameSummaryDraftChange = { updated -> uiState.game.summaryDraft = updated },
                        activeGameVideoId = uiState.game.activeVideoId,
                        onActiveGameVideoIdChange = { updated -> uiState.game.activeVideoId = updated },
                        onOpenQuickEntry = { activity, origin ->
                            actions.openQuickEntry(activity, origin, true)
                        },
                        onOpenRulesheet = actions::openRulesheet,
                        onOpenExternalRulesheet = actions::openExternalRulesheet,
                        onOpenPlayfield = actions::openPlayfield,
                    )
                    PracticeScreenRouteContent(
                        route = uiState.navigation.route,
                        gameContext = gameRouteContext,
                        searchGames = store.searchCatalogGames,
                        isLoadingSearchGames = store.isLoadingSearchCatalog,
                        onOpenSearchGame = actions::openPracticeGame,
                        homeContext = homeRouteContext,
                        ifpaProfileContext = ifpaProfileContext,
                        groupDashboardContext = groupDashboardContext,
                        groupEditorContext = groupEditorRouteContext,
                        journalContext = journalRouteContext,
                        insightsContext = insightsRouteContext,
                        mechanicsContext = mechanicsRouteContext,
                        settingsContext = settingsRouteContext,
                    )
                }

                if (showsHomeBootstrapShield) {
                    PracticeBootstrapInteractionShield()
                }
            }
        }
    }

    PracticeDialogHost(
        context = PracticePresentationContext(
            store = store,
            openNamePrompt = uiState.presentation.openNamePrompt,
            onOpenNamePromptChange = { open -> uiState.presentation.openNamePrompt = open },
            onImportStatusChange = { status -> uiState.presentation.importStatus = status },
            openQuickEntry = uiState.quickEntry.isOpen,
            onOpenQuickEntryChange = { open -> uiState.quickEntry.isOpen = open },
            selectedGameSlug = uiState.navigation.selectedGameSlug,
            quickPresetActivity = uiState.quickEntry.presetActivity,
            quickEntryOrigin = uiState.quickEntry.origin,
            quickEntryFromGameView = uiState.quickEntry.fromGameView,
            onQuickSave = actions::openPracticeGame,
            openGroupDateDialog = uiState.presentation.openGroupDateDialog,
            onOpenGroupDateDialogChange = { open -> uiState.presentation.openGroupDateDialog = open },
            groupDateDialogGroupID = uiState.presentation.groupDateDialogGroupID,
            groupDateDialogField = uiState.presentation.groupDateDialogField,
            groupDatePickerInitialMs = uiState.presentation.groupDatePickerInitialMs,
            openResetDialog = uiState.presentation.openResetDialog,
            onOpenResetDialogChange = { open -> uiState.presentation.openResetDialog = open },
            openClearImportedLeagueScoresDialog = uiState.presentation.openClearImportedLeagueScoresDialog,
            onOpenClearImportedLeagueScoresDialogChange = { open ->
                uiState.presentation.openClearImportedLeagueScoresDialog = open
            },
        ),
    )
}

@Composable
private fun PracticeBootstrapInteractionShield() {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = {},
            ),
    ) {
        AppFullscreenStatusOverlay(
            text = "Refreshing practice data…",
            showsProgress = true,
        )
    }
}
