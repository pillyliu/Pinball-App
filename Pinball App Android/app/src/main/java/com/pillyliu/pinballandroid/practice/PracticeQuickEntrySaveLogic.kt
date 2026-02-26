package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame
import kotlin.math.roundToInt

internal data class QuickEntrySaveResult(
    val savedSlug: String? = null,
    val validationMessage: String? = null,
)

internal fun saveQuickEntry(
    store: PracticeStore,
    mode: QuickActivity,
    rawGameSlug: String,
    scoreText: String,
    scoreContext: String,
    tournamentName: String,
    rulesheetProgress: Float,
    videoInputKind: String,
    selectedVideoSource: String,
    videoWatchedTime: String,
    videoTotalTime: String,
    videoPercent: Float,
    practiceMinutes: String,
    noteText: String,
    mechanicsSkill: String,
    mechanicsCompetency: Float,
): QuickEntrySaveResult {
    val lookupGames = if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
    val selectedSlug = rawGameSlug.takeUnless { it == "None" }.orEmpty()
    val resolvedSelectedSlug = canonicalPracticeKey(selectedSlug, lookupGames).takeIf {
        it.isNotBlank() && findGameByPracticeLookupKey(lookupGames, it) != null
    }.orEmpty()

    return when (mode) {
        QuickActivity.Score -> {
            if (resolvedSelectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            val score = scoreText.replace(",", "").toDoubleOrNull()
            if (score != null && score > 0) {
                val context = if (scoreContext == "tournament" && tournamentName.isNotBlank()) {
                    "tournament:${tournamentName.trim()}"
                } else {
                    scoreContext
                }
                store.addScore(resolvedSelectedSlug, score, context = context)
                QuickEntrySaveResult(savedSlug = resolvedSelectedSlug)
            } else {
                QuickEntrySaveResult(validationMessage = "Enter a valid score above 0.")
            }
        }

        QuickActivity.Rulesheet -> {
            if (resolvedSelectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            store.addStudy(
                resolvedSelectedSlug,
                "rulesheet",
                "${rulesheetProgress.roundToInt()}%",
                note = noteText.takeIf { it.isNotBlank() },
            )
            QuickEntrySaveResult(savedSlug = resolvedSelectedSlug)
        }

        QuickActivity.Tutorial, QuickActivity.Gameplay -> {
            if (resolvedSelectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            val sourceLabel = selectedVideoSource.ifBlank {
                if (mode == QuickActivity.Tutorial) "Tutorial -" else "Gameplay -"
            }
            val percent = if (videoInputKind == "clock") {
                val watched = parseHhMmSs(videoWatchedTime)
                val total = parseHhMmSs(videoTotalTime)
                if (watched == null && total == null) {
                    100
                } else {
                    if (watched == null || total == null || total <= 0 || watched > total) {
                        return QuickEntrySaveResult(validationMessage = "Enter valid watched/total hh:mm:ss values.")
                    }
                    ((watched.toDouble() / total.toDouble()) * 100.0).roundToInt().coerceIn(0, 100)
                }
            } else {
                videoPercent.roundToInt().coerceIn(0, 100)
            }
            val value = if (videoInputKind == "clock") {
                val watched = parseHhMmSs(videoWatchedTime)
                val total = parseHhMmSs(videoTotalTime)
                if (watched != null && total != null) {
                    "$percent% ($sourceLabel; ${formatHhMmSs(watched)}/${formatHhMmSs(total)})"
                } else {
                    "$percent% ($sourceLabel)"
                }
            } else {
                "$percent% ($sourceLabel)"
            }
            store.addStudy(
                resolvedSelectedSlug,
                if (mode == QuickActivity.Tutorial) "tutorial" else "gameplay",
                value,
                note = noteText.takeIf { it.isNotBlank() },
            )
            QuickEntrySaveResult(savedSlug = resolvedSelectedSlug)
        }

        QuickActivity.Playfield -> {
            if (resolvedSelectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            store.addStudy(
                resolvedSelectedSlug,
                "playfield",
                "Viewed",
                note = noteText.takeIf { it.isNotBlank() } ?: "Reviewed playfield image",
            )
            QuickEntrySaveResult(savedSlug = resolvedSelectedSlug)
        }

        QuickActivity.Practice -> {
            if (resolvedSelectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            val minutes = practiceMinutes.trim()
            if (minutes.isNotEmpty() && (minutes.toIntOrNull() == null || minutes.toInt() <= 0)) {
                return QuickEntrySaveResult(validationMessage = "Practice minutes must be a whole number greater than 0.")
            }
            val practiceSummary = minutes.toIntOrNull()?.let { m ->
                "Practice session: $m minute${if (m == 1) "" else "s"}"
            } ?: "Practice session"
            store.addStudy(
                resolvedSelectedSlug,
                "practice",
                practiceSummary,
                note = noteText.takeIf { it.isNotBlank() },
            )
            QuickEntrySaveResult(savedSlug = resolvedSelectedSlug)
        }

        QuickActivity.Mechanics -> {
            val prefix = if (mechanicsSkill.isBlank()) "#mechanics" else "#${mechanicsSkill.replace(" ", "")}"
            val composed = "$prefix competency ${mechanicsCompetency.roundToInt()}/5. ${noteText.trim()}".trim()
            store.addPracticeNote(resolvedSelectedSlug, "general", mechanicsSkill, composed)
            QuickEntrySaveResult(savedSlug = resolvedSelectedSlug)
        }
    }
}

internal fun quickEntryVideoSourceOptions(game: PinballGame?, mode: QuickActivity): List<String> {
    val prefix = when (mode) {
        QuickActivity.Tutorial -> "Tutorial"
        QuickActivity.Gameplay -> "Gameplay"
        else -> return emptyList()
    }
    val normalized = prefix.lowercase()
    val matching = game?.videos.orEmpty().filter { video ->
        video.kind?.contains(normalized, ignoreCase = true) == true ||
            video.label?.contains(prefix, ignoreCase = true) == true
    }
    return if (matching.isEmpty()) {
        listOf("$prefix -")
    } else {
        matching.indices.map { idx -> "$prefix ${idx + 1}" }
    }
}

private fun parseHhMmSs(raw: String): Int? {
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) return null
    val match = Regex("^(\\d{1,2}):(\\d{2}):(\\d{2})$").find(trimmed) ?: return null
    val hours = match.groupValues[1].toIntOrNull() ?: return null
    val minutes = match.groupValues[2].toIntOrNull() ?: return null
    val seconds = match.groupValues[3].toIntOrNull() ?: return null
    if (minutes !in 0..59 || seconds !in 0..59) return null
    return (hours * 3600) + (minutes * 60) + seconds
}

private fun formatHhMmSs(totalSeconds: Int): String {
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d:%02d".format(hours, minutes, seconds)
}
