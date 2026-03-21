package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.decodeCatalogManufacturerOptionsFromOPDBExport
import com.pillyliu.pinprofandroid.library.decodeOPDBExportCatalogMachines
import com.pillyliu.pinprofandroid.library.hostedOPDBExportPath
import kotlinx.coroutines.runBlocking

internal data class GameRoomCatalogGame(
    val catalogGameID: String,
    val opdbID: String,
    val canonicalPracticeIdentity: String,
    val displayTitle: String,
    val displayVariant: String?,
    val manufacturerID: String?,
    val manufacturer: String?,
    val year: Int?,
    val primaryImageUrl: String?,
    val opdbType: String?,
    val opdbDisplay: String?,
    val opdbShortname: String?,
    val opdbCommonName: String?,
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
    val opdbID: String,
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
        val raw = runBlocking {
            PinballDataCache.loadText(
                url = hostedOPDBExportPath,
                allowMissing = false,
            ).text
        } ?: throw IllegalStateException("Catalog data is missing.")
        val machines = decodeOPDBExportCatalogMachines(raw)
        if (machines.isEmpty()) {
            throw IllegalStateException("Catalog data is missing machines.")
        }

        manufacturerOptions = decodeCatalogManufacturerOptionsFromOPDBExport(raw)
            .map { option ->
                GameRoomCatalogManufacturerOption(
                    id = option.id,
                    name = option.name,
                    isModern = option.isModern,
                    featuredRank = option.featuredRank,
                )
            }
            .sortedWith(
            compareBy<GameRoomCatalogManufacturerOption> { !it.isModern }
                .thenBy { it.featuredRank ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )

        val allGames = mutableListOf<GameRoomCatalogGame>()
        val variantsByGroup = LinkedHashMap<String, MutableSet<String>>()
        val recordsByGroup = LinkedHashMap<String, MutableList<GameRoomCatalogMachineRecord>>()
        val slugMatches = LinkedHashMap<String, GameRoomCatalogSlugMatch>()
        val manufacturerBucket = linkedSetOf<String>()

        machines.forEach { machine ->
            val groupID = machine.opdbGroupId ?: machine.practiceIdentity
            if (groupID.isBlank()) return@forEach
            val opdbID = machine.opdbMachineId ?: groupID
            val rawTitle = machine.name.ifBlank { "Machine" }
            val canonicalPracticeIdentity = machine.practiceIdentity.ifBlank { groupID }
            val manufacturerID = machine.manufacturerId
            val manufacturer = machine.manufacturerName
            val year = machine.year
            val parsedTitle = parseCatalogName(
                title = rawTitle,
                explicitVariant = machine.variant,
            )
            val title = parsedTitle.displayTitle
            val variant = parsedTitle.displayVariant
            val slug = machine.slug.ifBlank { canonicalPracticeIdentity }.lowercase()
            val primaryImageUrl = machine.primaryImageMediumUrl
            val primaryImageLargeUrl = machine.primaryImageLargeUrl
            val playfieldImageUrl = machine.playfieldImageMediumUrl
            val playfieldImageLargeUrl = machine.playfieldImageLargeUrl
            if (!manufacturer.isNullOrBlank()) manufacturerBucket += manufacturer
            if (!variant.isNullOrBlank()) {
                variantsByGroup.getOrPut(groupID) { linkedSetOf() }.add(variant)
            }
            recordsByGroup.getOrPut(groupID) { mutableListOf() }.add(
                GameRoomCatalogMachineRecord(
                    groupID = groupID,
                    opdbID = opdbID,
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
                opdbID = opdbID,
                canonicalPracticeIdentity = canonicalPracticeIdentity,
                displayTitle = title,
                displayVariant = variant,
                manufacturerID = manufacturerID,
                manufacturer = manufacturer,
                year = year,
                primaryImageUrl = primaryImageUrl ?: primaryImageLargeUrl,
                opdbType = machine.opdbType,
                opdbDisplay = machine.opdbDisplay,
                opdbShortname = machine.opdbShortname,
                opdbCommonName = machine.opdbCommonName,
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
            sanitizeVariantOptions(values.toList()).sortedWith(
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

    fun games(catalogGameID: String): List<GameRoomCatalogGame> {
        val normalizedID = catalogGameID.trim().takeIf { it.isNotEmpty() } ?: return emptyList()
        gamesByCatalogGameID[normalizedID]?.let { return it.sortedWith(::compareSortedCatalogGames) }
        gamesByNormalizedCatalogGameID[normalizedCatalogGameID(normalizedID)]?.let { return it.sortedWith(::compareSortedCatalogGames) }
        return emptyList()
    }

    fun game(catalogGameID: String, variant: String?): GameRoomCatalogGame? {
        if (normalizeVariantLabel(variant) != null) {
            val matches = games(catalogGameID).filter {
                variantMatchesSelection(it.displayVariant, variant)
            }
            if (matches.isNotEmpty()) {
                return preferredCatalogGame(matches)
            }
        }
        return game(catalogGameID)
    }

    fun slugMatch(slug: String): GameRoomCatalogSlugMatch? {
        val normalizedSlug = slug.trim().lowercase()
        if (normalizedSlug.isBlank()) return null
        return buildSlugKeys(normalizedSlug).firstNotNullOfOrNull { key -> slugMatchesBySlug[key] }
    }

    fun resolvedOpdbId(machine: OwnedMachine): String? {
        machine.opdbID?.trim()?.takeIf { it.isNotBlank() }?.let { existing ->
            if (catalogGameForExactOpdbId(existing) != null) {
                return existing
            }
        }

        val parsedName = parseCatalogName(
            title = machine.displayTitle,
            explicitVariant = machine.displayVariant,
        )
        val normalizedTitle = parsedName.displayTitle.trim().lowercase()
        val normalizedVariant = normalizeVariantLabel(parsedName.displayVariant)
        val grouped = games(machine.catalogGameID)

        if (normalizedVariant != null) {
            grouped.firstOrNull {
                it.displayTitle.trim().lowercase() == normalizedTitle &&
                    normalizeVariantLabel(it.displayVariant) == normalizedVariant
            }?.let { return it.opdbID }
        }

        if (normalizedVariant != null) {
            grouped.firstOrNull {
                variantMatchesSelection(it.displayVariant, normalizedVariant)
            }?.let { return it.opdbID }
        }

        grouped.firstOrNull {
            it.displayTitle.trim().lowercase() == normalizedTitle
        }?.let { return it.opdbID }

        allCatalogGames.firstOrNull {
            it.canonicalPracticeIdentity == machine.canonicalPracticeIdentity
        }?.let { return it.opdbID }

        return grouped.firstOrNull()?.opdbID
    }

    fun normalizedCatalogGame(machine: OwnedMachine): GameRoomCatalogGame? {
        val exact = resolvedOpdbId(machine) ?: return null
        return catalogGameForExactOpdbId(exact)
    }

    fun imageCandidates(machine: OwnedMachine): List<String> {
        val normalizedExactOPDBID = normalizedCatalogGameID(resolvedOpdbId(machine).orEmpty())
        val grouped = gamesByCatalogGameID[machine.catalogGameID]
            ?: gamesByNormalizedCatalogGameID[normalizedCatalogGameID(machine.catalogGameID)]
            ?: emptyList()
        val rawCandidates = mutableListOf<String>()
        val normalizedVariant = normalizeVariantLabel(machine.displayVariant)
        val normalizedTitle = parseCatalogName(
            title = machine.displayTitle,
            explicitVariant = machine.displayVariant,
        ).displayTitle.trim().lowercase()

        if (normalizedExactOPDBID.isNotBlank()) {
            val exactMachineMatches = allCatalogGames.filter {
                normalizedCatalogGameID(it.opdbID) == normalizedExactOPDBID
            }
            rawCandidates.addAll(exactMachineMatches.mapNotNull { it.primaryImageUrl })
        }

        if (grouped.isEmpty() && rawCandidates.isEmpty()) return emptyList()

        if (normalizedVariant != null) {
            val variantMatches = grouped.filter {
                variantMatchesSelection(it.displayVariant, normalizedVariant)
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

    private fun catalogGameForExactOpdbId(opdbID: String): GameRoomCatalogGame? {
        val normalized = normalizedCatalogGameID(opdbID)
        if (normalized.isBlank()) return null
        return allCatalogGames.firstOrNull { normalizedCatalogGameID(it.opdbID) == normalized }
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
        opdbID: String? = null,
        selectedVariant: String?,
        selectedTitle: String? = null,
        selectedYear: Int? = null,
    ): GameRoomCatalogArt? {
        val normalizedExactOPDBID = opdbID?.trim().orEmpty()
        val exactRecords = if (normalizedExactOPDBID.isBlank()) {
            emptyList()
        } else {
            machineRecordsByCatalogGameID.values
                .flatten()
                .filter { it.opdbID.equals(normalizedExactOPDBID, ignoreCase = true) }
        }
        val normalizedID = catalogGameID.trim()
        if (normalizedID.isBlank() && exactRecords.isEmpty()) return null
        val records = if (exactRecords.isNotEmpty()) {
            exactRecords
        } else {
            machineRecordsByCatalogGameID[normalizedID]
            ?: machineRecordsByCatalogGameID.entries.firstOrNull { (key, _) ->
                key.equals(normalizedID, ignoreCase = true)
            }?.value
            ?: emptyList()
        }
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

    private fun sanitizeVariantOptions(values: List<String>): List<String> {
        val normalized = values.mapNotNull(::normalizeVariantLabel).toMutableSet()
        if ("Premium/LE" !in normalized) {
            return normalized.toList()
        }
        normalized.remove("Premium/LE")
        normalized += "Premium"
        normalized += "LE"
        return normalized.toList()
    }

    private fun variantMatchesSelection(candidate: String?, selected: String?): Boolean {
        val normalizedCandidate = normalizeVariantLabel(candidate)?.lowercase() ?: return false
        val normalizedSelected = normalizeVariantLabel(selected)?.lowercase() ?: return false
        if (normalizedCandidate == normalizedSelected) return true
        if (normalizedCandidate == "premium/le") {
            return normalizedSelected == "premium" || normalizedSelected == "le"
        }
        return false
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
