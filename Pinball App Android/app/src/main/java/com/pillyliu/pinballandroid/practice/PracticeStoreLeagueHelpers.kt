package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.data.parseCsv
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class LeagueCsvRow(
    val player: String,
    val machine: String,
    val rawScore: Double,
)

internal fun normalizeMachine(value: String): String =
    value.lowercase(Locale.US).replace("&", " and ").filter { it.isLetterOrDigit() }

internal fun normalizeHumanName(value: String): String =
    value.lowercase(Locale.US).trim().split(Regex("\\s+")).filter { it.isNotBlank() }.joinToString(" ")

internal fun normalizeHeader(value: String): String =
    value.replace("\uFEFF", "").trim().lowercase(Locale.US)

internal fun parseEventDateMillis(value: String): Long {
    val parsed = runCatching { LocalDate.parse(value, DateTimeFormatter.ISO_LOCAL_DATE) }.getOrNull()
        ?: return System.currentTimeMillis()
    return parsed.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
}

internal fun parseLeagueRows(text: String): List<LeagueCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val headers = table.first().map { normalizeHeader(it) }
    val playerIdx = headers.indexOf("player")
    val machineIdx = headers.indexOf("machine").takeIf { it >= 0 } ?: headers.indexOf("game")
    val scoreIdx = headers.indexOf("rawscore").takeIf { it >= 0 } ?: headers.indexOf("score")
    if (playerIdx < 0 || machineIdx < 0 || scoreIdx < 0) return emptyList()

    return table.drop(1).mapNotNull { row ->
        val player = row.getOrNull(playerIdx)?.trim().orEmpty()
        val machine = row.getOrNull(machineIdx)?.trim().orEmpty()
        val rawScore = row.getOrNull(scoreIdx)?.replace(",", "")?.trim()?.toDoubleOrNull() ?: return@mapNotNull null
        if (player.isBlank() || machine.isBlank() || rawScore <= 0) return@mapNotNull null
        LeagueCsvRow(player = player, machine = machine, rawScore = rawScore)
    }
}

internal fun parseLeagueTargets(text: String): Map<String, LeagueTargetScores> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyMap()
    val header = table.first().map { normalizeHeader(it) }
    val gameIndex = header.indexOf("game")
    val secondIndex = header.indexOf("second_highest_avg")
    val fourthIndex = header.indexOf("fourth_highest_avg")
    val eighthIndex = header.indexOf("eighth_highest_avg")
    if (listOf(gameIndex, secondIndex, fourthIndex, eighthIndex).any { it < 0 }) return emptyMap()

    val targets = linkedMapOf<String, LeagueTargetScores>()
    table.drop(1).forEach { row ->
        if (listOf(gameIndex, secondIndex, fourthIndex, eighthIndex).any { it !in row.indices }) return@forEach
        val game = row[gameIndex].trim()
        if (game.isBlank()) return@forEach

        val great = row[secondIndex].replace(",", "").trim().toDoubleOrNull() ?: return@forEach
        val main = row[fourthIndex].replace(",", "").trim().toDoubleOrNull() ?: return@forEach
        val floor = row[eighthIndex].replace(",", "").trim().toDoubleOrNull() ?: return@forEach
        targets[normalizeMachine(game)] = LeagueTargetScores(great = great, main = main, floor = floor)
    }
    return targets
}

internal fun resolveLeagueTargetScores(
    gameName: String,
    targetsByNormalizedMachine: Map<String, LeagueTargetScores>,
): LeagueTargetScores? {
    val normalized = normalizeMachine(gameName)
    val keys = listOf(normalized) + (MACHINE_ALIASES[normalized] ?: emptyList())

    keys.forEach { key ->
        targetsByNormalizedMachine[key]?.let { return it }
    }

    val loose = targetsByNormalizedMachine.entries.firstOrNull { (candidate, _) ->
        keys.any { key -> candidate.contains(key) || key.contains(candidate) }
    }
    return loose?.value
}

private val MACHINE_ALIASES = mapOf(
    "tmnt" to listOf("teenagemutantninjaturtles"),
    "thegetaway" to listOf("thegetawayhighspeedii"),
    "starwars2017" to listOf("starwars"),
    "jurassicparkstern2019" to listOf("jurassicpark", "jurassicpark2019"),
    "attackfrommars" to listOf("attackfrommarsremake"),
    "dungeonsanddragons" to listOf("dungeonsdragons"),
)
