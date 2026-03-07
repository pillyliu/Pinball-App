package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

internal data class PracticeRouteContentContext(
    val store: PracticeStore,
    val editingGroupID: String?,
    val onEditingGroupIDChange: (String?) -> Unit,
    val onNavigateGroupEditor: () -> Unit,
    val onBack: () -> Unit,
)

@Composable
internal fun PracticeScreenRouteContent(
    route: PracticeRoute,
    context: PracticeRouteContentContext,
    gameContext: PracticeGameRouteContext,
    homeContext: PracticeHomeRouteContext,
    groupDashboardContext: PracticeGroupDashboardContext,
    journalContext: PracticeJournalRouteContext,
    insightsContext: PracticeInsightsRouteContext,
    mechanicsContext: PracticeMechanicsRouteContext,
    settingsContext: PracticeSettingsRouteContext,
) {
    val store = context.store
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

        PracticeRoute.IfpaProfile -> {
            PracticeIfpaProfileScreen(
                playerName = store.playerName,
                ifpaPlayerID = store.ifpaPlayerID,
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
                store = store,
                editingGroupID = context.editingGroupID,
                onCancel = context.onBack,
                onSaved = context.onBack,
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
