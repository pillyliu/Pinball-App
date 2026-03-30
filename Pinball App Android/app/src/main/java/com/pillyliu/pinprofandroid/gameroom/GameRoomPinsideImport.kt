package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL

private const val PINSIDE_GROUP_MAP_ASSET_PATH = "pinside_group_map.json"

internal class GameRoomPinsideImportService(private val context: Context) {
    private var cachedGroupMap: Map<String, String>? = null

    suspend fun fetchCollectionMachines(sourceInput: String): PinsideImportResult = withContext(Dispatchers.IO) {
        val normalizedInput = sourceInput.trim()
        if (normalizedInput.isBlank()) {
            throw pinsideImportException(GameRoomPinsideImportError.invalidInput)
        }

        val sourceURL = buildPinsideCollectionURL(normalizedInput)
        val groupMap = loadGroupMap()
        val machines = fetchCollectionMachinesWithFallback(sourceURL, groupMap)
        if (machines.isEmpty()) {
            throw pinsideImportException(GameRoomPinsideImportError.noMachinesFound)
        }
        PinsideImportResult(sourceURL = sourceURL.toString(), machines = machines)
    }

    private fun fetchCollectionMachinesWithFallback(
        sourceURL: URL,
        groupMap: Map<String, String>,
    ): List<PinsideImportedMachine> {
        val directResult = runCatching {
            val directHTML = fetchPinsideHTML(sourceURL)
            val directMachines = parseBasicPinsideMachines(directHTML, groupMap)
            val enrichedMachines = runCatching {
                fetchDetailedOrBasicMachinesFromJina(sourceURL, groupMap)
            }.getOrNull().orEmpty()
            if (enrichedMachines.isNotEmpty()) {
                mergePinsideMachines(primary = enrichedMachines, fallback = directMachines)
            } else {
                directMachines
            }
        }
        if (directResult.isSuccess) {
            return directResult.getOrThrow()
        }

        val directError = directResult.exceptionOrNull()
        if (directError is GameRoomPinsideImportException) {
            val fatal = when (directError.error) {
                GameRoomPinsideImportError.invalidInput,
                GameRoomPinsideImportError.invalidURL,
                GameRoomPinsideImportError.userNotFound,
                GameRoomPinsideImportError.privateOrUnavailableCollection,
                -> true
                else -> false
            }
            if (fatal) throw directError
        }

        return fetchDetailedOrBasicMachinesFromJina(sourceURL, groupMap)
    }

    private fun fetchDetailedOrBasicMachinesFromJina(
        sourceURL: URL,
        groupMap: Map<String, String>,
    ): List<PinsideImportedMachine> {
        val content = fetchPinsideHTMLFromJina(sourceURL)
        val detailedMachines = parseDetailedPinsideMachines(content)
        if (detailedMachines.isNotEmpty()) {
            return detailedMachines
        }
        return parseBasicPinsideMachines(content, groupMap)
    }

    private suspend fun loadGroupMap(): Map<String, String> {
        cachedGroupMap?.let { return it }
        val raw = runCatching {
            context.assets.open(PINSIDE_GROUP_MAP_ASSET_PATH).bufferedReader().use { it.readText() }
        }.getOrNull().orEmpty()
        if (raw.isBlank()) return emptyMap()
        val json = runCatching { JSONObject(raw) }.getOrNull() ?: return emptyMap()
        val out = linkedMapOf<String, String>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val rawKey = keys.next().trim()
            val key = rawKey.lowercase()
            val value = json.optString(rawKey).trim()
            if (key.isNotBlank() && value.isNotBlank()) out[key] = value
        }
        cachedGroupMap = out
        return out
    }
}
