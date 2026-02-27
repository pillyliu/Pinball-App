package com.pillyliu.pinballandroid.practice

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

internal class PracticeScreenState(initialJournalFilter: JournalFilter) {
    var route by mutableStateOf(PracticeRoute.Home)
    var selectedGameSlug by mutableStateOf<String?>(null)
    var selectedPlayfieldUrls by mutableStateOf<List<String>>(emptyList())
    var journalFilter by mutableStateOf(initialJournalFilter)
    var journalSelectionMode by mutableStateOf(false)
    var selectedJournalRowIds by mutableStateOf<Set<String>>(emptySet())
    var gameSubview by mutableStateOf(PracticeGameSubview.Summary)
    var quickPresetActivity by mutableStateOf(QuickActivity.Score)
    var quickEntryOrigin by mutableStateOf(QuickEntryOrigin.Score)
    var quickEntryFromGameView by mutableStateOf(false)
    var editingGroupID by mutableStateOf<String?>(null)
    var openQuickEntry by mutableStateOf(false)
    var openResetDialog by mutableStateOf(false)
    var openGroupDateDialog by mutableStateOf(false)
    var groupDateDialogGroupID by mutableStateOf<String?>(null)
    var groupDateDialogField by mutableStateOf(GroupDashboardDateField.Start)
    var groupDatePickerInitialMs by mutableStateOf<Long?>(null)
    var openNamePrompt by mutableStateOf(false)
    var importStatus by mutableStateOf("")
    var resumeOtherExpanded by mutableStateOf(false)
    var gamePickerExpanded by mutableStateOf(false)
    var insightsOpponentName by mutableStateOf("")
    var insightsOpponentOptions by mutableStateOf<List<String>>(emptyList())
    var headToHead by mutableStateOf<HeadToHeadComparison?>(null)
    var isLoadingHeadToHead by mutableStateOf(false)
    var mechanicsSelectedSkill by mutableStateOf("")
    var mechanicsCompetency by mutableFloatStateOf(3f)
    var mechanicsNote by mutableStateOf("")
    var gameSummaryDraft by mutableStateOf("")
    var activeGameVideoId by mutableStateOf<String?>(null)
    val routeHistory = mutableStateListOf<PracticeRoute>()

    fun openQuickEntryFor(
        activity: QuickActivity,
        origin: QuickEntryOrigin = quickEntryOrigin,
        fromGameView: Boolean = false,
    ) {
        quickPresetActivity = activity
        quickEntryOrigin = origin
        quickEntryFromGameView = fromGameView
        openQuickEntry = true
    }

    fun navigateTo(target: PracticeRoute) {
        if (target == PracticeRoute.Game) {
            gameSubview = PracticeGameSubview.Summary
        }
        if (target != PracticeRoute.Journal) {
            journalSelectionMode = false
            selectedJournalRowIds = emptySet()
        }
        if (target == route) return
        routeHistory.add(route)
        route = target
    }

    fun resetToHome() {
        routeHistory.clear()
        journalSelectionMode = false
        selectedJournalRowIds = emptySet()
        route = PracticeRoute.Home
    }

    fun goBack() {
        if (routeHistory.isNotEmpty()) {
            route = routeHistory.removeAt(routeHistory.lastIndex)
        } else {
            route = PracticeRoute.Home
        }
        if (route != PracticeRoute.Journal) {
            journalSelectionMode = false
            selectedJournalRowIds = emptySet()
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
