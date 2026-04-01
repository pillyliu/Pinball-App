package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.refreshHostedResourcesIfNeeded
import com.pillyliu.pinprofandroid.data.refreshRedactedPlayersFromCsv
import com.pillyliu.pinprofandroid.league.LeaguePreviewRefreshEvents
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

internal const val HOSTED_LIBRARY_REFRESH_INTERVAL_MS = 24L * 60L * 60L * 1000L
internal const val hostedOPDBExportPath = "/pinball/data/opdb_export.json"
internal const val hostedPracticeIdentityCurationsPath = "/pinball/data/practice_identity_curations_v1.json"
internal const val hostedRulesheetAssetsPath = "/pinball/data/rulesheet_assets.json"
internal const val hostedVideoAssetsPath = "/pinball/data/video_assets.json"
internal const val hostedPlayfieldAssetsPath = "/pinball/data/playfield_assets.json"
internal const val hostedGameinfoAssetsPath = "/pinball/data/gameinfo_assets.json"
internal const val hostedBackglassAssetsPath = "/pinball/data/backglass_assets.json"
internal const val hostedVenueLayoutAssetsPath = "/pinball/data/venue_layout_assets.json"
internal const val hostedRedactedPlayersCsvPath = "/pinball/data/redacted_players.csv"
internal const val hostedLeagueStandingsPath = "/pinball/data/LPL_Standings.csv"
internal const val hostedLeagueStatsPath = "/pinball/data/LPL_Stats.csv"
internal const val hostedLeagueTargetsPath = "/pinball/data/LPL_Targets.csv"
internal const val hostedLeagueIfpaPlayersPath = "/pinball/data/LPL_IFPA_Players.csv"
internal const val hostedResolvedLeagueTargetsPath = "/pinball/data/lpl_targets_resolved_v1.json"
internal const val hostedLeagueMachineMappingsPath = "/pinball/data/lpl_machine_mappings_v1.json"
internal val HOSTED_LIBRARY_PATHS = listOf(
    hostedOPDBExportPath,
    hostedPracticeIdentityCurationsPath,
    hostedRulesheetAssetsPath,
    hostedVideoAssetsPath,
    hostedPlayfieldAssetsPath,
    hostedGameinfoAssetsPath,
    hostedBackglassAssetsPath,
    hostedVenueLayoutAssetsPath,
)
internal val HOSTED_CAF_DATA_PATH_SET = HOSTED_LIBRARY_PATHS.toSet()
internal val HOSTED_LEAGUE_REFRESH_NOTIFICATION_PATHS = setOf(
    hostedLeagueStandingsPath,
    hostedLeagueStatsPath,
    hostedLeagueTargetsPath,
    hostedLeagueIfpaPlayersPath,
    hostedResolvedLeagueTargetsPath,
    hostedLeagueMachineMappingsPath,
)

internal data class HostedPinballRefreshTarget(
    val path: String,
    val allowMissing: Boolean,
)

internal val HOSTED_PINBALL_REFRESH_TARGETS = listOf(
    HostedPinballRefreshTarget(path = hostedOPDBExportPath, allowMissing = false),
    HostedPinballRefreshTarget(path = hostedPracticeIdentityCurationsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedRulesheetAssetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedVideoAssetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedPlayfieldAssetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedGameinfoAssetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedBackglassAssetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedVenueLayoutAssetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedLeagueStandingsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedLeagueStatsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedLeagueTargetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedLeagueIfpaPlayersPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedResolvedLeagueTargetsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedLeagueMachineMappingsPath, allowMissing = true),
    HostedPinballRefreshTarget(path = hostedRedactedPlayersCsvPath, allowMissing = true),
)

