package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.hostedOPDBExportPath
import com.pillyliu.pinprofandroid.library.hostedPracticeIdentityCurationsPath
import kotlinx.coroutines.runBlocking

internal class GameRoomCatalogLoader {
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

    private val resolutionContext: GameRoomCatalogResolutionContext
        get() = GameRoomCatalogResolutionContext(
            allCatalogGames = allCatalogGames,
            gamesByCatalogGameID = gamesByCatalogGameID,
            gamesByNormalizedCatalogGameID = gamesByNormalizedCatalogGameID,
            machineRecordsByCatalogGameID = machineRecordsByCatalogGameID,
        )

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
        val practiceIdentityCurationsRaw = runBlocking {
            PinballDataCache.loadText(
                url = hostedPracticeIdentityCurationsPath,
                allowMissing = true,
            ).text
        }?.takeIf { it.isNotBlank() }
        val loadedCatalog = buildGameRoomLoadedCatalogData(raw, practiceIdentityCurationsRaw)
        allCatalogGames = loadedCatalog.allCatalogGames
        games = loadedCatalog.games
        manufacturers = loadedCatalog.manufacturers
        manufacturerOptions = loadedCatalog.manufacturerOptions
        gamesByCatalogGameID = loadedCatalog.gamesByCatalogGameID
        gamesByNormalizedCatalogGameID = loadedCatalog.gamesByNormalizedCatalogGameID
        variantOptionsByCatalogGameID = loadedCatalog.variantOptionsByCatalogGameID
        variantOptionsByNormalizedCatalogGameID = loadedCatalog.variantOptionsByNormalizedCatalogGameID
        machineRecordsByCatalogGameID = loadedCatalog.machineRecordsByCatalogGameID
        slugMatchesBySlug = loadedCatalog.slugMatchesBySlug
        errorMessage = null
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
        val normalizedVariant = normalizeVariantLabel(variant)
        if (normalizedVariant != null) {
            val grouped = games(catalogGameID)
            val exactMatches = grouped.filter {
                exactVariantMatchesSelection(it.displayVariant, normalizedVariant)
            }
            if (exactMatches.isNotEmpty()) {
                return preferredCatalogGame(exactMatches)
            }
            val matches = grouped.filter {
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
        val grouped = games(machine.catalogGameID)
        return resolvedGameRoomCatalogOpdbId(
            context = resolutionContext,
            machine = machine,
            groupedGames = grouped,
        )
    }

    fun normalizedCatalogGame(machine: OwnedMachine): GameRoomCatalogGame? {
        val exact = resolvedOpdbId(machine) ?: return null
        return gameRoomCatalogGameForExactOpdbId(resolutionContext, exact)
    }

    fun imageCandidates(machine: OwnedMachine): List<String> {
        return gameRoomCatalogImageCandidates(
            context = resolutionContext,
            machine = machine,
            resolvedOpdbId = resolvedOpdbId(machine),
        )
    }

    fun resolvedArt(
        catalogGameID: String,
        opdbID: String? = null,
        selectedVariant: String?,
        selectedTitle: String? = null,
        selectedYear: Int? = null,
    ): GameRoomCatalogArt? {
        return resolveGameRoomCatalogArt(
            context = resolutionContext,
            catalogGameID = catalogGameID,
            opdbID = opdbID,
            selectedVariant = selectedVariant,
            selectedTitle = selectedTitle,
            selectedYear = selectedYear,
        )
    }

}
