package com.pillyliu.pinprofandroid.library

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

internal object LibrarySourceEvents {
    private val _version = MutableStateFlow(0L)
    val version = _version.asStateFlow()

    fun notifyChanged() {
        _version.value = System.currentTimeMillis()
    }
}

internal fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            val value = optString(i).trim()
            if (value.isNotBlank()) add(value)
        }
    }
}

internal fun JSONObject?.toStringMap(): Map<String, String> {
    if (this == null) return emptyMap()
    val out = linkedMapOf<String, String>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val value = optString(key).trim()
        if (value.isNotBlank()) out[key] = value
    }
    return out
}

internal fun JSONObject?.toIntMap(): Map<String, Int> {
    if (this == null) return emptyMap()
    val out = linkedMapOf<String, Int>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        if (has(key) && !isNull(key)) {
            out[key] = optInt(key)
        }
    }
    return out
}

internal fun <V> Map<String, V>.mapNotNullKeys(transform: (String) -> String?): Map<String, V> =
    entries.mapNotNull { (key, value) -> transform(key)?.let { it to value } }.toMap()
