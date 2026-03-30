package com.pillyliu.pinprofandroid.gameroom

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

internal fun fetchPinsideHTML(url: URL): String {
    val connection = (url.openConnection() as HttpURLConnection).apply {
        instanceFollowRedirects = true
        connectTimeout = 20_000
        readTimeout = 20_000
        setRequestProperty("Accept", "text/html")
        setRequestProperty("Accept-Language", "en-US,en;q=0.9")
        // Browser-like UA performs better with Pinside than default Java/OkHttp variants.
        setRequestProperty(
            "User-Agent",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36",
        )
        requestMethod = "GET"
    }
    return try {
        val code = connection.responseCode
        if (code == 404) {
            throw pinsideImportException(GameRoomPinsideImportError.userNotFound)
        }
        if (code !in 200..299) {
            throw pinsideImportException(GameRoomPinsideImportError.httpError, code.toString())
        }
        val html = connection.inputStream.bufferedReader().use { it.readText() }
        if (html.isBlank()) {
            throw pinsideImportException(GameRoomPinsideImportError.parseFailed)
        }
        html
    } catch (error: GameRoomPinsideImportException) {
        throw error
    } catch (_: IOException) {
        throw pinsideImportException(GameRoomPinsideImportError.networkUnavailable)
    } catch (_: Throwable) {
        throw pinsideImportException(GameRoomPinsideImportError.networkUnavailable)
    } finally {
        connection.disconnect()
    }
}

internal fun fetchPinsideHTMLFromJina(sourceURL: URL): String {
    val normalizedTarget = sourceURL.toString()
        .removePrefix("https://")
        .removePrefix("http://")
    val proxyURL = URL("https://r.jina.ai/http://$normalizedTarget")
    val connection = (proxyURL.openConnection() as HttpURLConnection).apply {
        instanceFollowRedirects = true
        connectTimeout = 20_000
        readTimeout = 20_000
        setRequestProperty("Accept", "text/plain")
        setRequestProperty("Accept-Language", "en-US,en;q=0.9")
        setRequestProperty(
            "User-Agent",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36",
        )
        requestMethod = "GET"
    }
    return try {
        val code = connection.responseCode
        if (code !in 200..299) {
            throw pinsideImportException(GameRoomPinsideImportError.networkUnavailable)
        }
        val html = connection.inputStream.bufferedReader().use { it.readText() }
        if (html.isBlank()) {
            throw pinsideImportException(GameRoomPinsideImportError.parseFailed)
        }
        html
    } catch (error: GameRoomPinsideImportException) {
        throw error
    } catch (_: IOException) {
        throw pinsideImportException(GameRoomPinsideImportError.networkUnavailable)
    } catch (_: Throwable) {
        throw pinsideImportException(GameRoomPinsideImportError.networkUnavailable)
    } finally {
        connection.disconnect()
    }
}

internal fun validatePinsideCollectionPageHTML(html: String) {
    val lowered = html.lowercase()
    if (lowered.contains("404") && lowered.contains("page not found")) {
        throw pinsideImportException(GameRoomPinsideImportError.userNotFound)
    }
    if (
        lowered.contains("this profile is private") ||
        lowered.contains("private profile") ||
        lowered.contains("collection is private")
    ) {
        throw pinsideImportException(GameRoomPinsideImportError.privateOrUnavailableCollection)
    }
    if (
        !lowered.contains("/pinball/machine/") &&
        (lowered.contains("access denied") || lowered.contains("not available"))
    ) {
        throw pinsideImportException(GameRoomPinsideImportError.privateOrUnavailableCollection)
    }
    if (lowered.trim().isEmpty()) {
        throw pinsideImportException(GameRoomPinsideImportError.parseFailed)
    }
}
