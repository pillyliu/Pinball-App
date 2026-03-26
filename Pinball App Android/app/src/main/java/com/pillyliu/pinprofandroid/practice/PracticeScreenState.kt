package com.pillyliu.pinprofandroid.practice

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource

internal class PracticeNavigationState {
    var route by mutableStateOf(PracticeRoute.Home)
    var selectedGameSlug by mutableStateOf<String?>(null)
    var selectedPlayfieldUrls by mutableStateOf<List<String>>(emptyList())
    var selectedRulesheetSource by mutableStateOf<RulesheetRemoteSource?>(null)
    var selectedExternalRulesheetUrl by mutableStateOf<String?>(null)
    var editingGroupID by mutableStateOf<String?>(null)
    val routeHistory = mutableStateListOf<PracticeRoute>()
}

internal class PracticeJournalUiState(initialFilter: JournalFilter) {
    var filter by mutableStateOf(initialFilter)
    var selectionMode by mutableStateOf(false)
    var selectedRowIds by mutableStateOf<Set<String>>(emptySet())

    fun resetSelection() {
        selectionMode = false
        selectedRowIds = emptySet()
    }
}

internal class PracticeGameUiState {
    var subview by mutableStateOf(PracticeGameSubview.Summary)
    var summaryDraft by mutableStateOf("")
    var activeVideoId by mutableStateOf<String?>(null)
    var resumeOtherExpanded by mutableStateOf(false)
    var pickerExpanded by mutableStateOf(false)
}

internal class PracticeQuickEntryUiState {
    var presetActivity by mutableStateOf(QuickActivity.Score)
    var origin by mutableStateOf(QuickEntryOrigin.Score)
    var fromGameView by mutableStateOf(false)
    var isOpen by mutableStateOf(false)
}

internal class PracticePresentationState {
    var openResetDialog by mutableStateOf(false)
    var openClearImportedLeagueScoresDialog by mutableStateOf(false)
    var openGroupDateDialog by mutableStateOf(false)
    var groupDateDialogGroupID by mutableStateOf<String?>(null)
    var groupDateDialogField by mutableStateOf(GroupDashboardDateField.Start)
    var groupDatePickerInitialMs by mutableStateOf<Long?>(null)
    var openNamePrompt by mutableStateOf(false)
    var importStatus by mutableStateOf("")
}

internal class PracticeInsightsUiState {
    var opponentName by mutableStateOf("")
    var opponentOptions by mutableStateOf<List<String>>(emptyList())
    var headToHead by mutableStateOf<HeadToHeadComparison?>(null)
    var isLoadingHeadToHead by mutableStateOf(false)
}

internal class PracticeMechanicsUiState {
    var selectedSkill by mutableStateOf("")
    var competency by mutableFloatStateOf(3f)
    var note by mutableStateOf("")
}

internal class PracticeScreenState(initialJournalFilter: JournalFilter) {
    val navigation = PracticeNavigationState()
    val journal = PracticeJournalUiState(initialJournalFilter)
    val game = PracticeGameUiState()
    val quickEntry = PracticeQuickEntryUiState()
    val presentation = PracticePresentationState()
    val insights = PracticeInsightsUiState()
    val mechanics = PracticeMechanicsUiState()

    fun openQuickEntryFor(
        activity: QuickActivity,
        origin: QuickEntryOrigin = quickEntry.origin,
        fromGameView: Boolean = false,
    ) {
        quickEntry.presetActivity = activity
        quickEntry.origin = origin
        quickEntry.fromGameView = fromGameView
        quickEntry.isOpen = true
    }

    fun navigateTo(target: PracticeRoute) {
        if (target == PracticeRoute.Game) {
            game.subview = PracticeGameSubview.Summary
        }
        if (target != PracticeRoute.Journal) {
            journal.resetSelection()
        }
        if (target == navigation.route) return
        navigation.routeHistory.add(navigation.route)
        navigation.route = target
    }

    fun resetToHome() {
        navigation.routeHistory.clear()
        journal.resetSelection()
        navigation.selectedRulesheetSource = null
        navigation.selectedExternalRulesheetUrl = null
        navigation.route = PracticeRoute.Home
    }

    fun goBack() {
        navigation.route = if (navigation.routeHistory.isNotEmpty()) {
            navigation.routeHistory.removeAt(navigation.routeHistory.lastIndex)
        } else {
            PracticeRoute.Home
        }
        if (navigation.route != PracticeRoute.Journal) {
            journal.resetSelection()
        }
    }
}

@Composable
internal fun rememberPracticeScreenState(prefs: SharedPreferences): PracticeScreenState {
    val initialJournalFilter = remember(prefs) {
        JournalFilter.entries.firstOrNull {
            it.name == prefs.getString(KEY_PRACTICE_JOURNAL_FILTER, JournalFilter.All.name)
        } ?: JournalFilter.All
    }
    return remember { PracticeScreenState(initialJournalFilter) }
}
