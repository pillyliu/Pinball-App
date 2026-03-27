package com.pillyliu.pinprofandroid.practice

internal const val PRACTICE_LEAGUE_IMPORT_DESCRIPTION =
    "Select name to import Lansing Pinball League scores. Automatically imports new scores throughout the season."

internal fun importedLeagueScoreSummary(count: Int): String {
    return when (count) {
        0 -> "No imported league scores are currently saved."
        1 -> "Remove only the 1 imported league score. Manual Practice notes and scores stay."
        else -> "Remove only the $count imported league scores. Manual Practice notes and scores stay."
    }
}

internal fun clearImportedLeagueScoresButtonTitle(count: Int): String {
    return when (count) {
        0 -> "Clear Imported League Scores"
        1 -> "Clear 1 Imported League Score"
        else -> "Clear $count Imported League Scores"
    }
}

internal fun clearImportedLeagueScoresAlertMessage(count: Int): String {
    return when (count) {
        0 -> "No imported league scores are currently saved."
        1 -> "This removes the 1 imported league score and matching journal rows. Manual Practice entries stay."
        else -> "This removes the $count imported league scores and matching journal rows. Manual Practice entries stay."
    }
}

internal fun clearedImportedLeagueScoresStatusMessage(count: Int): String {
    return when (count) {
        0 -> "No imported league scores to clear."
        1 -> "Cleared 1 imported league score."
        else -> "Cleared $count imported league scores."
    }
}
