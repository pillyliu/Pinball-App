package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.data.parseCsv
import com.pillyliu.pinprofandroid.library.LibraryGameLookup
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class LeagueCsvRow(
    val player: String,
    val machine: String,
    val rawScore: Double,
    val eventDateMs: Long?,
    val practiceIdentity: String?,
    val opdbId: String?,
)

internal data class LeagueIfpaPlayerRecord(
    val player: String,
    val ifpaPlayerID: String,
    val ifpaName: String,
)

internal data class LeagueIdentityMatch(
    val player: String,
    val ifpaPlayerID: String?,
)

private val HUMAN_NAME_SUFFIXES = setOf("jr", "sr", "ii", "iii", "iv", "v")

internal fun normalizeMachine(value: String): String = LibraryGameLookup.normalizeMachineName(value)

internal fun normalizeHumanName(value: String): String =
    value.lowercase(Locale.US).trim().split(Regex("\\s+")).filter { it.isNotBlank() }.joinToString(" ")

private fun normalizedHumanNameTokens(value: String): List<String> =
    value
        .lowercase(Locale.US)
        .replace(Regex("[^a-z0-9]+"), " ")
        .trim()
        .split(Regex("\\s+"))
        .filter { it.isNotBlank() }

private fun relaxedHumanNameTokens(value: String): List<String> {
    val baseTokens = normalizedHumanNameTokens(value).filterNot { HUMAN_NAME_SUFFIXES.contains(it) }
    if (baseTokens.size <= 2) return baseTokens
    return baseTokens.filterIndexed { index, token ->
        index == 0 || index == baseTokens.lastIndex || token.length > 1
    }
}

private fun humanNameKeys(value: String): Set<String> {
    val strict = normalizedHumanNameTokens(value).joinToString(" ")
    val relaxed = relaxedHumanNameTokens(value).joinToString(" ")
    return setOf(strict, relaxed).filter { it.isNotBlank() }.toSet()
}

internal fun softHumanNameMatches(left: String, right: String): Boolean {
    val leftTokens = relaxedHumanNameTokens(left)
    val rightTokens = relaxedHumanNameTokens(right)
    if (leftTokens.isEmpty() || rightTokens.isEmpty()) return false
    if (leftTokens == rightTokens) return true
    if (leftTokens.size < 2 || rightTokens.size < 2) return false
    if (leftTokens.last() != rightTokens.last()) return false

    val leftFirst = leftTokens.first()
    val rightFirst = rightTokens.first()
    if (leftFirst == rightFirst) return true
    if (minOf(leftFirst.length, rightFirst.length) < 3) return false
    return leftFirst.startsWith(rightFirst) || rightFirst.startsWith(leftFirst)
}

internal fun normalizeHeader(value: String): String =
    value.replace("\uFEFF", "").trim().lowercase(Locale.US)

internal fun parseEventDateMillis(value: String): Long? {
    val parsed = runCatching { LocalDate.parse(value, DateTimeFormatter.ISO_LOCAL_DATE) }.getOrNull()
        ?: return null
    return leagueEventTimestampMsForDate(parsed)
}

internal fun leagueEventTimestampMsForDate(
    date: LocalDate,
    zoneId: ZoneId = ZoneId.systemDefault(),
): Long {
    return date.atTime(LocalTime.of(22, 0)).atZone(zoneId).toInstant().toEpochMilli()
}

