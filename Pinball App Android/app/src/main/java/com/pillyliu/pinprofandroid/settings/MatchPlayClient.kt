package com.pillyliu.pinprofandroid.settings

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal data class MatchPlayTournamentImportResult(
    val id: String,
    val name: String,
    val machineIds: List<String>,
)

internal object MatchPlayClient {
    fun fetchTournament(id: String): MatchPlayTournamentImportResult {
        val trimmed = id.trim()
        if (trimmed.isBlank()) error("Enter a valid tournament ID.")

        val root = JSONObject(fetchText("https://app.matchplay.events/api/tournaments/$trimmed?includeArenas=true"))
        val data = root.optJSONObject("data") ?: error("Tournament not found.")
        val tournamentId = data.optInt("tournamentId").takeIf { it > 0 }?.toString()
            ?: error("Tournament not found.")
        val name = data.optString("name").trim().ifBlank { "Tournament $tournamentId" }
        val arenas = data.optJSONArray("arenas") ?: JSONArray()
        val machineIds = LinkedHashSet<String>()
        for (i in 0 until arenas.length()) {
            val arena = arenas.optJSONObject(i) ?: continue
            val opdbId = arena.optString("opdbId").trim()
            if (opdbId.isNotBlank()) {
                machineIds += opdbId
            }
        }
        return MatchPlayTournamentImportResult(
            id = tournamentId,
            name = name,
            machineIds = machineIds.toList(),
        )
    }

    private fun fetchText(url: String): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 20000
            requestMethod = "GET"
        }
        val status = connection.responseCode
        if (status == 404) error("Tournament not found.")
        if (status !in 200..299) error("Match Play request failed ($status)")
        return connection.inputStream.bufferedReader().use { it.readText() }
    }
}
