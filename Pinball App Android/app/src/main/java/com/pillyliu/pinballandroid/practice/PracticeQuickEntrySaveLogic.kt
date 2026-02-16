package com.pillyliu.pinballandroid.practice

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
    videoValue: String,
    videoPercent: Float,
    practiceMinutes: String,
    noteText: String,
    noteType: String,
    mechanicsSkill: String,
    mechanicsCompetency: Float,
): QuickEntrySaveResult {
    val selectedSlug = rawGameSlug.takeUnless { it == "None" }.orEmpty()
    return when (mode) {
        QuickActivity.Score -> {
            if (selectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            val score = scoreText.replace(",", "").toDoubleOrNull()
            if (score != null && score > 0) {
                val context = if (scoreContext == "tournament" && tournamentName.isNotBlank()) {
                    "tournament:${tournamentName.trim()}"
                } else {
                    scoreContext
                }
                store.addScore(selectedSlug, score, context = context)
                QuickEntrySaveResult(savedSlug = selectedSlug)
            } else {
                QuickEntrySaveResult(validationMessage = "Enter a valid score above 0.")
            }
        }

        QuickActivity.Rulesheet -> {
            if (selectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            store.addStudy(
                selectedSlug,
                "rulesheet",
                "${rulesheetProgress.roundToInt()}%",
                note = noteText.takeIf { it.isNotBlank() },
            )
            QuickEntrySaveResult(savedSlug = selectedSlug)
        }

        QuickActivity.Tutorial, QuickActivity.Gameplay -> {
            if (selectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            val value = if (videoInputKind == "clock") {
                val match = Regex("^(\\d{1,3}):(\\d{2})$").find(videoValue.trim())
                val minutes = match?.groupValues?.getOrNull(1)?.toIntOrNull()
                val seconds = match?.groupValues?.getOrNull(2)?.toIntOrNull()
                if (minutes == null || seconds == null || seconds !in 0..59) {
                    return QuickEntrySaveResult(validationMessage = "Video time must be mm:ss.")
                }
                "${minutes}:${seconds.toString().padStart(2, '0')}"
            } else {
                "${videoPercent.roundToInt()}"
            }
            store.addStudy(
                selectedSlug,
                if (mode == QuickActivity.Tutorial) "tutorial" else "gameplay",
                value,
                note = noteText.takeIf { it.isNotBlank() },
            )
            QuickEntrySaveResult(savedSlug = selectedSlug)
        }

        QuickActivity.Playfield -> {
            if (selectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            store.addStudy(
                selectedSlug,
                "playfield",
                "Viewed",
                note = noteText.takeIf { it.isNotBlank() } ?: "Reviewed playfield image",
            )
            QuickEntrySaveResult(savedSlug = selectedSlug)
        }

        QuickActivity.Practice -> {
            if (selectedSlug.isBlank()) return QuickEntrySaveResult(validationMessage = "Select a game.")
            val minutes = practiceMinutes.trim()
            if (minutes.isNotEmpty() && (minutes.toIntOrNull() == null || minutes.toInt() <= 0)) {
                return QuickEntrySaveResult(validationMessage = "Practice minutes must be a whole number greater than 0.")
            }
            val practiceSummary = minutes.toIntOrNull()?.let { m ->
                "Practice session: $m minute${if (m == 1) "" else "s"}"
            } ?: "Practice session"
            store.addStudy(selectedSlug, "practice", practiceSummary)
            if (noteText.isNotBlank()) {
                store.addPracticeNote(selectedSlug, noteType, null, noteText)
            }
            QuickEntrySaveResult(savedSlug = selectedSlug)
        }

        QuickActivity.Mechanics -> {
            val targetSlug = selectedSlug.ifBlank { store.games.firstOrNull()?.slug.orEmpty() }
            if (targetSlug.isBlank()) {
                return QuickEntrySaveResult(validationMessage = "Add at least one game before logging mechanics.")
            }
            val prefix = if (mechanicsSkill.isBlank()) "#mechanics" else "#${mechanicsSkill.replace(" ", "")}"
            val composed = "$prefix competency ${mechanicsCompetency.roundToInt()}/5. ${noteText.trim()}".trim()
            store.addPracticeNote(targetSlug, "general", mechanicsSkill, composed)
            QuickEntrySaveResult(savedSlug = targetSlug)
        }
    }
}
