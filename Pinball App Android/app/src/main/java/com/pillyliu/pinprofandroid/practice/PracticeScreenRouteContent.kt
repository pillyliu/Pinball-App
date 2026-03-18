package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import com.pillyliu.pinprofandroid.library.PinballGame

@Composable
internal fun PracticeScreenRouteContent(
    route: PracticeRoute,
    gameContext: PracticeGameRouteContext,
    searchGames: List<PinballGame>,
    isLoadingSearchGames: Boolean,
    onOpenSearchGame: (String) -> Unit,
    homeContext: PracticeHomeRouteContext,
    ifpaProfileContext: PracticeIfpaProfileContext,
    groupDashboardContext: PracticeGroupDashboardContext,
    groupEditorContext: PracticeGroupEditorRouteContext,
    journalContext: PracticeJournalRouteContext,
    insightsContext: PracticeInsightsRouteContext,
    mechanicsContext: PracticeMechanicsRouteContext,
    settingsContext: PracticeSettingsRouteContext,
) {
    when (route) {
        PracticeRoute.Home -> {
            PracticeHomeSection(
                store = homeContext.store,
                resumeOtherExpanded = homeContext.resumeOtherExpanded,
                onResumeOtherExpandedChange = homeContext.onResumeOtherExpandedChange,
                librarySources = homeContext.librarySources,
                selectedLibrarySourceId = homeContext.selectedLibrarySourceId,
                onSelectLibrarySourceId = homeContext.onSelectLibrarySourceId,
                onOpenGame = homeContext.onOpenGame,
                onOpenQuickEntry = homeContext.onOpenQuickEntry,
                onOpenGroupDashboard = homeContext.onOpenGroupDashboard,
                onOpenJournal = homeContext.onOpenJournal,
                onOpenInsights = homeContext.onOpenInsights,
                onOpenMechanics = homeContext.onOpenMechanics,
            )
        }

        PracticeRoute.Search -> {
            PracticeGameSearchSheet(
                games = searchGames,
                isLoadingGames = isLoadingSearchGames,
                onOpenGame = onOpenSearchGame,
            )
        }

        PracticeRoute.IfpaProfile -> {
            PracticeIfpaProfileScreen(
                playerName = ifpaProfileContext.playerName,
                ifpaPlayerID = ifpaProfileContext.ifpaPlayerID,
            )
        }

        PracticeRoute.Game -> {
            PracticeGameSection(
                store = gameContext.store,
                game = gameContext.selectedGame,
                gameSubview = gameContext.gameSubview,
                onGameSubviewChange = gameContext.onGameSubviewChange,
                gameSummaryDraft = gameContext.gameSummaryDraft,
                onGameSummaryDraftChange = gameContext.onGameSummaryDraftChange,
                activeGameVideoId = gameContext.activeGameVideoId,
                onActiveGameVideoIdChange = gameContext.onActiveGameVideoIdChange,
                onOpenQuickEntry = gameContext.onOpenQuickEntry,
                onOpenRulesheet = gameContext.onOpenRulesheet,
                onOpenExternalRulesheet = gameContext.onOpenExternalRulesheet,
                onOpenPlayfield = gameContext.onOpenPlayfield,
            )
        }

        PracticeRoute.GroupDashboard -> {
            PracticeGroupDashboardSection(
                store = groupDashboardContext.store,
                onCreateGroup = groupDashboardContext.onCreateGroup,
                onEditSelectedGroup = groupDashboardContext.onEditSelectedGroup,
                onOpenGroupDatePicker = groupDashboardContext.onOpenGroupDatePicker,
                onOpenGame = groupDashboardContext.onOpenGame,
            )
        }

        PracticeRoute.GroupEditor -> {
            GroupEditorScreen(
                store = groupEditorContext.store,
                editingGroupID = groupEditorContext.editingGroupID,
                onCancel = groupEditorContext.onBack,
                onSaved = groupEditorContext.onBack,
            )
        }

        PracticeRoute.Journal -> {
            PracticeJournalSection(
                store = journalContext.store,
                journalFilter = journalContext.journalFilter,
                onJournalFilterChange = journalContext.onJournalFilterChange,
                isSelectionMode = journalContext.journalSelectionMode,
                selectedRowIds = journalContext.selectedJournalRowIds,
                onSelectionModeChange = journalContext.onJournalSelectionModeChange,
                onSelectedRowIdsChange = journalContext.onSelectedJournalRowIdsChange,
                onOpenGame = journalContext.onOpenGame,
                modifier = journalContext.timelineModifier,
            )
        }

        PracticeRoute.Insights -> {
            PracticeInsightsSection(
                store = insightsContext.store,
                selectedGameSlug = insightsContext.selectedGameSlug,
                onSelectGameSlug = insightsContext.onSelectGameSlug,
                insightsOpponentName = insightsContext.insightsOpponentName,
                insightsOpponentOptions = insightsContext.insightsOpponentOptions,
                onInsightsOpponentNameChange = insightsContext.onInsightsOpponentNameChange,
                headToHead = insightsContext.headToHead,
                isLoadingHeadToHead = insightsContext.isLoadingHeadToHead,
                onRefreshHeadToHead = insightsContext.onRefreshHeadToHead,
            )
        }

        PracticeRoute.Mechanics -> {
            PracticeMechanicsSection(
                store = mechanicsContext.store,
                mechanicsSelectedSkill = mechanicsContext.mechanicsSelectedSkill,
                onMechanicsSelectedSkillChange = mechanicsContext.onMechanicsSelectedSkillChange,
                mechanicsCompetency = mechanicsContext.mechanicsCompetency,
                onMechanicsCompetencyChange = mechanicsContext.onMechanicsCompetencyChange,
                mechanicsNote = mechanicsContext.mechanicsNote,
                onMechanicsNoteChange = mechanicsContext.onMechanicsNoteChange,
                onOpenDeadFlipTutorials = mechanicsContext.onOpenDeadFlipTutorials,
            )
        }

        PracticeRoute.Settings -> {
            PracticeSettingsSection(
                store = settingsContext.store,
                importStatus = settingsContext.importStatus,
                onImportLplCsv = settingsContext.onImportLplCsv,
                onOpenResetDialog = settingsContext.onOpenResetDialog,
            )
        }

        else -> Unit
    }
}
