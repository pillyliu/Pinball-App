import Foundation

nonisolated let hostedOPDBExportPath = "/pinball/data/opdb_export.json"
nonisolated let hostedRulesheetAssetsPath = "/pinball/data/rulesheet_assets.json"
nonisolated let hostedVideoAssetsPath = "/pinball/data/video_assets.json"
nonisolated let hostedPlayfieldAssetsPath = "/pinball/data/playfield_assets.json"
nonisolated let hostedGameinfoAssetsPath = "/pinball/data/gameinfo_assets.json"
nonisolated let hostedBackglassAssetsPath = "/pinball/data/backglass_assets.json"
nonisolated let hostedVenueLayoutAssetsPath = "/pinball/data/venue_layout_assets.json"
nonisolated let hostedRedactedPlayersCSVPath = "/pinball/data/redacted_players.csv"
nonisolated let hostedLeagueStandingsPath = "/pinball/data/LPL_Standings.csv"
nonisolated let hostedLeagueStatsPath = "/pinball/data/LPL_Stats.csv"
nonisolated let hostedLeagueTargetsPath = "/pinball/data/LPL_Targets.csv"
nonisolated let hostedResolvedLeagueTargetsPath = "/pinball/data/lpl_targets_resolved_v1.json"
nonisolated let hostedCAFDataPaths = [
    hostedOPDBExportPath,
    hostedRulesheetAssetsPath,
    hostedVideoAssetsPath,
    hostedPlayfieldAssetsPath,
    hostedGameinfoAssetsPath,
    hostedBackglassAssetsPath,
    hostedVenueLayoutAssetsPath,
]
nonisolated let hostedPinballRefreshTargets: [(path: String, allowMissing: Bool)] = [
    (hostedOPDBExportPath, false),
    (hostedRulesheetAssetsPath, true),
    (hostedVideoAssetsPath, true),
    (hostedPlayfieldAssetsPath, true),
    (hostedGameinfoAssetsPath, true),
    (hostedBackglassAssetsPath, true),
    (hostedVenueLayoutAssetsPath, true),
    (hostedLeagueStandingsPath, true),
    (hostedLeagueStatsPath, true),
    (hostedLeagueTargetsPath, true),
    (hostedResolvedLeagueTargetsPath, true),
    (hostedRedactedPlayersCSVPath, true),
]

nonisolated private let hostedLibraryRefreshInterval: TimeInterval = 24 * 60 * 60

func loadHostedCatalogManufacturerOptions() async throws -> [PinballCatalogManufacturerOption] {
    if let rawData = try await loadHostedOrCachedPinballJSONData(
        path: hostedOPDBExportPath,
        allowMissing: true
    ),
       !rawData.isEmpty {
        return try decodeCatalogManufacturerOptionsFromOPDBExport(data: rawData)
    }
    return []
}

func warmHostedCAFData() async {
    await PinballPerformanceTrace.measure("HostedCAFWarmup", detail: "count=\(hostedCAFDataPaths.count)") {
        for path in hostedCAFDataPaths {
            _ = try? await PinballPerformanceTrace.measure("HostedCAFAssetLoad", detail: path) {
                try await loadHostedOrCachedPinballJSONData(
                    path: path,
                    allowMissing: path != hostedOPDBExportPath
                )
            }
        }
    }
}

func loadHostedOrCachedPinballJSONData(
    path: String,
    allowMissing: Bool = false,
    maxCacheAge: TimeInterval = hostedLibraryRefreshInterval
) async throws -> Data? {
    let cached = try await PinballDataCache.shared.loadText(
        path: path,
        allowMissing: allowMissing,
        maxCacheAge: maxCacheAge
    )
    if let text = cached.text,
       let data = text.data(using: .utf8),
       !data.isEmpty {
        return data
    }
    return nil
}
