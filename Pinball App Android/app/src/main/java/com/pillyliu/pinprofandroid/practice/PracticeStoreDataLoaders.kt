package com.pillyliu.pinprofandroid.practice

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.PM_AVENUE_LIBRARY_SOURCE_ID
import com.pillyliu.pinprofandroid.library.canonicalLibrarySourceId
import com.pillyliu.pinprofandroid.library.hostedOPDBExportPath
import com.pillyliu.pinprofandroid.library.hostedVenueLayoutAssetsPath
import com.pillyliu.pinprofandroid.library.loadFullLibraryExtraction
import com.pillyliu.pinprofandroid.library.loadLibraryExtraction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal data class PracticeLibraryLoadResult(
    val games: List<PinballGame>,
    val allGames: List<PinballGame>,
    val sources: List<LibrarySource>,
    val defaultSourceId: String?,
    val isFullLibraryScope: Boolean,
)

internal suspend fun loadPracticeGamesFromLibrary(
    context: Context,
    fullLibraryScope: Boolean,
): PracticeLibraryLoadResult = withContext(Dispatchers.IO) {
    try {
        val extraction = if (fullLibraryScope) {
            loadFullLibraryExtraction(context)
        } else {
            loadLibraryExtraction(context)
        }
        val parsed = extraction.payload
        val selectedSource = parsed.sources.firstOrNull { it.id == extraction.state.selectedSourceId }
            ?: parsed.sources.firstOrNull()
        if (selectedSource == null) {
            PracticeLibraryLoadResult(
                games = parsed.games,
                allGames = parsed.games,
                sources = parsed.sources,
                defaultSourceId = null,
                isFullLibraryScope = fullLibraryScope,
            )
        } else {
            PracticeLibraryLoadResult(
                games = parsed.games.filter { it.sourceId == selectedSource.id },
                allGames = parsed.games,
                sources = parsed.sources,
                defaultSourceId = selectedSource.id,
                isFullLibraryScope = fullLibraryScope,
            )
        }
    } catch (_: Throwable) {
        PracticeLibraryLoadResult(
            games = emptyList(),
            allGames = emptyList(),
            sources = emptyList(),
            defaultSourceId = null,
            isFullLibraryScope = fullLibraryScope,
        )
    }
}

internal suspend fun loadLeagueTargetsMap(path: String): Map<String, LeagueTargetScores> = withContext(Dispatchers.IO) {
    try {
        val result = PinballDataCache.loadText(path, allowMissing = true)
        val text = result.text ?: return@withContext emptyMap()
        parseLeagueTargets(text)
    } catch (_: Throwable) {
        emptyMap()
    }
}

internal suspend fun loadResolvedLeagueTargets(path: String): List<ResolvedLeagueTargetRecord> = withContext(Dispatchers.IO) {
    try {
        val result = PinballDataCache.loadText(path, allowMissing = true)
        val text = result.text ?: return@withContext emptyList()
        parseResolvedLeagueTargets(text)
    } catch (_: Throwable) {
        emptyList()
    }
}

internal suspend fun loadPracticeAvenueBankTemplateGames(): List<PinballGame> = withContext(Dispatchers.IO) {
    try {
        val opdbResult = PinballDataCache.loadText(hostedOPDBExportPath, allowMissing = true)
        val venueLayoutResult = PinballDataCache.loadText(hostedVenueLayoutAssetsPath, allowMissing = true)
        val opdbText = opdbResult.text?.takeIf { it.isNotBlank() } ?: return@withContext emptyList()
        val venueLayoutText = venueLayoutResult.text?.takeIf { it.isNotBlank() } ?: return@withContext emptyList()

        val machines = parsePracticeBankTemplateMachines(opdbText)
        val layoutRecords = parsePracticeVenueLayoutRecords(venueLayoutText)
            .filter { canonicalLibrarySourceId(it.sourceId) == PM_AVENUE_LIBRARY_SOURCE_ID }
            .filter { (it.bank ?: 0) > 0 }
            .sortedWith(
                compareBy<PracticeVenueLayoutRecord> { it.bank ?: Int.MAX_VALUE }
                    .thenBy { it.groupNumber ?: Int.MAX_VALUE }
                    .thenBy { it.position ?: Int.MAX_VALUE }
                    .thenBy { it.opdbId.lowercase() },
            )

        val machinesByOpdbId = machines.associateBy { it.opdbId }
        val machinesByPracticeIdentity = machines.groupBy { it.practiceIdentity }
        val seen = linkedSetOf<String>()
        buildList {
            layoutRecords.forEach { record ->
                if (!seen.add(record.opdbId)) return@forEach
                val machine = machinesByOpdbId[record.opdbId]
                    ?: record.practiceIdentity?.let { machinesByPracticeIdentity[it]?.firstOrNull() }
                    ?: return@forEach
                add(
                    PinballGame(
                        libraryEntryId = null,
                        practiceIdentity = record.practiceIdentity ?: machine.practiceIdentity,
                        opdbId = machine.opdbId,
                        opdbGroupId = machine.practiceIdentity,
                        opdbMachineId = machine.opdbId,
                        variant = machine.variant,
                        sourceId = PM_AVENUE_LIBRARY_SOURCE_ID,
                        sourceName = "The Avenue Cafe",
                        sourceType = LibrarySourceType.VENUE,
                        area = record.area,
                        areaOrder = record.areaOrder,
                        group = record.groupNumber,
                        position = record.position,
                        bank = record.bank,
                        name = machine.name,
                        manufacturer = machine.manufacturer,
                        year = machine.year,
                        slug = machine.slug,
                        opdbName = machine.name,
                        primaryImageUrl = machine.primaryImageUrl,
                        primaryImageLargeUrl = machine.primaryImageLargeUrl,
                        playfieldImageUrl = machine.playfieldImageUrl,
                        alternatePlayfieldImageUrl = null,
                        playfieldLocalOriginal = null,
                        playfieldLocal = null,
                        playfieldSourceLabel = if (machine.playfieldImageUrl != null) "Playfield (OPDB)" else null,
                        gameinfoLocal = null,
                        rulesheetLocal = null,
                        rulesheetUrl = null,
                        rulesheetLinks = emptyList(),
                        videos = emptyList(),
                    ),
                )
            }
        }
    } catch (_: Throwable) {
        emptyList()
    }
}