internal suspend fun loadHostedLibraryExtraction(
    context: Context,
    filterBySourceState: Boolean = true,
): LibraryExtraction = coroutineScope {
    val opdbExportText = loadHostedOrCachedPinballText(hostedOPDBExportPath, allowMissing = false)
        ?: error("Missing OPDB export")
    val practiceIdentityCurationsText = async {
        loadHostedOrCachedPinballText(hostedPracticeIdentityCurationsPath, allowMissing = true)
    }
    val rulesheetAssetsText = async {
        loadHostedOrCachedPinballText(hostedRulesheetAssetsPath, allowMissing = true)
    }
    val videoAssetsText = async {
        loadHostedOrCachedPinballText(hostedVideoAssetsPath, allowMissing = true)
    }
    val playfieldAssetsText = async {
        loadHostedOrCachedPinballText(hostedPlayfieldAssetsPath, allowMissing = true)
    }
    val gameinfoAssetsText = async {
        loadHostedOrCachedPinballText(hostedGameinfoAssetsPath, allowMissing = true)
    }
    val venueLayoutAssetsText = async {
        loadHostedOrCachedPinballText(hostedVenueLayoutAssetsPath, allowMissing = true)
    }

    buildCAFLibraryExtraction(
        context = context,
        opdbExportRaw = opdbExportText,
        practiceIdentityCurationsRaw = practiceIdentityCurationsText.await(),
        rulesheetAssetsRaw = rulesheetAssetsText.await(),
        videoAssetsRaw = videoAssetsText.await(),
        playfieldAssetsRaw = playfieldAssetsText.await(),
        gameinfoAssetsRaw = gameinfoAssetsText.await(),
        venueLayoutAssetsRaw = venueLayoutAssetsText.await(),
        filterBySourceState = filterBySourceState,
    )
}

internal suspend fun warmHostedCAFData() {
    PinballPerformanceTrace.measureSuspend(
        name = "HostedCAFWarmup",
        detail = "count=${HOSTED_LIBRARY_PATHS.size}",
    ) {
        HOSTED_LIBRARY_PATHS.forEach { path ->
            PinballPerformanceTrace.measureSuspend(
                name = "HostedCAFAssetLoad",
                detail = path,
            ) {
                loadHostedOrCachedPinballText(
                    path = path,
                    allowMissing = path != hostedOPDBExportPath,
                )
            }
        }
    }
}

internal suspend fun refreshHostedPinballDataIfNeeded() {
    try {
        val changedPaths = PinballDataCache.refreshHostedResourcesIfNeeded(
            targets = HOSTED_PINBALL_REFRESH_TARGETS,
        )
        if (changedPaths.isEmpty()) return

        if (hostedRedactedPlayersCsvPath in changedPaths) {
            refreshRedactedPlayersFromCsv()
        }
        if (changedPaths.any(HOSTED_CAF_DATA_PATH_SET::contains)) {
            LibrarySourceEvents.notifyChanged()
        }
        if (changedPaths.any(HOSTED_LEAGUE_REFRESH_NOTIFICATION_PATHS::contains)) {
            LeaguePreviewRefreshEvents.notifyChanged()
        }
    } catch (_: Throwable) {
        // Keep cached data if selective refresh fails.
    }
}

private suspend fun loadHostedOrCachedPinballText(
    path: String,
    allowMissing: Boolean,
    maxCacheAgeMs: Long = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
): String? {
    val cached = PinballDataCache.loadText(
        url = path,
        allowMissing = allowMissing,
        maxCacheAgeMs = maxCacheAgeMs,
    )
    return cached.text?.takeIf { it.isNotBlank() }
}

@Suppress("UNUSED_PARAMETER")
internal suspend fun loadHostedCatalogManufacturerOptions(context: Context): List<CatalogManufacturerOption> {
    val hostedText = loadHostedOrCachedPinballText(
        path = hostedOPDBExportPath,
        allowMissing = true,
    ) ?: return emptyList()
    val practiceIdentityCurationsText = loadHostedOrCachedPinballText(
        path = hostedPracticeIdentityCurationsPath,
        allowMissing = true,
    )
    return decodeCatalogManufacturerOptionsFromOPDBExport(hostedText, practiceIdentityCurationsText)
}
