package com.pillyliu.pinprofandroid.data

import org.json.JSONArray
import org.json.JSONObject

internal data class PinballCacheMetadataRefresh(
    val manifestFiles: Map<String, String>,
    val removedPaths: Set<String>,
    val lastMetaFetchAt: Long,
    val lastUpdateScanAt: String?,
)

internal fun shouldRefreshPinballCacheMetadata(
    lastMetaFetchAt: Long,
    now: Long,
    refreshIntervalMs: Long,
    force: Boolean,
): Boolean {
    return force || (now - lastMetaFetchAt) >= refreshIntervalMs
}

internal fun fetchPinballCacheMetadataRefresh(
    manifestUrl: String,
    updateLogUrl: String,
    now: Long,
    lastUpdateScanAt: String?,
    httpText: (String) -> String,
): PinballCacheMetadataRefresh {
    val manifestJson = JSONObject(httpText(manifestUrl))
    val filesJson = manifestJson.optJSONObject("files") ?: JSONObject()
    val manifestFiles = buildMap {
        val fileKeys = filesJson.keys()
        while (fileKeys.hasNext()) {
            val path = fileKeys.next()
            val hash = filesJson.optJSONObject(path)?.optString("hash") ?: continue
            put(path, hash)
        }
    }

    val updateJson = JSONObject(httpText(updateLogUrl))
    val events = updateJson.optJSONArray("events") ?: JSONArray()

    var newestEventAt = lastUpdateScanAt
    val removedPaths = linkedSetOf<String>()
    for (index in 0 until events.length()) {
        val event = events.optJSONObject(index) ?: continue
        val generatedAt = event.optString("generatedAt")
        if (newestEventAt == null || generatedAt > newestEventAt) {
            newestEventAt = generatedAt
        }
        if (lastUpdateScanAt != null && generatedAt <= lastUpdateScanAt) {
            continue
        }
        collectPinballCachePaths(event.optJSONArray("removed"), removedPaths)
    }

    return PinballCacheMetadataRefresh(
        manifestFiles = manifestFiles,
        removedPaths = removedPaths,
        lastMetaFetchAt = now,
        lastUpdateScanAt = newestEventAt,
    )
}

private fun collectPinballCachePaths(array: JSONArray?, into: MutableSet<String>) {
    if (array == null) return
    for (index in 0 until array.length()) {
        val path = array.optString(index)
        if (path.isNotBlank()) into += path
    }
}
