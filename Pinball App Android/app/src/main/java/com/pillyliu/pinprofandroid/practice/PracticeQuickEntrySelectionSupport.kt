package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal const val QUICK_GAME_KEY_PREFIX = "practice-quick-game-"
internal const val QUICK_LIBRARY_KEY_PREFIX = "practice-quick-library-"
internal const val ALL_GAMES_LIBRARY_OPTION = "__all_games__"

internal fun resolveInitialQuickEntryLibraryOption(
    origin: QuickEntryOrigin,
    fromGameView: Boolean,
    selectedGameSourceId: String,
    resumeGameSourceId: String,
    savedLibraryOption: String,
    preferredLibraryOption: String,
    avenueLibraryOption: String,
    defaultPracticeSourceId: String,
    availableLibraryOptionIds: Set<String>,
): String {
    fun validSourceOrBlank(sourceId: String): String {
        return sourceId.takeIf { it.isNotBlank() && it in availableLibraryOptionIds }.orEmpty()
    }

    fun validLibraryOptionOrBlank(option: String): String {
        return when {
            option == ALL_GAMES_LIBRARY_OPTION -> ALL_GAMES_LIBRARY_OPTION
            option.isNotBlank() && option in availableLibraryOptionIds -> option
            else -> ""
        }
    }

    return when {
        origin == QuickEntryOrigin.Mechanics -> ALL_GAMES_LIBRARY_OPTION
        fromGameView -> validLibraryOptionOrBlank(defaultPracticeSourceId)
            .ifBlank { validSourceOrBlank(selectedGameSourceId) }
            .ifBlank { ALL_GAMES_LIBRARY_OPTION }
        else -> validSourceOrBlank(resumeGameSourceId)
            .ifBlank { validSourceOrBlank(selectedGameSourceId) }
            .ifBlank { validLibraryOptionOrBlank(savedLibraryOption) }
            .ifBlank { validLibraryOptionOrBlank(preferredLibraryOption) }
            .ifBlank { validLibraryOptionOrBlank(avenueLibraryOption) }
            .ifBlank { validLibraryOptionOrBlank(defaultPracticeSourceId) }
            .ifBlank { availableLibraryOptionIds.firstOrNull().orEmpty() }
            .ifBlank { ALL_GAMES_LIBRARY_OPTION }
    }
}

internal fun resolveInitialQuickEntryGameSlug(
    origin: QuickEntryOrigin,
    fromGameView: Boolean,
    selectedGameSlug: String,
    resumeGameSlug: String,
    savedQuickGameSlug: String,
    fallbackGameSlug: String,
): String {
    return when {
        origin == QuickEntryOrigin.Mechanics -> ""
        fromGameView -> selectedGameSlug
        resumeGameSlug.isNotBlank() -> resumeGameSlug
        selectedGameSlug.isNotBlank() -> selectedGameSlug
        savedQuickGameSlug.isNotBlank() -> savedQuickGameSlug
        else -> fallbackGameSlug
    }
}

@Composable
internal fun QuickEntrySelectionFields(
    fromGameView: Boolean,
    showLibraryDropdown: Boolean,
    librarySources: List<LibrarySource>,
    selectedLibraryOption: String,
    onLibraryOptionChange: (String) -> Unit,
    mode: QuickActivity,
    showActivityDropdown: Boolean,
    studyActivities: List<QuickActivity>,
    onActivityChange: (QuickActivity) -> Unit,
    gameOptions: List<PinballGame>,
    gameSlug: String,
    onGameSlugChange: (String) -> Unit,
) {
    if (fromGameView) {
        if (showActivityDropdown) {
            SimpleMenuDropdown(
                title = "Activity",
                options = studyActivities.map { it.label },
                selected = mode.label,
                onSelect = { selected ->
                    onActivityChange(studyActivities.firstOrNull { it.label == selected } ?: QuickActivity.Rulesheet)
                },
            )
        }
        return
    }

    if (showLibraryDropdown) {
        SimpleMenuDropdown(
            title = "Library",
            options = listOf(ALL_GAMES_LIBRARY_OPTION) + librarySources.map { it.id },
            selected = selectedLibraryOption,
            selectedLabel = when (selectedLibraryOption) {
                ALL_GAMES_LIBRARY_OPTION -> "All games"
                else -> librarySources.firstOrNull { it.id == selectedLibraryOption }?.name ?: selectedLibraryOption
            },
            onSelect = onLibraryOptionChange,
            formatOptionLabel = { option ->
                when (option) {
                    ALL_GAMES_LIBRARY_OPTION -> "All games"
                    else -> librarySources.firstOrNull { it.id == option }?.name ?: option
                }
            },
        )
    }

    SimpleMenuDropdown(
        title = "Game",
        options = if (mode == QuickActivity.Mechanics) {
            listOf("None") + gameOptions.map { it.practiceKey }
        } else {
            gameOptions.map { it.practiceKey }
        },
        selected = if (mode == QuickActivity.Mechanics && gameSlug.isBlank()) "None" else gameSlug,
        selectedLabel = if (mode == QuickActivity.Mechanics && gameSlug.isBlank()) {
            "None"
        } else {
            findGameByPracticeLookupKey(gameOptions, gameSlug)?.displayTitleForPractice ?: gameSlug
        },
        onSelect = onGameSlugChange,
        formatOptionLabel = { option ->
            if (option == "None") {
                "None"
            } else {
                findGameByPracticeLookupKey(gameOptions, option)?.displayTitleForPractice ?: option
            }
        },
    )

    if (showActivityDropdown) {
        SimpleMenuDropdown(
            title = "Activity",
            options = studyActivities.map { it.label },
            selected = mode.label,
            onSelect = { selected ->
                onActivityChange(studyActivities.firstOrNull { it.label == selected } ?: QuickActivity.Rulesheet)
            },
        )
    }
}
