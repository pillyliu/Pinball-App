package com.pillyliu.pinballandroid.library

import android.content.Context
import com.pillyliu.pinballandroid.practice.PRACTICE_PREFS
import org.json.JSONArray
import org.json.JSONObject

private const val LIBRARY_ACTIVITY_KEY = "library-activity-log-v1"

internal enum class LibraryActivityKind(val raw: String) {
    BrowseGame("browse"),
    OpenRulesheet("rulesheet"),
    OpenPlayfield("playfield"),
    TapVideo("video"),
    ;

    companion object {
        fun fromRaw(value: String): LibraryActivityKind? = entries.firstOrNull { it.raw == value }
    }
}

internal data class LibraryActivityEvent(
    val id: String,
    val gameSlug: String,
    val gameName: String,
    val kind: LibraryActivityKind,
    val detail: String?,
    val timestampMs: Long,
)

internal object LibraryActivityLog {
    fun log(context: Context, gameSlug: String, gameName: String, kind: LibraryActivityKind, detail: String? = null) {
        val prefs = context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
        val current = events(context).toMutableList()
        current.add(
            LibraryActivityEvent(
                id = "library-${System.nanoTime()}",
                gameSlug = gameSlug,
                gameName = gameName,
                kind = kind,
                detail = detail?.trim()?.takeIf { it.isNotBlank() },
                timestampMs = System.currentTimeMillis(),
            ),
        )
        val trimmed = current.sortedByDescending { it.timestampMs }.take(500)
        val encoded = JSONArray().apply {
            trimmed.forEach { event ->
                put(
                    JSONObject().apply {
                        put("id", event.id)
                        put("gameSlug", event.gameSlug)
                        put("gameName", event.gameName)
                        put("kind", event.kind.raw)
                        put("detail", event.detail)
                        put("timestampMs", event.timestampMs)
                    },
                )
            }
        }
        prefs.edit().putString(LIBRARY_ACTIVITY_KEY, encoded.toString()).apply()
    }

    fun events(context: Context): List<LibraryActivityEvent> {
        val prefs = context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(LIBRARY_ACTIVITY_KEY, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { idx ->
                val obj = arr.optJSONObject(idx) ?: return@mapNotNull null
                val kind = LibraryActivityKind.fromRaw(obj.optString("kind")) ?: return@mapNotNull null
                val gameSlug = obj.optString("gameSlug").trim()
                val gameName = obj.optString("gameName").trim()
                if (gameSlug.isBlank() || gameName.isBlank()) return@mapNotNull null
                LibraryActivityEvent(
                    id = obj.optString("id").takeIf { it.isNotBlank() } ?: "library-$idx",
                    gameSlug = gameSlug,
                    gameName = gameName,
                    kind = kind,
                    detail = obj.optString("detail").takeIf { it.isNotBlank() },
                    timestampMs = obj.optLong("timestampMs"),
                )
            }.sortedByDescending { it.timestampMs }
        }.getOrDefault(emptyList())
    }

    fun clear(context: Context) {
        val prefs = context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove(LIBRARY_ACTIVITY_KEY).apply()
    }
}
