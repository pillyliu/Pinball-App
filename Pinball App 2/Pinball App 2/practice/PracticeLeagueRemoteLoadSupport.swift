import Foundation

extension PracticeStore {
    func loadLeagueStatsSnapshot(forceRefresh: Bool = false) async throws -> LeagueStatsSnapshot {
        let cached: CachedTextResult
        if forceRefresh {
            do {
                cached = try await PinballDataCache.shared.forceRefreshText(path: Self.leagueStatsPath)
            } catch {
                cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            }
        } else {
            cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
        }
        guard let text = cached.text else {
            cachedLeagueStatsUpdatedAt = cached.updatedAt
            cachedLeagueStatsRows = []
            cachedLeaguePlayers = []
            return LeagueStatsSnapshot(rows: [], players: [], updatedAt: cached.updatedAt)
        }

        if cachedLeagueStatsRows.isEmpty || cachedLeagueStatsUpdatedAt != cached.updatedAt {
            let snapshot = PinballPerformanceTrace.measure("PracticeLeagueStatsLoad") {
                let rows = parseLeagueRows(text: text)
                return LeagueStatsSnapshot(
                    rows: rows,
                    players: leaguePlayers(from: rows),
                    updatedAt: cached.updatedAt
                )
            }
            cachedLeagueStatsRows = snapshot.rows
            cachedLeaguePlayers = snapshot.players
            cachedLeagueStatsUpdatedAt = cached.updatedAt
        }

        return LeagueStatsSnapshot(
            rows: cachedLeagueStatsRows,
            players: cachedLeaguePlayers,
            updatedAt: cached.updatedAt
        )
    }

    func loadLeagueIFPAPlayers(forceRefresh: Bool = false) async throws -> [LeagueIFPAPlayerRecord] {
        let cached: CachedTextResult
        if forceRefresh {
            do {
                cached = try await PinballDataCache.shared.forceRefreshText(path: Self.leagueIFPAPlayersPath, allowMissing: true)
            } catch {
                cached = try await PinballDataCache.shared.loadText(path: Self.leagueIFPAPlayersPath, allowMissing: true)
            }
        } else {
            cached = try await PinballDataCache.shared.loadText(path: Self.leagueIFPAPlayersPath, allowMissing: true)
        }

        guard let text = cached.text else {
            cachedLeagueIFPAPlayersUpdatedAt = cached.updatedAt
            cachedLeagueIFPAPlayers = []
            return []
        }

        if cachedLeagueIFPAPlayers.isEmpty || cachedLeagueIFPAPlayersUpdatedAt != cached.updatedAt {
            cachedLeagueIFPAPlayers = parseLeagueIFPAPlayers(text: text)
            cachedLeagueIFPAPlayersUpdatedAt = cached.updatedAt
        }

        return cachedLeagueIFPAPlayers
    }

    func loadLeagueMachineMappings(forceRefresh: Bool = false) async throws -> [String: LeagueMachineMappingRecord] {
        let cached: CachedTextResult
        if forceRefresh {
            do {
                cached = try await PinballDataCache.shared.forceRefreshText(path: Self.leagueMachineMappingsPath, allowMissing: true)
            } catch {
                cached = try await PinballDataCache.shared.loadText(path: Self.leagueMachineMappingsPath, allowMissing: true)
            }
        } else {
            cached = try await PinballDataCache.shared.loadText(path: Self.leagueMachineMappingsPath, allowMissing: true)
        }

        guard let text = cached.text else {
            cachedLeagueMachineMappingsUpdatedAt = cached.updatedAt
            cachedLeagueMachineMappings = [:]
            return [:]
        }

        if cachedLeagueMachineMappings.isEmpty || cachedLeagueMachineMappingsUpdatedAt != cached.updatedAt {
            cachedLeagueMachineMappings = parseLeagueMachineMappings(text: text)
            cachedLeagueMachineMappingsUpdatedAt = cached.updatedAt
        }

        return cachedLeagueMachineMappings
    }
}

