package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject

internal data class GameRoomCatalogGame(
    val catalogGameID: String,
    val canonicalPracticeIdentity: String,
    val displayTitle: String,
    val displayVariant: String?,
    val manufacturerID: String?,
    val manufacturer: String?,
    val year: Int?,
    val primaryImageUrl: String?,
)

internal data class GameRoomCatalogManufacturerOption(
    val id: String,
    val name: String,
    val isModern: Boolean,
    val featuredRank: Int?,
)

internal data class GameRoomCatalogArt(
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
    val playfieldImageLargeUrl: String?,
)

internal data class GameRoomCatalogSlugMatch(
    val catalogGameID: String,
    val canonicalPracticeIdentity: String,
    val variant: String?,
)

private data class GameRoomCatalogMachineRecord(
    val groupID: String,
    val practiceIdentity: String,
    val slug: String,
    val machineName: String,
    val variant: String?,
    val manufacturer: String?,
    val year: Int?,
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
    val playfieldImageLargeUrl: String?,
)

internal class GameRoomCatalogLoader(private val context: Context) {
    var didLoad by mutableStateOf(false)
        private set

    var isLoading by mutableStateOf(false)
        private set

    var errorMessage by mutableStateOf<String?>(null)
        private set

    var games by mutableStateOf<List<GameRoomCatalogGame>>(emptyList())
        private set

    var manufacturers by mutableStateOf<List<String>>(emptyList())
        private set

    var manufacturerOptions by mutableStateOf<List<GameRoomCatalogManufacturerOption>>(emptyList())
        private set

    var variantOptionsByCatalogGameID by mutableStateOf<Map<String, List<String>>>(emptyMap())
        private set

    private var allCatalogGames: List<GameRoomCatalogGame> = emptyList()
    private var gamesByCatalogGameID: Map<String, List<GameRoomCatalogGame>> = emptyMap()
    private var gamesByNormalizedCatalogGameID: Map<String, List<GameRoomCatalogGame>> = emptyMap()
    private var variantOptionsByNormalizedCatalogGameID: Map<String, List<String>> = emptyMap()
    private var machineRecordsByCatalogGameID: Map<String, List<GameRoomCatalogMachineRecord>> = emptyMap()
    private var slugMatchesBySlug: Map<String, GameRoomCatalogSlugMatch> = emptyMap()

    fun loadIfNeeded() {
        if (didLoad) return
        didLoad = true
        isLoading = true
        errorMessage = null
        try {
            loadCatalog()
        } catch (error: Throwable) {
            games = emptyList()
            manufacturers = emptyList()
            manufacturerOptions = emptyList()
            variantOptionsByCatalogGameID = emptyMap()
            allCatalogGames = emptyList()
            gamesByCatalogGameID = emptyMap()
            gamesByNormalizedCatalogGameID = emptyMap()
            variantOptionsByNormalizedCatalogGameID = emptyMap()
            machineRecordsByCatalogGameID = emptyMap()
            slugMatchesBySlug = emptyMap()
            errorMessage = "Failed to load catalog data: ${error.localizedMessage ?: error::class.java.simpleName}"
        }
        isLoading = false
    }

