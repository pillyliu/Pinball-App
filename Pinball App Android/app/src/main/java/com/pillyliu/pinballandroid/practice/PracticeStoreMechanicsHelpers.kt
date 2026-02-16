package com.pillyliu.pinballandroid.practice

import java.util.Locale

internal fun mechanicsAliases(skill: String): List<String> = when (skill) {
    "Dead Bounce" -> listOf("dead bounce", "deadbounce", "dead flip", "deadflip")
    "Post Pass" -> listOf("post pass", "postpass")
    "Post Catch" -> listOf("post catch", "postcatch")
    "Flick Pass" -> listOf("flick pass", "flickpass")
    "Nudge Pass" -> listOf("nudge pass", "nudgepass", "nudge control", "nudgecontrol")
    "Drop Catch" -> listOf("drop catch", "dropcatch")
    "Live Catch" -> listOf("live catch", "livecatch")
    "Shatz" -> listOf("shatz", "shatzing", "alley pass", "alleypass")
    "Back Flip" -> listOf("back flip", "backflip", "bang back", "bangback")
    "Loop Pass" -> listOf("loop pass", "looppass")
    "Slap Save (Single)" -> listOf("slap save", "slap save single", "single slap save")
    "Slap Save (Double)" -> listOf("slap save double", "double slap save")
    "Air Defense" -> listOf("air defense", "airdefense")
    "Cradle Separation" -> listOf("cradle separation", "cradleseparation")
    "Over Under" -> listOf("over under", "overunder")
    "Tap Pass" -> listOf("tap pass", "tappass")
    else -> listOf(skill.lowercase(Locale.US))
}

internal fun extractComfort(note: String): Int? {
    val regex = Regex("""comfort\s+([1-5])(?:\s*/\s*5)?""", RegexOption.IGNORE_CASE)
    return regex.find(note)?.groupValues?.getOrNull(1)?.toIntOrNull()
}

internal fun defaultMechanicsSkills(): List<String> = listOf(
    "Dead Bounce", "Post Pass", "Post Catch", "Flick Pass", "Nudge Pass", "Drop Catch", "Live Catch",
    "Shatz", "Back Flip", "Loop Pass", "Slap Save (Single)", "Slap Save (Double)", "Air Defense",
    "Cradle Separation", "Over Under", "Tap Pass",
)

internal fun detectMechanicsTags(text: String, skills: List<String>): List<String> {
    val normalized = text.lowercase(Locale.US)
    return skills.filter { skill ->
        mechanicsAliases(skill).any { alias -> normalized.contains(alias) }
    }
}

internal fun trackedMechanicsSkills(
    notes: List<NoteEntry>,
    skills: List<String>,
): List<String> {
    val tracked = skills.toMutableSet()
    notes.forEach { entry ->
        detectMechanicsTags(entry.detail.orEmpty(), skills).forEach { tracked.add(it) }
        detectMechanicsTags(entry.note, skills).forEach { tracked.add(it) }
    }
    return skills.filter { tracked.contains(it) }
}

internal fun mechanicsLogsForSkill(
    skill: String,
    notes: List<NoteEntry>,
    skills: List<String>,
): List<NoteEntry> {
    val trimmed = skill.trim()
    if (trimmed.isEmpty()) return emptyList()
    return notes.filter { entry ->
        val detailMatch = detectMechanicsTags(entry.detail.orEmpty(), skills).contains(trimmed)
        val tag = "#${trimmed.replace(" ", "").lowercase(Locale.US)}"
        val tagMatch = entry.note.lowercase(Locale.US).contains(tag)
        val termMatch = detectMechanicsTags(entry.note, skills).contains(trimmed)
        detailMatch || tagMatch || termMatch
    }.sortedBy { it.timestampMs }
}

internal fun mechanicsSummaryForSkill(
    skill: String,
    notes: List<NoteEntry>,
    skills: List<String>,
): MechanicsSkillSummary {
    val logs = mechanicsLogsForSkill(skill, notes, skills)
    val comforts = logs.mapNotNull { extractComfort(it.note) }
    val latest = comforts.lastOrNull()
    val average = if (comforts.isEmpty()) null else comforts.average()
    val trend = if (comforts.size < 2) null else {
        val split = maxOf(1, comforts.size / 2)
        val first = comforts.take(split).average()
        val second = comforts.drop(split)
        if (second.isEmpty()) null else second.average() - first
    }
    return MechanicsSkillSummary(
        totalLogs = logs.size,
        latestComfort = latest,
        averageComfort = average,
        trendDelta = trend,
    )
}
