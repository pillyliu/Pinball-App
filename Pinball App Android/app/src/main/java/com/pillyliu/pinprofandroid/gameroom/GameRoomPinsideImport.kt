package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

internal data class PinsideImportedMachine(
    val id: String,
    val slug: String,
    val rawTitle: String,
    val rawVariant: String?,
    val rawPurchaseDateText: String? = null,
    val normalizedPurchaseDateMs: Long? = null,
) {
    val fingerprint: String
        get() = "pinside:${slug.lowercase()}"
}

internal data class PinsideImportResult(
    val sourceURL: String,
    val machines: List<PinsideImportedMachine>,
)

internal enum class GameRoomPinsideImportError {
    invalidInput,
    invalidURL,
    httpError,
    userNotFound,
    privateOrUnavailableCollection,
    parseFailed,
    noMachinesFound,
    networkUnavailable,
}

internal class GameRoomPinsideImportException(
    val error: GameRoomPinsideImportError,
    val userMessage: String,
) : Exception(userMessage)

internal class GameRoomPinsideImportService(private val context: Context) {
    private var cachedGroupMap: Map<String, String>? = null

    suspend fun fetchCollectionMachines(sourceInput: String): PinsideImportResult = withContext(Dispatchers.IO) {
        val normalizedInput = sourceInput.trim()
        if (normalizedInput.isBlank()) {
            throw importException(GameRoomPinsideImportError.invalidInput)
        }

        val sourceURL = buildCollectionURL(normalizedInput)
        val slugs = fetchCollectionSlugsWithFallback(sourceURL)
        if (slugs.isEmpty()) {
            throw importException(GameRoomPinsideImportError.noMachinesFound)
        }

        val groupMap = loadGroupMap()
        val machines = slugs.map { slug ->
            val title = groupMap[slug] ?: humanizedTitleFromSlug(slug)
            PinsideImportedMachine(
                id = slug,
                slug = slug,
                rawTitle = title,
                rawVariant = variantFromSlug(slug),
                rawPurchaseDateText = null,
                normalizedPurchaseDateMs = null,
            )
        }
        PinsideImportResult(sourceURL = sourceURL.toString(), machines = machines)
    }

    private fun buildCollectionURL(input: String): URL {
        if (input.contains("pinside.com", ignoreCase = true)) {
            val parsed = runCatching { URL(input) }.getOrNull()
            val host = parsed?.host?.lowercase().orEmpty()
            if (parsed == null || !host.contains("pinside.com")) {
                throw importException(GameRoomPinsideImportError.invalidURL)
            }
            val path = parsed.path.orEmpty()
            if (path.contains("/collection/", ignoreCase = true)) return parsed
            val segments = path.split("/").filter { it.isNotBlank() }
            val pinsiderIndex = segments.indexOfLast { it.equals("pinsiders", ignoreCase = true) }
            val profileUsername = segments.getOrNull(pinsiderIndex + 1).orEmpty()
            if (pinsiderIndex >= 0 && profileUsername.isNotBlank()) {
                return URL("https://pinside.com/pinball/community/pinsiders/${profileUsername.lowercase()}/collection/current")
            }
            return parsed
        }

        val username = input.replace("@", "").trim().lowercase()
        if (username.isBlank()) {
            throw importException(GameRoomPinsideImportError.invalidInput)
        }
        return runCatching {
            URL("https://pinside.com/pinball/community/pinsiders/$username/collection/current")
        }.getOrElse {
            throw importException(GameRoomPinsideImportError.invalidURL)
        }
    }

    private fun fetchCollectionSlugsWithFallback(sourceURL: URL): List<String> {
        val directResult = runCatching {
            val directHTML = fetchHTML(sourceURL)
            parseCollectionSlugsFromHTML(directHTML)
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
                GameRoomPinsideImportError.privateOrUnavailableCollection -> true
                else -> false
            }
            if (fatal) throw directError
        }

