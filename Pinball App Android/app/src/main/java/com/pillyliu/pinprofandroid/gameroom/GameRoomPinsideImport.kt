package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

private const val PINSIDE_GROUP_MAP_ASSET_PATH = "pinside_group_map.json"

internal data class PinsideImportedMachine(
    val id: String,
    val slug: String,
    val rawTitle: String,
    val rawVariant: String?,
    val manufacturerLabel: String? = null,
    val manufactureYear: Int? = null,
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
        val groupMap = loadGroupMap()
        val machines = fetchCollectionMachinesWithFallback(sourceURL, groupMap)
        if (machines.isEmpty()) {
            throw importException(GameRoomPinsideImportError.noMachinesFound)
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

    private fun fetchCollectionMachinesWithFallback(
        sourceURL: URL,
        groupMap: Map<String, String>,
    ): List<PinsideImportedMachine> {
        val directResult = runCatching {
            val directHTML = fetchHTML(sourceURL)
            val directMachines = parseBasicMachines(directHTML, groupMap)
            val enrichedMachines = runCatching {
                fetchDetailedOrBasicMachinesFromJina(sourceURL, groupMap)
            }.getOrNull().orEmpty()
            if (enrichedMachines.isNotEmpty()) {
                mergeMachines(primary = enrichedMachines, fallback = directMachines)
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
                GameRoomPinsideImportError.privateOrUnavailableCollection -> true
                else -> false
            }
            if (fatal) throw directError
        }

        return fetchDetailedOrBasicMachinesFromJina(sourceURL, groupMap)
    }

    private fun parseBasicMachines(
        html: String,
        groupMap: Map<String, String>,
    ): List<PinsideImportedMachine> {
        validateCollectionPageHTML(html)
        if (looksLikeCloudflareChallenge(html)) {
            throw importException(GameRoomPinsideImportError.parseFailed, "Pinside returned a challenge page.")
        }
        val slugs = extractCollectionSlugs(html)
        if (slugs.isEmpty()) {
            throw importException(GameRoomPinsideImportError.noMachinesFound)
        }
        return slugs.map { slug ->
            PinsideImportedMachine(
                id = slug,
                slug = slug,
                rawTitle = resolveTitle(slug, groupMap),
                rawVariant = variantFromSlug(slug),
            )
        }
    }

    private fun fetchDetailedOrBasicMachinesFromJina(
        sourceURL: URL,
        groupMap: Map<String, String>,
    ): List<PinsideImportedMachine> {
        val content = fetchHTMLFromJina(sourceURL)
        val detailedMachines = parseDetailedMachines(content)
        if (detailedMachines.isNotEmpty()) {
            return detailedMachines
        }
        return parseBasicMachines(content, groupMap)
    }

    private fun parseDetailedMachines(content: String): List<PinsideImportedMachine> {
        val titleRegex = Regex(
            """^####\s+(.+?)\s+\[\]\((?:https?:\/\/)?pinside\.com\/pinball\/machine\/([a-z0-9\-]+)[^)]*\)\s*$""",
            RegexOption.IGNORE_CASE,
        )
        val metadataRegex = Regex(
            """^#####\s+(.+?),\s*((?:19|20)\d{2})\s*$""",
            RegexOption.IGNORE_CASE,
        )
        val lines = content.lines()
        val seen = linkedSetOf<String>()
        val machines = mutableListOf<PinsideImportedMachine>()
        var index = 0

        while (index < lines.size) {
            val line = lines[index].trim()
            val titleMatch = titleRegex.matchEntire(line)
            if (titleMatch == null) {
                index += 1
                continue
            }

            val slug = titleMatch.groupValues.getOrNull(2)?.trim()?.lowercase().orEmpty()
            if (slug.isBlank() || !seen.add(slug)) {
                index += 1
                continue
            }

            val displayTitle = titleMatch.groupValues.getOrNull(1)?.trim().orEmpty()
            var scanIndex = index + 1
            while (scanIndex < lines.size && lines[scanIndex].trim().isEmpty()) {
                scanIndex += 1
            }
            if (scanIndex >= lines.size) break

            val metadataMatch = metadataRegex.matchEntire(lines[scanIndex].trim())
            if (metadataMatch == null) {
                index += 1
                continue
            }

            val parsedTitle = parseDisplayedTitle(displayTitle, variantFromSlug(slug))
            val manufacturer = metadataMatch.groupValues.getOrNull(1)?.trim()?.ifBlank { null }
            val year = metadataMatch.groupValues.getOrNull(2)?.trim()?.toIntOrNull()

            scanIndex += 1
            while (scanIndex < lines.size && lines[scanIndex].trim().isEmpty()) {
                scanIndex += 1
            }

            var purchaseText: String? = null
            if (scanIndex < lines.size) {
                val purchaseLine = lines[scanIndex].trim()
                if (purchaseLine.startsWith("Purchased ", ignoreCase = true)) {
                    purchaseText = purchaseLine.substring("Purchased ".length).trim().ifBlank { null }
                    scanIndex += 1
                }
            }

            machines += PinsideImportedMachine(
                id = slug,
                slug = slug,
                rawTitle = parsedTitle.first,
                rawVariant = parsedTitle.second,
                manufacturerLabel = manufacturer,
                manufactureYear = year,
                rawPurchaseDateText = purchaseText,
                normalizedPurchaseDateMs = normalizeFirstOfMonthMs(purchaseText),
            )
            index = scanIndex
        }

        return machines
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

    private fun resolveTitle(
        slug: String,
        groupMap: Map<String, String>,
    ): String {
        val mapped = groupMap[slug]?.trim().orEmpty()
        if (mapped.isNotEmpty() && mapped != "~") {
            return mapped
        }
        return humanizedTitleFromSlug(slug)
    }

    private fun mergeMachines(
        primary: List<PinsideImportedMachine>,
        fallback: List<PinsideImportedMachine>,
    ): List<PinsideImportedMachine> {
        val fallbackBySlug = fallback.associateBy { it.slug.lowercase() }.toMutableMap()
        val merged = mutableListOf<PinsideImportedMachine>()

        primary.forEach { machine ->
            val key = machine.slug.lowercase()
            val fallbackMachine = fallbackBySlug.remove(key)
            if (fallbackMachine == null) {
                merged += machine
            } else {
                merged += machine.copy(
                    rawVariant = machine.rawVariant ?: fallbackMachine.rawVariant,
                    manufacturerLabel = machine.manufacturerLabel ?: fallbackMachine.manufacturerLabel,
                    manufactureYear = machine.manufactureYear ?: fallbackMachine.manufactureYear,
                    rawPurchaseDateText = machine.rawPurchaseDateText ?: fallbackMachine.rawPurchaseDateText,
                    normalizedPurchaseDateMs = machine.normalizedPurchaseDateMs ?: fallbackMachine.normalizedPurchaseDateMs,
                )
            }
        }

        fallback.forEach { machine ->
            if (fallbackBySlug.containsKey(machine.slug.lowercase())) {
                merged += machine
            }
        }

        return merged
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

    private fun parseDisplayedTitle(
        title: String,
        fallbackVariant: String?,
    ): Pair<String, String?> {
        return canonicalPinsideDisplayedTitle(title, fallbackVariant)
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
