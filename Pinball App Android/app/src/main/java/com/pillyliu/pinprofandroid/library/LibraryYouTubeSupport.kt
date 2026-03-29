package com.pillyliu.pinprofandroid.library

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.core.net.toUri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap

internal fun openYoutubeInApp(context: Context, url: String, fallbackVideoId: String): Boolean {
    return try {
        if (url.startsWith("intent:")) {
            val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } else {
            val id = youtubeId(url) ?: fallbackVideoId
            val appIntent = Intent(Intent.ACTION_VIEW, "vnd.youtube:$id".toUri()).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(appIntent)
            } catch (_: ActivityNotFoundException) {
                val webIntent = Intent(Intent.ACTION_VIEW, "https://www.youtube.com/watch?v=$id".toUri()).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(webIntent)
            }
            true
        }
    } catch (_: Throwable) {
        false
    }
}

internal fun youtubeId(raw: String?): String? {
    raw ?: return null
    return try {
        val uri = java.net.URI(raw)
        val host = uri.host?.lowercase() ?: return null
        when {
            host.contains("youtu.be") -> uri.path.removePrefix("/").takeIf { it.isNotBlank() }
            host.contains("youtube.com") -> {
                val queryID = uri.query
                    ?.split("&")
                    ?.mapNotNull {
                        val pair = it.split("=", limit = 2)
                        if (pair.size == 2 && pair[0] == "v") pair[1] else null
                    }
                    ?.firstOrNull()
                queryID
                    ?: uri.path.removePrefix("/shorts/").takeIf { uri.path.startsWith("/shorts/") && it.isNotBlank() }
                    ?: uri.path.removePrefix("/embed/").takeIf { uri.path.startsWith("/embed/") && it.isNotBlank() }
            }
            else -> null
        }
    } catch (_: Throwable) {
        null
    }
}

private val youTubeMetadataCache = ConcurrentHashMap<String, YouTubeVideoMetadata>()

internal suspend fun loadYouTubeVideoMetadata(videoId: String): YouTubeVideoMetadata? {
    youTubeMetadataCache[videoId]?.let { return it }

    return withContext(Dispatchers.IO) {
        try {
            val watchUrl = "https://www.youtube.com/watch?v=$videoId"
            val encodedWatchUrl = URLEncoder.encode(watchUrl, StandardCharsets.UTF_8.toString())
            val requestUrl = URL("https://www.youtube.com/oembed?url=$encodedWatchUrl&format=json")
            val connection = requestUrl.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.setRequestProperty("Accept", "application/json")
            try {
                if (connection.responseCode !in 200..299) {
                    return@withContext null
                }
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(body)
                val title = json.optString("title").trim()
                if (title.isBlank()) {
                    return@withContext null
                }
                val channelName = json.optString("author_name").trim().ifBlank { null }
                YouTubeVideoMetadata(title = title, channelName = channelName).also {
                    youTubeMetadataCache[videoId] = it
                }
            } finally {
                connection.disconnect()
            }
        } catch (_: Throwable) {
            null
        }
    }
}