private data class PracticeBankTemplateMachine(
    val practiceIdentity: String,
    val opdbId: String,
    val slug: String,
    val name: String,
    val variant: String?,
    val manufacturer: String?,
    val year: Int?,
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
)

private data class PracticeVenueLayoutRecord(
    val sourceId: String,
    val practiceIdentity: String?,
    val opdbId: String,
    val area: String?,
    val areaOrder: Int?,
    val groupNumber: Int?,
    val position: Int?,
    val bank: Int?,
)

private fun parsePracticeBankTemplateMachines(raw: String): List<PracticeBankTemplateMachine> {
    val root = JSONObject(raw.trim())
    val array = root.optJSONArray("machines") ?: return emptyList()
    return buildList {
        for (index in 0 until array.length()) {
            val obj = array.optJSONObject(index) ?: continue
            val practiceIdentity = obj.optString("practice_identity").trim().takeIf { it.isNotEmpty() } ?: continue
            val opdbId = obj.optString("opdb_machine_id").trim().takeIf { it.isNotEmpty() } ?: continue
            val slug = obj.optString("slug").trim().ifEmpty { practiceIdentity }
            val name = obj.optString("name").trim().takeIf { it.isNotEmpty() } ?: continue
            val variant = obj.optString("variant").trim().takeIf { it.isNotEmpty() }
            val manufacturer = obj.optString("manufacturer_name").trim().takeIf { it.isNotEmpty() }
            val year = if (obj.has("year") && !obj.isNull("year")) obj.optInt("year") else null
            val primary = obj.optJSONObject("primary_image")
            val playfield = obj.optJSONObject("playfield_image")
            add(
                PracticeBankTemplateMachine(
                    practiceIdentity = practiceIdentity,
                    opdbId = opdbId,
                    slug = slug,
                    name = name,
                    variant = variant,
                    manufacturer = manufacturer,
                    year = year,
                    primaryImageUrl = primary?.optString("medium_url")?.trim()?.takeIf { it.isNotEmpty() },
                    primaryImageLargeUrl = primary?.optString("large_url")?.trim()?.takeIf { it.isNotEmpty() },
                    playfieldImageUrl = playfield?.optString("large_url")?.trim()?.takeIf { it.isNotEmpty() }
                        ?: playfield?.optString("medium_url")?.trim()?.takeIf { it.isNotEmpty() },
                ),
            )
        }
    }
}

private fun parsePracticeVenueLayoutRecords(raw: String): List<PracticeVenueLayoutRecord> {
    val root = JSONObject(raw.trim())
    val array = root.optJSONArray("records") ?: return emptyList()
    return buildList {
        for (index in 0 until array.length()) {
            val obj = array.optJSONObject(index) ?: continue
            val sourceId = obj.optString("sourceId").trim().takeIf { it.isNotEmpty() } ?: continue
            val opdbId = obj.optString("opdbId").trim().takeIf { it.isNotEmpty() } ?: continue
            add(
                PracticeVenueLayoutRecord(
                    sourceId = sourceId,
                    practiceIdentity = obj.optString("practiceIdentity").trim().takeIf { it.isNotEmpty() },
                    opdbId = opdbId,
                    area = obj.optString("area").trim().takeIf { it.isNotEmpty() },
                    areaOrder = if (obj.has("areaOrder") && !obj.isNull("areaOrder")) obj.optInt("areaOrder") else null,
                    groupNumber = if (obj.has("group") && !obj.isNull("group")) obj.optInt("group") else null,
                    position = if (obj.has("position") && !obj.isNull("position")) obj.optInt("position") else null,
                    bank = if (obj.has("bank") && !obj.isNull("bank")) obj.optInt("bank") else null,
                ),
            )
        }
    }
}