        val fallbackHTML = fetchHTMLFromJina(sourceURL)
        return parseCollectionSlugsFromHTML(fallbackHTML)
    }

    private fun parseCollectionSlugsFromHTML(html: String): List<String> {
        validateCollectionPageHTML(html)
        if (looksLikeCloudflareChallenge(html)) {
            throw importException(GameRoomPinsideImportError.parseFailed, "Pinside returned a challenge page.")
        }
        val slugs = extractCollectionSlugs(html)
        if (slugs.isEmpty()) {
            throw importException(GameRoomPinsideImportError.noMachinesFound)
        }
        return slugs
    }

    private fun looksLikeCloudflareChallenge(html: String): Boolean {
        val lowered = html.lowercase()
        return lowered.contains("just a moment") &&
            (lowered.contains("cf_chl_") ||
                lowered.contains("challenge-platform") ||
                lowered.contains("enable javascript and cookies to continue"))
    }

    private fun fetchHTML(url: URL): String {
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
                throw importException(GameRoomPinsideImportError.userNotFound)
            }
            if (code !in 200..299) {
                throw importException(GameRoomPinsideImportError.httpError, code.toString())
            }
            val html = connection.inputStream.bufferedReader().use { it.readText() }
            if (html.isBlank()) {
                throw importException(GameRoomPinsideImportError.parseFailed)
            }
            html
        } catch (error: GameRoomPinsideImportException) {
            throw error
        } catch (_: IOException) {
            throw importException(GameRoomPinsideImportError.networkUnavailable)
        } catch (_: Throwable) {
            throw importException(GameRoomPinsideImportError.networkUnavailable)
        } finally {
            connection.disconnect()
        }
    }

    private fun fetchHTMLFromJina(sourceURL: URL): String {
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
                throw importException(GameRoomPinsideImportError.networkUnavailable)
            }
            val html = connection.inputStream.bufferedReader().use { it.readText() }
            if (html.isBlank()) {
                throw importException(GameRoomPinsideImportError.parseFailed)
            }
            html
        } catch (error: GameRoomPinsideImportException) {
            throw error
        } catch (_: IOException) {
            throw importException(GameRoomPinsideImportError.networkUnavailable)
        } catch (_: Throwable) {
            throw importException(GameRoomPinsideImportError.networkUnavailable)
        } finally {
            connection.disconnect()
        }
    }

    private fun validateCollectionPageHTML(html: String) {
        val lowered = html.lowercase()
        if (lowered.contains("404") && lowered.contains("page not found")) {
            throw importException(GameRoomPinsideImportError.userNotFound)
        }
        if (lowered.contains("this profile is private") ||
            lowered.contains("private profile") ||
            lowered.contains("collection is private")
        ) {
            throw importException(GameRoomPinsideImportError.privateOrUnavailableCollection)
        }
        if (!lowered.contains("/pinball/machine/") &&
            (lowered.contains("access denied") || lowered.contains("not available"))
        ) {
            throw importException(GameRoomPinsideImportError.privateOrUnavailableCollection)
        }
        if (lowered.trim().isEmpty()) {
            throw importException(GameRoomPinsideImportError.parseFailed)
        }
    }

    private fun extractCollectionSlugs(html: String): List<String> {
        val regex = Regex("""(?:https?:\/\/pinside\.com)?\/pinball\/machine\/([a-z0-9\-]+)""", RegexOption.IGNORE_CASE)
        val ordered = linkedSetOf<String>()
        regex.findAll(html).forEach { match ->
            val slug = match.groupValues.getOrNull(1)?.lowercase().orEmpty()
            if (slug.isNotBlank()) ordered += slug
        }
        return ordered.toList()
    }

    private fun loadGroupMap(): Map<String, String> {
        cachedGroupMap?.let { return it }
        val raw = runCatching {
            context.assets.open("starter-pack/pinball/data/pinside_group_map.json")
                .bufferedReader()
                .use { it.readText() }
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

    private fun variantFromSlug(slug: String): String? {
        val lowered = slug.lowercase()
        val anniversaryMatch = Regex("""(\d+)(st|nd|rd|th)-anniversary""", RegexOption.IGNORE_CASE)
            .find(lowered)
        if (anniversaryMatch != null) {
            val ordinal = "${anniversaryMatch.groupValues[1]}${anniversaryMatch.groupValues[2].lowercase()}"
            return "$ordinal Anniversary"
        }
        if (lowered.contains("anniversary")) {
            return "Anniversary"
        }
        return when {
            lowered.endsWith("-premium") -> "Premium"
            lowered.endsWith("-pro") -> "Pro"
            lowered.endsWith("-le") || lowered.contains("-limited-edition") -> "LE"
            lowered.endsWith("-ce") || lowered.contains("-collector") -> "CE"
            lowered.endsWith("-se") || lowered.contains("-special-edition") -> "SE"
            else -> null
        }
    }

    private fun humanizedTitleFromSlug(slug: String): String {
        return slug
            .split("-")
            .filter { it.isNotBlank() }
            .joinToString(" ") { token ->
                token.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
            }
            .ifBlank { "Imported Machine" }
    }

    private fun importException(
        error: GameRoomPinsideImportError,
        detail: String? = null,
    ): GameRoomPinsideImportException {
        val message = when (error) {
            GameRoomPinsideImportError.invalidInput -> "Enter a Pinside username or public collection URL."
            GameRoomPinsideImportError.invalidURL -> "Could not build a valid Pinside collection URL."
            GameRoomPinsideImportError.httpError -> "Pinside request failed (${detail ?: "unknown"})."
            GameRoomPinsideImportError.userNotFound -> "Could not find that Pinside user/profile."
            GameRoomPinsideImportError.privateOrUnavailableCollection -> "This Pinside collection appears private or unavailable publicly."
            GameRoomPinsideImportError.parseFailed -> "Could not parse that collection page. Try a different public collection URL."
            GameRoomPinsideImportError.noMachinesFound -> "No machine entries were found on that public collection page."
            GameRoomPinsideImportError.networkUnavailable -> "Could not load Pinside collection right now."
        }
        return GameRoomPinsideImportException(error = error, userMessage = message)
    }
}