    private fun loadCatalog() {
        val raw = context.assets
            .open("starter-pack/pinball/data/opdb_catalog_v1.json")
            .bufferedReader()
            .use { it.readText() }
        val root = JSONObject(raw)
        val machines = root.optJSONArray("machines")
            ?: throw IllegalStateException("Catalog data is missing machines.")

        val manufacturersArray = root.optJSONArray("manufacturers")
        manufacturerOptions = buildList {
            if (manufacturersArray != null) {
                for (index in 0 until manufacturersArray.length()) {
                    val obj = manufacturersArray.optJSONObject(index) ?: continue
                    val id = obj.optString("id").ifBlank { continue }
                    val name = obj.optString("name").ifBlank { continue }
                    add(
                        GameRoomCatalogManufacturerOption(
                            id = id,
                            name = name,
                            isModern = obj.optBoolean("is_modern", false),
                            featuredRank = obj.optInt("featured_rank").takeIf { it > 0 },
                        ),
                    )
                }
            }
        }.sortedWith(
            compareBy<GameRoomCatalogManufacturerOption> { !it.isModern }
                .thenBy { it.featuredRank ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )

        val allGames = mutableListOf<GameRoomCatalogGame>()
        val variantsByGroup = LinkedHashMap<String, MutableSet<String>>()
        val recordsByGroup = LinkedHashMap<String, MutableList<GameRoomCatalogMachineRecord>>()
        val slugMatches = LinkedHashMap<String, GameRoomCatalogSlugMatch>()
        val manufacturerBucket = linkedSetOf<String>()

        for (index in 0 until machines.length()) {
            val obj = machines.optJSONObject(index) ?: continue
            val groupID = obj.optString("opdb_group_id").ifBlank { obj.optString("practice_identity") }
            if (groupID.isBlank()) continue
            val rawTitle = obj.optString("name").ifBlank { "Machine" }
            val canonicalPracticeIdentity = obj.optString("practice_identity").ifBlank { groupID }
            val manufacturerID = obj.optString("manufacturer_id").ifBlank { null }
            val manufacturer = obj.optString("manufacturer_name").ifBlank { null }
            val year = obj.optInt("year").takeIf { it > 0 }
            val parsedTitle = parseCatalogName(
                title = rawTitle,
                explicitVariant = obj.optString("variant").ifBlank { null },
            )
            val title = parsedTitle.displayTitle
            val variant = parsedTitle.displayVariant
            val slug = obj.optString("slug").ifBlank { canonicalPracticeIdentity }.lowercase()
            val primaryImage = obj.optJSONObject("primary_image")
            val playfieldImage = obj.optJSONObject("playfield_image")
            val primaryImageUrl = primaryImage?.optString("medium_url").orEmpty().ifBlank { null }
            val primaryImageLargeUrl = primaryImage?.optString("large_url").orEmpty().ifBlank { null }
            val playfieldImageUrl = playfieldImage?.optString("medium_url").orEmpty().ifBlank { null }
            val playfieldImageLargeUrl = playfieldImage?.optString("large_url").orEmpty().ifBlank { null }
            if (!manufacturer.isNullOrBlank()) manufacturerBucket += manufacturer
            if (!variant.isNullOrBlank()) {
                variantsByGroup.getOrPut(groupID) { linkedSetOf() }.add(variant)
            }
            recordsByGroup.getOrPut(groupID) { mutableListOf() }.add(
                GameRoomCatalogMachineRecord(
                    groupID = groupID,
                    practiceIdentity = canonicalPracticeIdentity,
                    slug = slug,
                    machineName = title,
                    variant = variant,
                    manufacturer = manufacturer,
                    year = year,
                    primaryImageUrl = primaryImageUrl,
                    primaryImageLargeUrl = primaryImageLargeUrl,
                    playfieldImageUrl = playfieldImageUrl,
                    playfieldImageLargeUrl = playfieldImageLargeUrl,
                ),
            )

            val candidate = GameRoomCatalogGame(
                catalogGameID = groupID,
                canonicalPracticeIdentity = canonicalPracticeIdentity,
                displayTitle = title,
                displayVariant = variant,
                manufacturerID = manufacturerID,
                manufacturer = manufacturer,
                year = year,
                primaryImageUrl = primaryImageUrl ?: primaryImageLargeUrl,
            )
            allGames += candidate

            val slugMatch = GameRoomCatalogSlugMatch(
                catalogGameID = groupID,
                canonicalPracticeIdentity = canonicalPracticeIdentity,
                variant = variant,
            )
            buildSlugKeys(slug).forEach { key ->
                if (!slugMatches.containsKey(key)) {
                    slugMatches[key] = slugMatch
                }
            }
        }

        allCatalogGames = allGames
        gamesByCatalogGameID = allGames.groupBy { it.catalogGameID }
        gamesByNormalizedCatalogGameID = allGames.groupBy { normalizedCatalogGameID(it.catalogGameID) }
        games = dedupedCatalogGames(allGames)
        manufacturers = manufacturerBucket.toList().sortedBy { it.lowercase() }
        errorMessage = null
        variantOptionsByCatalogGameID = variantsByGroup.mapValues { (_, values) ->
            values.sortedWith(
                compareBy<String> { gameRoomVariantPreferenceRank(it) }
                    .thenBy { it.lowercase() },
            )
        }
        variantOptionsByNormalizedCatalogGameID = variantOptionsByCatalogGameID
            .entries
            .associate { (key, values) -> normalizedCatalogGameID(key) to values }
        machineRecordsByCatalogGameID = recordsByGroup
        slugMatchesBySlug = slugMatches
    }

    fun variantOptions(catalogGameID: String): List<String> {
        variantOptionsByCatalogGameID[catalogGameID]
            ?.let { return it }
        return variantOptionsByNormalizedCatalogGameID[normalizedCatalogGameID(catalogGameID)].orEmpty()
    }

    fun game(catalogGameID: String): GameRoomCatalogGame? {
        val normalizedID = catalogGameID.trim().takeIf { it.isNotEmpty() } ?: return null
        gamesByCatalogGameID[normalizedID]
            ?.let(::preferredCatalogGame)
            ?.let { return it }
        gamesByNormalizedCatalogGameID[normalizedCatalogGameID(normalizedID)]
            ?.let(::preferredCatalogGame)
            ?.let { return it }
        return games.firstOrNull { it.catalogGameID.equals(normalizedID, ignoreCase = true) }
    }

    fun slugMatch(slug: String): GameRoomCatalogSlugMatch? {
        val normalizedSlug = slug.trim().lowercase()
        if (normalizedSlug.isBlank()) return null
        return buildSlugKeys(normalizedSlug).firstNotNullOfOrNull { key -> slugMatchesBySlug[key] }
    }

    fun imageCandidates(machine: OwnedMachine): List<String> {
        val grouped = gamesByCatalogGameID[machine.catalogGameID]
            ?: gamesByNormalizedCatalogGameID[normalizedCatalogGameID(machine.catalogGameID)]
            ?: emptyList()
        if (grouped.isEmpty()) return emptyList()

        val normalizedVariant = normalizeVariantLabel(machine.displayVariant)?.lowercase()
        val normalizedTitle = machine.displayTitle.trim().lowercase()
        val rawCandidates = mutableListOf<String>()

        if (normalizedVariant != null) {
            val variantMatches = grouped.filter {
                normalizeVariantLabel(it.displayVariant)?.lowercase() == normalizedVariant
            }
            rawCandidates.addAll(variantMatches.mapNotNull { it.primaryImageUrl })
        }

        allCatalogGames.firstOrNull { it.canonicalPracticeIdentity == machine.canonicalPracticeIdentity }
            ?.primaryImageUrl
            ?.let(rawCandidates::add)

        rawCandidates.addAll(grouped.mapNotNull { it.primaryImageUrl })

        val titleMatches = allCatalogGames.filter { it.displayTitle.trim().lowercase() == normalizedTitle }
        rawCandidates.addAll(titleMatches.mapNotNull { it.primaryImageUrl })

        val seen = linkedSetOf<String>()
        return rawCandidates.mapNotNull(::resolveUrl)
            .filter { candidate -> seen.add(candidate.lowercase()) }
    }

    private fun buildSlugKeys(slug: String): List<String> {
        val lowered = slug.trim().lowercase()
        if (lowered.isBlank()) return emptyList()
        val keys = linkedSetOf<String>()
        keys += lowered
        keys += normalizeSlugForMatching(lowered)
        val strippedVariant = stripVariantSuffix(normalizeSlugForMatching(lowered))
        if (strippedVariant.isNotBlank()) keys += strippedVariant
        return keys.toList()
    }

    private fun normalizeSlugForMatching(slug: String): String {
        val prefixTokens = setOf(
            "stern",
            "williams",
            "bally",
            "gottlieb",
            "spooky",
            "jersey",
            "jack",
            "american",
            "pinball",
            "chicago",
            "gaming",
            "company",
            "sega",
            "data",
            "east",
        )
        val tokens = slug.split("-").filter { it.isNotBlank() }.toMutableList()
        while (tokens.isNotEmpty() && tokens.first() in prefixTokens) {
            tokens.removeAt(0)
        }
        val yearRegex = Regex("""^(19|20)\d{2}$""")
        val withoutYears = tokens.filterNot { token -> yearRegex.matches(token) }
        return withoutYears.joinToString("-")
    }

    private fun stripVariantSuffix(slug: String): String {
        val suffixTokens = setOf(
            "premium",
            "pro",
            "le",
            "ce",
            "se",
            "limited",
            "edition",
            "collector",
            "collectors",
        )
        val tokens = slug.split("-").filter { it.isNotBlank() }.toMutableList()
        while (tokens.isNotEmpty() && tokens.last() in suffixTokens) {
            tokens.removeAt(tokens.lastIndex)
        }
        return tokens.joinToString("-")
    }

    fun resolvedArt(
        catalogGameID: String,
        selectedVariant: String?,
        selectedTitle: String? = null,
        selectedYear: Int? = null,
    ): GameRoomCatalogArt? {
        val normalizedID = catalogGameID.trim()
        if (normalizedID.isBlank()) return null
        val records = machineRecordsByCatalogGameID[normalizedID]
            ?: machineRecordsByCatalogGameID.entries.firstOrNull { (key, _) ->
                key.equals(normalizedID, ignoreCase = true)
            }?.value
            ?: emptyList()
        if (records.isEmpty()) return null
        val variantRanked = records.sortedWith { lhs, rhs ->
            val lhsScore = machineContextScore(lhs, selectedVariant, selectedTitle, selectedYear)
            val rhsScore = machineContextScore(rhs, selectedVariant, selectedTitle, selectedYear)
            when {
                lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
                else -> compareCatalogRecords(lhs, rhs)
            }
        }
        val requestedVariant = selectedVariant?.trim()?.lowercase().orEmpty()
        val strictVariantMatch = if (requestedVariant.isBlank()) {
            variantRanked.firstOrNull {
                machineContextScore(it, selectedVariant, selectedTitle, selectedYear) > 0 && hasPrimaryArt(it)
            }
        } else {
            variantRanked.firstOrNull {
                machineContextScore(it, selectedVariant, selectedTitle, selectedYear) > 0 && hasPrimaryArt(it)
            }
        }
        val preferred = strictVariantMatch
            ?: records.filter(::hasPrimaryArt).minWithOrNull(::compareCatalogRecords)
            ?: variantRanked.first()
        return GameRoomCatalogArt(
            primaryImageUrl = preferred.primaryImageUrl,
            primaryImageLargeUrl = preferred.primaryImageLargeUrl,
            playfieldImageUrl = preferred.playfieldImageUrl,
            playfieldImageLargeUrl = preferred.playfieldImageLargeUrl,
        )
    }

    private fun compareCatalogRecords(lhs: GameRoomCatalogMachineRecord, rhs: GameRoomCatalogMachineRecord): Int {
        val lhsHasArt = hasPrimaryArt(lhs)
        val rhsHasArt = hasPrimaryArt(rhs)
        if (lhsHasArt != rhsHasArt) return if (lhsHasArt) -1 else 1

        val lhsVariant = lhs.variant?.trim().orEmpty()
        val rhsVariant = rhs.variant?.trim().orEmpty()
        if (lhsVariant.isEmpty() != rhsVariant.isEmpty()) return if (lhsVariant.isEmpty()) -1 else 1

        val lhsYear = lhs.year ?: Int.MAX_VALUE
        val rhsYear = rhs.year ?: Int.MAX_VALUE
        if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

        return lhs.machineName.lowercase().compareTo(rhs.machineName.lowercase())
    }

    private fun machineVariantMatchScore(machineVariant: String?, selectedVariant: String?): Int {
        val requested = selectedVariant?.trim()?.lowercase().orEmpty()
        val candidate = machineVariant?.trim()?.lowercase().orEmpty()
        if (requested.isBlank()) return 0
        if (candidate == requested) return 200
        if (candidate.contains(requested) || requested.contains(candidate)) return 120
        if (requested.contains("premium") && candidate == "le") return 80
        if (requested == "le" && candidate.contains("anniversary")) return 40
        return 0
    }

    private fun machineContextScore(
        record: GameRoomCatalogMachineRecord,
        selectedVariant: String?,
        selectedTitle: String?,
        selectedYear: Int?,
    ): Int {
        var score = machineVariantMatchScore(record.variant, selectedVariant)
        val inferredVariant = selectedTitle
            ?.takeIf { it.contains("(") && it.contains(")") }
            ?.substringAfterLast('(')
            ?.substringBeforeLast(')')
            ?.trim()
        if (score == 0 && !inferredVariant.isNullOrBlank()) {
            score = machineVariantMatchScore(record.variant, inferredVariant)
        }
        if (selectedYear != null && record.year == selectedYear) {
            score += 90
        }
        return score
    }

    private fun hasPrimaryArt(record: GameRoomCatalogMachineRecord): Boolean {
        return !record.primaryImageLargeUrl.isNullOrBlank() ||
            !record.primaryImageUrl.isNullOrBlank()
    }

    private fun parseCatalogName(title: String, explicitVariant: String?): ParsedCatalogName {
        val trimmedTitle = title.trim()
        val normalizedExplicitVariant = normalizeVariantLabel(explicitVariant)
        if (!normalizedExplicitVariant.isNullOrBlank()) {
            return ParsedCatalogName(displayTitle = trimmedTitle, displayVariant = normalizedExplicitVariant)
        }
        if (!trimmedTitle.endsWith(")")) {
            return ParsedCatalogName(displayTitle = trimmedTitle, displayVariant = null)
        }

        val openParenIndex = trimmedTitle.lastIndexOf('(')
        if (openParenIndex <= 0) {
            return ParsedCatalogName(displayTitle = trimmedTitle, displayVariant = null)
        }

        val baseTitle = trimmedTitle.substring(0, openParenIndex).trim()
        val rawSuffix = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
        val derivedVariant = deriveVariantFromTitleSuffix(rawSuffix)
        return if (baseTitle.isNotBlank() && !derivedVariant.isNullOrBlank()) {
            ParsedCatalogName(displayTitle = baseTitle, displayVariant = derivedVariant)
        } else {
            ParsedCatalogName(displayTitle = trimmedTitle, displayVariant = null)
        }
    }

    private fun deriveVariantFromTitleSuffix(value: String): String? {
        val lowered = value.trim().lowercase()
        if (lowered.isBlank()) return null
        val looksLikeVariant = lowered == "premium" ||
            lowered == "pro" ||
            lowered == "le" ||
            lowered == "ce" ||
            lowered == "se" ||
            lowered == "home" ||
            lowered.contains("anniversary") ||
            lowered.contains("limited edition") ||
            lowered.contains("special edition") ||
            lowered.contains("collector") ||
            lowered == "premium/le" ||
            lowered == "premium le" ||
            lowered == "premium-le"
        return if (looksLikeVariant) normalizeVariantLabel(value) else null
    }

    private fun normalizeVariantLabel(value: String?): String? {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isBlank()) return null
        val lowered = trimmed.lowercase()
        return when {
            lowered == "null" || lowered == "none" -> null
            lowered == "premium" -> "Premium"
            lowered == "pro" -> "Pro"
            lowered == "le" || lowered.contains("limited edition") -> "LE"
            lowered == "ce" || lowered.contains("collector") -> "CE"
            lowered == "se" || lowered.contains("special edition") -> "SE"
            lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" -> "Premium/LE"
            lowered.contains("anniversary") -> trimmed.split(" ")
                .filter { it.isNotBlank() }
                .joinToString(" ") { token ->
                    when (token.lowercase()) {
                        "le", "ce", "se" -> token.uppercase()
                        else -> token.replaceFirstChar { ch -> if (ch.isLowerCase()) ch.titlecase() else ch.toString() }
                    }
                }
            else -> trimmed
        }
    }

    private data class ParsedCatalogName(
        val displayTitle: String,
        val displayVariant: String?,
    )

    private fun normalizedCatalogGameID(value: String): String =
        value.trim().lowercase()

    private fun resolveUrl(pathOrUrl: String?): String? {
        val value = pathOrUrl?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        if (value.startsWith("http://") || value.startsWith("https://")) return value
        return if (value.startsWith("/")) {
            "https://pillyliu.com$value"
        } else {
            "https://pillyliu.com/$value"
        }
    }
}