internal fun parseLeagueRows(text: String): List<LeagueCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val headers = table.first().map { normalizeHeader(it) }
    val playerIdx = headers.indexOf("player")
    val machineIdx = headers.indexOf("machine").takeIf { it >= 0 } ?: headers.indexOf("game")
    val scoreIdx = headers.indexOf("rawscore").takeIf { it >= 0 } ?: headers.indexOf("score")
    val dateIdx = headers.indexOf("eventdate").takeIf { it >= 0 } ?: headers.indexOf("date")
    val practiceIdentityIdx = listOf("practiceidentity", "practice_identity").firstNotNullOfOrNull { normalized ->
        headers.indexOf(normalized).takeIf { it >= 0 }
    } ?: -1
    val opdbIdIdx = listOf("opdbid", "opdb id", "opdb_id", "opdbid").firstNotNullOfOrNull { normalized ->
        headers.indexOf(normalized).takeIf { it >= 0 }
    } ?: -1
    if (playerIdx < 0 || machineIdx < 0 || scoreIdx < 0) return emptyList()

    return table.drop(1).mapNotNull { row ->
        val player = row.getOrNull(playerIdx)?.trim().orEmpty()
        val machine = row.getOrNull(machineIdx)?.trim().orEmpty()
        val rawScore = row.getOrNull(scoreIdx)?.replace(",", "")?.trim()?.toDoubleOrNull() ?: return@mapNotNull null
        if (player.isBlank() || machine.isBlank() || rawScore <= 0) return@mapNotNull null
        val eventDateMs = row.getOrNull(dateIdx)
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?.let(::parseEventDateMillis)
        val practiceIdentity = row.getOrNull(practiceIdentityIdx)?.trim()?.takeIf { it.isNotBlank() }
        val opdbId = row.getOrNull(opdbIdIdx)?.trim()?.takeIf { it.isNotBlank() }
        LeagueCsvRow(
            player = player,
            machine = machine,
            rawScore = rawScore,
            eventDateMs = eventDateMs,
            practiceIdentity = practiceIdentity,
            opdbId = opdbId,
        )
    }
}

internal fun parseLeagueIfpaPlayers(text: String): List<LeagueIfpaPlayerRecord> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val header = table.first().map { normalizeHeader(it) }
    val playerIdx = header.indexOf("player")
    val ifpaPlayerIdIdx = header.indexOf("ifpa_player_id")
    val ifpaNameIdx = header.indexOf("ifpa_name")
    if (listOf(playerIdx, ifpaPlayerIdIdx, ifpaNameIdx).any { it < 0 }) return emptyList()

    return table.drop(1).mapNotNull { row ->
        val player = row.getOrNull(playerIdx)?.trim().orEmpty()
        val ifpaPlayerID = row.getOrNull(ifpaPlayerIdIdx)?.trim().orEmpty()
        val ifpaName = row.getOrNull(ifpaNameIdx)?.trim().orEmpty()
        if (player.isBlank() || ifpaPlayerID.isBlank()) return@mapNotNull null
        LeagueIfpaPlayerRecord(
            player = player,
            ifpaPlayerID = ifpaPlayerID,
            ifpaName = ifpaName.ifBlank { player },
        )
    }
}

internal fun matchApprovedIfpaPlayer(
    records: List<LeagueIfpaPlayerRecord>,
    inputName: String,
): LeagueIfpaPlayerRecord? {
    val inputKeys = humanNameKeys(inputName)
    val exactMatches = records.filter { record ->
        val candidateKeys = humanNameKeys(record.player) + humanNameKeys(record.ifpaName)
        candidateKeys.any(inputKeys::contains)
    }
    if (exactMatches.size == 1) return exactMatches.first()
    if (exactMatches.size > 1) return null

    val softMatches = records.filter { record ->
        softHumanNameMatches(inputName, record.player) || softHumanNameMatches(inputName, record.ifpaName)
    }
    return softMatches.singleOrNull()
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
        targets[LibraryGameLookup.normalizeMachineName(game)] = LeagueTargetScores(great = great, main = main, floor = floor)
    }
    return targets
}

internal fun resolveLeagueTargetScores(
    gameName: String,
    targetsByNormalizedMachine: Map<String, LeagueTargetScores>,
): LeagueTargetScores? {
    val keys = LibraryGameLookup.candidateKeys(gameName)
    if (keys.isEmpty()) return null

    keys.forEach { key ->
        targetsByNormalizedMachine[key]?.let { return it }
    }

    val loose = targetsByNormalizedMachine.entries.firstOrNull { (candidate, _) ->
        keys.any { key -> candidate.contains(key) || key.contains(candidate) }
    }
    return loose?.value
}
