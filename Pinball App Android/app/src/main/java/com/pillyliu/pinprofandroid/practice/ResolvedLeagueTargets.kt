package com.pillyliu.pinprofandroid.practice

import android.util.Log
import org.json.JSONObject

private const val RESOLVED_LEAGUE_TARGETS_TAG = "PinballDataIntegrity"

internal data class ResolvedLeagueTargetRecord(
    val order: Int,
    val game: String,
    val practiceIdentity: String?,
    val opdbId: String?,
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
    val secondHighestAvg: Long,
    val fourthHighestAvg: Long,
    val eighthHighestAvg: Long,
) {
    val scores: LeagueTargetScores
        get() = LeagueTargetScores(
            great = secondHighestAvg.toDouble(),
            main = fourthHighestAvg.toDouble(),
            floor = eighthHighestAvg.toDouble(),
        )
}

internal fun parseResolvedLeagueTargets(text: String): List<ResolvedLeagueTargetRecord> {
    val root = runCatching { JSONObject(text.trim()) }.getOrNull() ?: return emptyList()
    if (root.optInt("version", 0) < 1) return emptyList()
    val items = root.optJSONArray("items") ?: return emptyList()
    return buildList {
        for (index in 0 until items.length()) {
            val obj = items.optJSONObject(index) ?: continue
            val game = obj.optString("game").trim()
            if (game.isBlank()) continue
            add(
                ResolvedLeagueTargetRecord(
                    order = obj.optInt("order", index),
                    game = game,
                    practiceIdentity = obj.optString("practice_identity").trim().ifBlank { null },
                    opdbId = obj.optString("opdb_id").trim().ifBlank { null },
                    area = obj.optString("area").trim().ifBlank { null },
                    areaOrder = obj.optIntOrNullLocal("area_order"),
                    group = obj.optIntOrNullLocal("group"),
                    position = obj.optIntOrNullLocal("position"),
                    bank = obj.optIntOrNullLocal("bank"),
                    secondHighestAvg = obj.optLong("second_highest_avg"),
                    fourthHighestAvg = obj.optLong("fourth_highest_avg"),
                    eighthHighestAvg = obj.optLong("eighth_highest_avg"),
                ),
            )
        }
    }
}

internal fun resolvedLeagueTargetScoresByPracticeIdentity(records: List<ResolvedLeagueTargetRecord>): Map<String, LeagueTargetScores> {
    val out = linkedMapOf<String, LeagueTargetScores>()
    records.forEach { record ->
        val practiceIdentity = record.practiceIdentity?.trim().orEmpty()
        if (practiceIdentity.isBlank()) return@forEach
        if (out.containsKey(practiceIdentity)) {
            Log.w(
                RESOLVED_LEAGUE_TARGETS_TAG,
                "Duplicate resolved league target for practice identity $practiceIdentity; keeping later row from game ${record.game}",
            )
        }
        out[practiceIdentity] = record.scores
    }
    return out
}

private fun JSONObject.optIntOrNullLocal(name: String): Int? =
    if (has(name) && !isNull(name)) optInt(name) else null
