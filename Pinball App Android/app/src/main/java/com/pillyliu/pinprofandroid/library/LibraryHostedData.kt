package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.data.PinballDataCache

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
): LegacyCatalogExtraction {
    val opdbExportText = loadHostedOrCachedPinballText(hostedOPDBExportPath, allowMissing = false)
        ?: error("Missing OPDB export")
    val practiceIdentityCurationsText = loadHostedOrCachedPinballText(hostedPracticeIdentityCurationsPath, allowMissing = true)
    val rulesheetAssetsText = loadHostedOrCachedPinballText(hostedRulesheetAssetsPath, allowMissing = true)
    val videoAssetsText = loadHostedOrCachedPinballText(hostedVideoAssetsPath, allowMissing = true)
    val playfieldAssetsText = loadHostedOrCachedPinballText(hostedPlayfieldAssetsPath, allowMissing = true)
    val gameinfoAssetsText = loadHostedOrCachedPinballText(hostedGameinfoAssetsPath, allowMissing = true)
    val venueLayoutAssetsText = loadHostedOrCachedPinballText(hostedVenueLayoutAssetsPath, allowMissing = true)

    return buildCAFLibraryExtraction(
        context = context,
        opdbExportRaw = opdbExportText,
        practiceIdentityCurationsRaw = practiceIdentityCurationsText,
        rulesheetAssetsRaw = rulesheetAssetsText,
        videoAssetsRaw = videoAssetsText,
        playfieldAssetsRaw = playfieldAssetsText,
        gameinfoAssetsRaw = gameinfoAssetsText,
        venueLayoutAssetsRaw = venueLayoutAssetsText,
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
