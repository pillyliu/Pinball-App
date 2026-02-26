package com.pillyliu.pinballandroid.practice

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.UriHandler
import com.pillyliu.pinballandroid.library.LibrarySource

internal data class PracticeRouteContentContext(
    val store: PracticeStore,
    val selectedGame: com.pillyliu.pinballandroid.library.PinballGame?,
    val selectedGameSlug: String?,
    val onSelectGameSlug: (String?) -> Unit,
    val gameSubview: PracticeGameSubview,
    val onGameSubviewChange: (PracticeGameSubview) -> Unit,
    val gameSummaryDraft: String,
    val onGameSummaryDraftChange: (String) -> Unit,
    val activeGameVideoId: String?,
    val onActiveGameVideoIdChange: (String?) -> Unit,
    val resumeOtherExpanded: Boolean,
    val onResumeOtherExpandedChange: (Boolean) -> Unit,
    val librarySources: List<LibrarySource>,
    val selectedLibrarySourceId: String?,
    val onSelectLibrarySourceId: (String) -> Unit,
    val onOpenQuickEntry: (QuickActivity, QuickEntryOrigin, Boolean) -> Unit,
    val onOpenGroupDashboard: () -> Unit,
    val onOpenJournal: () -> Unit,
    val onOpenInsights: () -> Unit,
    val onOpenMechanics: () -> Unit,
    val onOpenGameRoute: () -> Unit,
    val onOpenRulesheet: () -> Unit,
    val onOpenPlayfield: (List<String>) -> Unit,
    val editingGroupID: String?,
    val onEditingGroupIDChange: (String?) -> Unit,
    val onNavigateGroupEditor: () -> Unit,
    val onBack: () -> Unit,
    val journalFilter: JournalFilter,
    val onJournalFilterChange: (JournalFilter) -> Unit,
    val journalSelectionMode: Boolean,
    val selectedJournalRowIds: Set<String>,
    val onJournalSelectionModeChange: (Boolean) -> Unit,
    val onSelectedJournalRowIdsChange: (Set<String>) -> Unit,
    val journalTimelineModifier: Modifier,
    val insightsOpponentName: String,
    val insightsOpponentOptions: List<String>,
    val onInsightsOpponentNameChange: (String) -> Unit,
    val headToHead: HeadToHeadComparison?,
    val isLoadingHeadToHead: Boolean,
    val onRefreshHeadToHead: () -> Unit,
    val mechanicsSelectedSkill: String,
    val onMechanicsSelectedSkillChange: (String) -> Unit,
    val mechanicsCompetency: Float,
    val onMechanicsCompetencyChange: (Float) -> Unit,
    val mechanicsNote: String,
    val onMechanicsNoteChange: (String) -> Unit,
    val uriHandler: UriHandler,
    val importStatus: String,
    val onImportLplCsv: () -> Unit,
    val onOpenResetDialog: () -> Unit,
    val onOpenGroupDatePicker: (String?, GroupDashboardDateField, Long?) -> Unit,
)

@Composable
internal fun PracticeScreenRouteContent(
    route: PracticeRoute,
    context: PracticeRouteContentContext,
) {
    val store = context.store
    when (route) {
        PracticeRoute.Home -> {
            PracticeHomeSection(
                store = store,
                resumeOtherExpanded = context.resumeOtherExpanded,
                onResumeOtherExpandedChange = context.onResumeOtherExpandedChange,
                librarySources = context.librarySources,
                selectedLibrarySourceId = context.selectedLibrarySourceId,
                onSelectLibrarySourceId = context.onSelectLibrarySourceId,
                onOpenGame = { slug ->
                    context.onSelectGameSlug(slug)
                    store.markPracticeViewedGame(slug)
                    context.onOpenGameRoute()
                },
                onOpenQuickEntry = { activity, origin ->
                    context.onOpenQuickEntry(activity, origin, false)
                },
                onOpenGroupDashboard = context.onOpenGroupDashboard,
                onOpenJournal = context.onOpenJournal,
                onOpenInsights = context.onOpenInsights,
                onOpenMechanics = context.onOpenMechanics,
            )
        }

        PracticeRoute.Game -> {
            PracticeGameSection(
                store = store,
                game = context.selectedGame,
                gameSubview = context.gameSubview,
                onGameSubviewChange = context.onGameSubviewChange,
                gameSummaryDraft = context.gameSummaryDraft,
                onGameSummaryDraftChange = context.onGameSummaryDraftChange,
                activeGameVideoId = context.activeGameVideoId,
                onActiveGameVideoIdChange = context.onActiveGameVideoIdChange,
                onOpenQuickEntry = { activity, origin ->
                    context.onOpenQuickEntry(activity, origin, true)
                },
                onOpenRulesheet = context.onOpenRulesheet,
                onOpenPlayfield = context.onOpenPlayfield,
            )
        }

        PracticeRoute.GroupDashboard -> {
            PracticeGroupDashboardSection(
                store = store,
                onCreateGroup = {
                    context.onEditingGroupIDChange(null)
                    context.onNavigateGroupEditor()
                },
                onEditSelectedGroup = { selectedId ->
                    context.onEditingGroupIDChange(selectedId)
                    context.onNavigateGroupEditor()
                },
                onOpenGroupDatePicker = context.onOpenGroupDatePicker,
                onOpenGame = { slug ->
                    context.onSelectGameSlug(slug)
                    store.markPracticeViewedGame(slug)
                    context.onOpenGameRoute()
                },
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
                store = store,
                journalFilter = context.journalFilter,
                onJournalFilterChange = context.onJournalFilterChange,
                isSelectionMode = context.journalSelectionMode,
                selectedRowIds = context.selectedJournalRowIds,
                onSelectionModeChange = context.onJournalSelectionModeChange,
                onSelectedRowIdsChange = context.onSelectedJournalRowIdsChange,
                onOpenGame = { slug ->
                    context.onSelectGameSlug(slug)
                    store.markPracticeViewedGame(slug)
                    context.onOpenGameRoute()
                },
                modifier = context.journalTimelineModifier,
            )
        }

        PracticeRoute.Insights -> {
            PracticeInsightsSection(
                store = store,
                selectedGameSlug = context.selectedGameSlug,
                onSelectGameSlug = context.onSelectGameSlug,
                insightsOpponentName = context.insightsOpponentName,
                insightsOpponentOptions = context.insightsOpponentOptions,
                onInsightsOpponentNameChange = context.onInsightsOpponentNameChange,
                headToHead = context.headToHead,
                isLoadingHeadToHead = context.isLoadingHeadToHead,
                onRefreshHeadToHead = context.onRefreshHeadToHead,
            )
        }

        PracticeRoute.Mechanics -> {
            PracticeMechanicsSection(
                store = store,
                selectedGameSlug = context.selectedGameSlug,
                mechanicsSelectedSkill = context.mechanicsSelectedSkill,
                onMechanicsSelectedSkillChange = context.onMechanicsSelectedSkillChange,
                mechanicsCompetency = context.mechanicsCompetency,
                onMechanicsCompetencyChange = context.onMechanicsCompetencyChange,
                mechanicsNote = context.mechanicsNote,
                onMechanicsNoteChange = context.onMechanicsNoteChange,
                onOpenDeadFlipTutorials = { context.uriHandler.openUri("https://www.deadflip.com/tutorials") },
            )
        }

        PracticeRoute.Settings -> {
            PracticeSettingsSection(
                store = store,
                importStatus = context.importStatus,
                onImportLplCsv = context.onImportLplCsv,
                onOpenResetDialog = context.onOpenResetDialog,
            )
        }

        else -> Unit
    }
}
