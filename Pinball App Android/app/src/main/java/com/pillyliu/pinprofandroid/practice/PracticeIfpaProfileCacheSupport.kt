package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject

internal object IfpaProfileCacheStore {
    private const val KEY_PREFIX = "ifpa-public-profile-cache"

    fun load(context: Context, playerID: String): IfpaCachedProfileSnapshot? {
        val prefs = context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
        val key = cacheKey(playerID)
        val raw = prefs.getString(key, null) ?: return null
        return try {
            val root = JSONObject(raw)
            val profileObject = root.optJSONObject("profile") ?: error("Missing cached profile.")
            val cachedAtEpochMs = root.optLong("cachedAtEpochMs", 0L).takeIf { it > 0L }
                ?: error("Missing cached timestamp.")
            IfpaCachedProfileSnapshot(
                profile = profileFromJson(profileObject),
                cachedAtEpochMs = cachedAtEpochMs,
            )
        } catch (_: Exception) {
            prefs.edit { remove(key) }
            null
        }
    }

    fun save(context: Context, profile: IfpaPlayerProfile) {
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

private fun IfpaPlayerProfile.toJson(): JSONObject {
    return JSONObject()
        .put("playerID", playerID)
        .put("displayName", displayName)
        .put("location", location)
        .put("profilePhotoUrl", profilePhotoUrl)
        .put("currentRank", currentRank)
        .put("currentWpprPoints", currentWpprPoints)
        .put("rating", rating)
        .put("lastEventDate", lastEventDate)
        .put("seriesLabel", seriesLabel)
        .put("seriesRank", seriesRank)
        .put(
            "recentTournaments",
            JSONArray().apply {
                recentTournaments.forEach { put(it.toJson()) }
            },
        )
}

private fun IfpaRecentTournament.toJson(): JSONObject {
    return JSONObject()
        .put("name", name)
        .put("date", date.toString())
        .put("dateLabel", dateLabel)
        .put("finish", finish)
        .put("pointsGained", pointsGained)
}

private fun profileFromJson(json: JSONObject): IfpaPlayerProfile {
    val recentTournamentsArray = json.optJSONArray("recentTournaments") ?: JSONArray()
    val recentTournaments = buildList {
        for (index in 0 until recentTournamentsArray.length()) {
            val item = recentTournamentsArray.optJSONObject(index) ?: continue
            val date = item.optString("date").takeIf { it.isNotBlank() }?.let(java.time.LocalDate::parse) ?: continue
            add(
                IfpaRecentTournament(
                    name = item.optString("name"),
                    date = date,
                    dateLabel = item.optString("dateLabel"),
                    finish = item.optString("finish"),
                    pointsGained = item.optString("pointsGained"),
                ),
            )
        }
    }
    return IfpaPlayerProfile(
        playerID = json.optString("playerID"),
        displayName = json.optString("displayName"),
        location = json.optString("location").takeIf { it.isNotBlank() },
        profilePhotoUrl = json.optString("profilePhotoUrl").takeIf { it.isNotBlank() },
        currentRank = json.optString("currentRank"),
        currentWpprPoints = json.optString("currentWpprPoints"),
        rating = json.optString("rating"),
        lastEventDate = json.optString("lastEventDate").takeIf { it.isNotBlank() },
        seriesLabel = json.optString("seriesLabel").takeIf { it.isNotBlank() },
        seriesRank = json.optString("seriesRank").takeIf { it.isNotBlank() },
        recentTournaments = recentTournaments,
    )
}
