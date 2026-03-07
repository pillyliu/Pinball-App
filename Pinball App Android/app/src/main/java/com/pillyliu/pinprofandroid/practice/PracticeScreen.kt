package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.PlayfieldScreen
import com.pillyliu.pinprofandroid.library.RulesheetScreen
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.ExternalRulesheetWebScreen
import com.pillyliu.pinprofandroid.library.hasRulesheetResource
import com.pillyliu.pinprofandroid.library.resolve
import com.pillyliu.pinprofandroid.library.rulesheetPathCandidates
import com.pillyliu.pinprofandroid.library.fullscreenPlayfieldCandidates
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack

internal enum class PracticeRoute {
    Home,
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
    Log("Log"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PracticeScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val store = remember { PracticeStore(context) }
    val prefs = remember { practiceSharedPreferences(context) }
    val scope = rememberCoroutineScope()
    val uiState = rememberPracticeScreenState(prefs)
    val sourceVersion by LibrarySourceEvents.version.collectAsState()

    val gameLookupPool = if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
    val selectedGame = findGameByPracticeLookupKey(gameLookupPool, uiState.selectedGameSlug)
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

    when (uiState.route) {
        PracticeRoute.Rulesheet -> {
            val game = selectedGame
            if (game != null) {
                if (!uiState.selectedExternalRulesheetUrl.isNullOrBlank()) {
                    ExternalRulesheetWebScreen(
                        contentPadding = contentPadding,
                        title = game.name,
                        url = uiState.selectedExternalRulesheetUrl!!,
                        onBack = uiState::goBack,
                    )
                } else {
                    RulesheetScreen(
                        contentPadding = contentPadding,
                        slug = game.practiceKey,
                        remoteCandidates = game.rulesheetPathCandidates.mapNotNull { game.resolve(it) },
                        externalSource = uiState.selectedRulesheetSource,
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
        val topBarGamePickerContext = PracticeTopBarGamePickerContext(
            selectedGameName = selectedGame?.name,
            games = store.games,
            librarySources = store.librarySources,
            selectedLibrarySourceId = store.defaultPracticeSourceId,
            expanded = uiState.gamePickerExpanded,
            onExpandedChange = { expanded -> uiState.gamePickerExpanded = expanded },
            onLibrarySourceSelected = actions::selectLibrarySource,
            onGameSelected = { game ->
                actions.selectPracticeGame(game.practiceKey)
            },
        )
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
                gamePickerContext = topBarGamePickerContext,
                onBack = uiState::goBack,
                onOpenSettings = { actions.navigateTo(PracticeRoute.Settings) },
                onOpenIfpaProfile = { actions.navigateTo(PracticeRoute.IfpaProfile) },
                isJournalSelectionMode = uiState.journalSelectionMode,
                onToggleJournalSelectionMode = if (uiState.route == PracticeRoute.Journal) {
                    actions::toggleJournalSelectionMode
                } else null,
            )

            val homeRouteContext = PracticeHomeRouteContext(
                store = store,
                resumeOtherExpanded = uiState.resumeOtherExpanded,
                onResumeOtherExpandedChange = { expanded -> uiState.resumeOtherExpanded = expanded },
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
                editingGroupID = uiState.editingGroupID,
                onBack = uiState::goBack,
            )
            val insightsRouteContext = PracticeInsightsRouteContext(
                store = store,
                selectedGameSlug = uiState.selectedGameSlug,
                onSelectGameSlug = { uiState.selectedGameSlug = it },
                insightsOpponentName = uiState.insightsOpponentName,
                insightsOpponentOptions = uiState.insightsOpponentOptions,
                onInsightsOpponentNameChange = actions::selectInsightsOpponent,
                headToHead = uiState.headToHead,
                isLoadingHeadToHead = uiState.isLoadingHeadToHead,
                onRefreshHeadToHead = actions::refreshHeadToHead,
            )
            val mechanicsRouteContext = PracticeMechanicsRouteContext(
                store = store,
                mechanicsSelectedSkill = uiState.mechanicsSelectedSkill,
                onMechanicsSelectedSkillChange = { uiState.mechanicsSelectedSkill = it },
                mechanicsCompetency = uiState.mechanicsCompetency,
                onMechanicsCompetencyChange = { uiState.mechanicsCompetency = it },
                mechanicsNote = uiState.mechanicsNote,
                onMechanicsNoteChange = { uiState.mechanicsNote = it },
                onOpenDeadFlipTutorials = actions::openDeadFlipTutorials,
            )
            val settingsRouteContext = PracticeSettingsRouteContext(
                store = store,
                importStatus = uiState.importStatus,
                onImportLplCsv = actions::importLplCsv,
                onOpenResetDialog = actions::openResetDialog,
            )
            val journalRouteContext = PracticeJournalRouteContext(
                store = store,
                journalFilter = uiState.journalFilter,
                onJournalFilterChange = { uiState.journalFilter = it },
                journalSelectionMode = uiState.journalSelectionMode,
                selectedJournalRowIds = uiState.selectedJournalRowIds,
                onJournalSelectionModeChange = { uiState.journalSelectionMode = it },
                onSelectedJournalRowIdsChange = { uiState.selectedJournalRowIds = it },
                onOpenGame = actions::openPracticeGame,
                timelineModifier = Modifier.fillMaxSize(),
            )
            val gameRouteContext = PracticeGameRouteContext(
                store = store,
                selectedGame = selectedGame,
                gameSubview = uiState.gameSubview,
                onGameSubviewChange = { updated -> uiState.gameSubview = updated },
                gameSummaryDraft = uiState.gameSummaryDraft,
                onGameSummaryDraftChange = { updated -> uiState.gameSummaryDraft = updated },
                activeGameVideoId = uiState.activeGameVideoId,
                onActiveGameVideoIdChange = { updated -> uiState.activeGameVideoId = updated },
                onOpenQuickEntry = { activity, origin ->
                    actions.openQuickEntry(activity, origin, true)
                },
                onOpenRulesheet = actions::openRulesheet,
                onOpenExternalRulesheet = actions::openExternalRulesheet,
                onOpenPlayfield = actions::openPlayfield,
            )
            PracticeScreenRouteContent(
                route = uiState.route,
                gameContext = gameRouteContext,
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
    }

    PracticeDialogHost(
        context = PracticePresentationContext(
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
            onQuickSave = actions::openPracticeGame,
            openGroupDateDialog = uiState.openGroupDateDialog,
            onOpenGroupDateDialogChange = { open -> uiState.openGroupDateDialog = open },
            groupDateDialogGroupID = uiState.groupDateDialogGroupID,
            groupDateDialogField = uiState.groupDateDialogField,
            groupDatePickerInitialMs = uiState.groupDatePickerInitialMs,
            openResetDialog = uiState.openResetDialog,
            onOpenResetDialogChange = { open -> uiState.openResetDialog = open },
        ),
    )
}
