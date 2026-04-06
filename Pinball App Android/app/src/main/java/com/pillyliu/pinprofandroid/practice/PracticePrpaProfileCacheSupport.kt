package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime

internal object PrpaProfileCacheStore {
    private const val KEY_PREFIX = "prpa-public-profile-cache"

    fun load(context: Context, playerID: String): PrpaCachedProfileSnapshot? {
        val prefs = context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
        val key = cacheKey(playerID)
        val raw = prefs.getString(key, null) ?: return null
        return try {
            val root = JSONObject(raw)
            val profileObject = root.optJSONObject("profile") ?: error("Missing cached profile.")
            val cachedAtEpochMs = root.optLong("cachedAtEpochMs", 0L).takeIf { it > 0L }
                ?: error("Missing cached timestamp.")
            PrpaCachedProfileSnapshot(
                profile = prpaProfileFromJson(profileObject),
                cachedAtEpochMs = cachedAtEpochMs,
            )
        } catch (_: Exception) {
            prefs.edit { remove(key) }
            null
        }
    }

    fun save(context: Context, profile: PrpaPlayerProfile) {
        val prefs = context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
        val root = JSONObject()
            .put("cachedAtEpochMs", System.currentTimeMillis())
            .put("profile", profile.toJson())
        prefs.edit {
            putString(cacheKey(profile.playerID), root.toString())
        }
    }

    private fun cacheKey(playerID: String): String = "$KEY_PREFIX.$playerID"
}

private fun PrpaPlayerProfile.toJson(): JSONObject {
    return JSONObject()
        .put("playerID", playerID)
        .put("displayName", displayName)
        .put("openPoints", openPoints)
        .put("eventsPlayed", eventsPlayed)
        .put("openRanking", openRanking)
        .put("averagePointsPerEvent", averagePointsPerEvent)
        .put("bestFinish", bestFinish)
        .put("worstFinish", worstFinish)
        .put("ifpaPlayerID", ifpaPlayerID)
        .put("lastEventDate", lastEventDate)
        .put(
            "scenes",
            JSONArray().apply {
                scenes.forEach { put(it.toJson()) }
            },
        )
        .put(
            "recentTournaments",
            JSONArray().apply {
                recentTournaments.forEach { put(it.toJson()) }
            },
        )
}

private fun PrpaSceneStanding.toJson(): JSONObject {
    return JSONObject()
        .put("name", name)
        .put("rank", rank)
}

private fun PrpaRecentTournament.toJson(): JSONObject {
    return JSONObject()
        .put("name", name)
        .put("eventType", eventType)
        .put("date", date.toString())
        .put("dateLabel", dateLabel)
        .put("placement", placement)
        .put("pointsGained", pointsGained)
}

private fun prpaProfileFromJson(json: JSONObject): PrpaPlayerProfile {
    val scenesArray = json.optJSONArray("scenes") ?: JSONArray()
    val scenes = buildList {
        for (index in 0 until scenesArray.length()) {
            val item = scenesArray.optJSONObject(index) ?: continue
            val name = item.optString("name").takeIf { it.isNotBlank() } ?: continue
            val rank = item.optString("rank").takeIf { it.isNotBlank() } ?: continue
            add(PrpaSceneStanding(name = name, rank = rank))
        }
    }
    val tournamentsArray = json.optJSONArray("recentTournaments") ?: JSONArray()
    val recentTournaments = buildList {
        for (index in 0 until tournamentsArray.length()) {
            val item = tournamentsArray.optJSONObject(index) ?: continue
            val date = item.optString("date").takeIf { it.isNotBlank() }?.let(LocalDateTime::parse) ?: continue
            add(
                PrpaRecentTournament(
                    name = item.optString("name"),
                    eventType = item.optString("eventType").takeIf { it.isNotBlank() },
                    date = date,
                    dateLabel = item.optString("dateLabel"),
                    placement = item.optString("placement"),
                    pointsGained = item.optString("pointsGained"),
                ),
            )
        }
    }
    return PrpaPlayerProfile(
        playerID = json.optString("playerID"),
        displayName = json.optString("displayName"),
        openPoints = json.optString("openPoints"),
        eventsPlayed = json.optString("eventsPlayed"),
        openRanking = json.optString("openRanking"),
        averagePointsPerEvent = json.optString("averagePointsPerEvent"),
        bestFinish = json.optString("bestFinish"),
        worstFinish = json.optString("worstFinish"),
        ifpaPlayerID = json.optString("ifpaPlayerID").takeIf { it.isNotBlank() },
        lastEventDate = json.optString("lastEventDate").takeIf { it.isNotBlank() },
        scenes = scenes,
        recentTournaments = recentTournaments,
    )
}
