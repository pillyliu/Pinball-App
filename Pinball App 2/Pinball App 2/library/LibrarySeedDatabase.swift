import Foundation
import SQLite3

actor LibrarySeedDatabase {
    static let shared = LibrarySeedDatabase()

    private let fileManager = FileManager.default
    private let seedFileName = "pinball_library_seed_v1.sqlite"
    private let starterBundleName = "PinballStarter"
    private let starterBundleExtension = "bundle"

    func loadExtraction() async throws -> LegacyCatalogExtraction {
        let databaseURL = try ensureDatabaseReady()
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            throw SeedDatabaseError.openDatabase(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_close(database) }

        let builtInSources = try loadBuiltInSources(database)
        let builtInGames = try loadBuiltInGames(database)
        let importedSources = await MainActor.run { PinballImportedSourcesStore.load() }
        let importedGames = try loadImportedGames(database, importedSources: importedSources)

        let payload = PinballLibraryPayload(
            games: builtInGames + importedGames,
            sources: dedupedSources(builtInSources + importedSources.map {
                PinballLibrarySource(id: $0.id, name: $0.name, type: $0.type)
            })
        )
        let state = await MainActor.run { PinballLibrarySourceStateStore.synchronize(with: payload.sources) }
        let enabled = Set(state.enabledSourceIDs)
        let filteredSources = payload.sources.filter { enabled.contains($0.id) }
        let filteredSourceIDs = Set(filteredSources.map(\.id))
        let filteredGames = payload.games.filter { filteredSourceIDs.contains($0.sourceId) }
        return LegacyCatalogExtraction(payload: PinballLibraryPayload(games: filteredGames, sources: filteredSources), state: state)
    }

    func loadManufacturerOptions() async throws -> [PinballCatalogManufacturerOption] {
        let databaseURL = try ensureDatabaseReady()
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            throw SeedDatabaseError.openDatabase(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT
            manufacturers.id,
            manufacturers.name,
            COUNT(DISTINCT COALESCE(machines.opdb_group_id, machines.practice_identity)) AS group_count,
            manufacturers.is_modern,
            manufacturers.featured_rank,
            manufacturers.sort_bucket
        FROM manufacturers
        LEFT JOIN machines ON machines.manufacturer_id = manufacturers.id
        GROUP BY manufacturers.id, manufacturers.name, manufacturers.is_modern, manufacturers.featured_rank, manufacturers.sort_bucket
        ORDER BY sort_bucket ASC, COALESCE(featured_rank, 9999) ASC, sort_name ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [PinballCatalogManufacturerOption] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            out.append(
                PinballCatalogManufacturerOption(
                    id: sqliteString(statement, index: 0) ?? "",
                    name: sqliteString(statement, index: 1) ?? "",
                    gameCount: sqliteInt(statement, index: 2) ?? 0,
                    isModern: (sqliteInt(statement, index: 3) ?? 0) > 0,
                    featuredRank: sqliteInt(statement, index: 4),
                    sortBucket: sqliteInt(statement, index: 5) ?? 2
                )
            )
        }
        return out
    }

    private func ensureDatabaseReady() throws -> URL {
        let localURL = try localDatabaseURL()
        let bundledURL = try bundledDatabaseURL()

        if !fileManager.fileExists(atPath: localURL.path) {
            try fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: bundledURL, to: localURL)
            return localURL
        }

        let bundledDate = (try? bundledURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let localDate = (try? localURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        if bundledDate > localDate {
            try? fileManager.removeItem(at: localURL)
            try fileManager.copyItem(at: bundledURL, to: localURL)
        }

        return localURL
    }

    private func localDatabaseURL() throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent(seedFileName)
    }

    private func bundledDatabaseURL() throws -> URL {
        guard let starterBundleURL = Bundle.main.url(forResource: starterBundleName, withExtension: starterBundleExtension) else {
            throw SeedDatabaseError.missingBundle
        }
        let url = starterBundleURL.appendingPathComponent("pinball/data/\(seedFileName)")
        guard fileManager.fileExists(atPath: url.path) else {
            throw SeedDatabaseError.missingSeed
        }
        return url
    }

    private func loadBuiltInSources(_ database: OpaquePointer) throws -> [PinballLibrarySource] {
        let sql = "SELECT id, name, type FROM built_in_sources ORDER BY sort_rank ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [PinballLibrarySource] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            out.append(
                PinballLibrarySource(
                    id: sqliteString(statement, index: 0) ?? "",
                    name: sqliteString(statement, index: 1) ?? "",
                    type: parseSeedSourceType(sqliteString(statement, index: 2))
                )
            )
        }
        return out
    }

    private func loadBuiltInGames(_ database: OpaquePointer) throws -> [PinballGame] {
        let rulesheetsByEntry = try loadBuiltInRulesheets(database)
        let videosByEntry = try loadBuiltInVideos(database)
        let machines = try loadCatalogMachines(database)
        let machinesByPracticeIdentity = Dictionary(grouping: machines, by: \.practiceIdentity)
        let machinesByOPDBID: [String: SeedCatalogMachineRow] = Dictionary(uniqueKeysWithValues: machines.compactMap { machine in
            guard let opdbMachineID = machine.opdbMachineID else { return nil }
            return (opdbMachineID, machine)
        })
        return try loadBuiltInGameRows(database).map { row in
            let resolvedMachine = preferredSeedMachineForBuiltInGame(
                requestedMachineID: row.opdbID,
                practiceIdentity: row.practiceIdentity,
                machinesByPracticeIdentity: machinesByPracticeIdentity,
                machinesByOPDBID: machinesByOPDBID
            )
            return PinballGame(
                record: seedBuiltInResolvedRecord(
                    row: row,
                    resolvedMachine: resolvedMachine,
                    rulesheetLinks: rulesheetsByEntry[row.libraryEntryID] ?? [],
                    videos: videosByEntry[row.libraryEntryID] ?? []
                )
            )
        }
    }

    private func preferredSeedMachineForBuiltInGame(
        requestedMachineID: String?,
        practiceIdentity: String,
        machinesByPracticeIdentity: [String: [SeedCatalogMachineRow]],
        machinesByOPDBID: [String: SeedCatalogMachineRow]
    ) -> SeedCatalogMachineRow? {
        let preferredGroupMachine = preferredSeedGroupMachine(machinesByPracticeIdentity[practiceIdentity] ?? [])

        guard let requestedMachineID,
              let exactMachine = machinesByOPDBID[requestedMachineID] else {
            return preferredGroupMachine
        }

        if seedMachineHasPrimaryImage(exactMachine) {
            return exactMachine
        }

        let preferredExactGroupMachine = preferredSeedGroupMachine(machinesByPracticeIdentity[exactMachine.practiceIdentity] ?? [])
        return preferredExactGroupMachine ?? preferredGroupMachine ?? exactMachine
    }

    private func loadBuiltInRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        try loadEntryScopedRulesheetLinks(database, tableName: "built_in_rulesheet_links")
    }

    private func loadBuiltInVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        try loadEntryScopedVideos(database, tableName: "built_in_videos")
    }

    private func loadBuiltInGameRows(_ database: OpaquePointer) throws -> [SeedBuiltInGameRow] {
        let sql = """
        SELECT
            library_entry_id, source_id, source_name, source_type, practice_identity, opdb_id,
            area, area_order, group_number, position, bank, name, variant, manufacturer, year, slug,
            primary_image_url, primary_image_large_url, playfield_image_url, playfield_local_path,
            playfield_source_label, gameinfo_local_path, rulesheet_local_path, rulesheet_url
        FROM built_in_games
        ORDER BY source_name ASC, COALESCE(area_order, 9999) ASC, COALESCE(group_number, 9999) ASC, COALESCE(position, 9999) ASC, name ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var rows: [SeedBuiltInGameRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let libraryEntryID = sqliteString(statement, index: 0) ?? UUID().uuidString
            let opdbID = sqliteString(statement, index: 5)
            rows.append(
                SeedBuiltInGameRow(
                    libraryEntryID: libraryEntryID,
                    sourceID: sqliteString(statement, index: 1) ?? "",
                    sourceName: sqliteString(statement, index: 2) ?? "",
                    sourceType: parseSeedSourceType(sqliteString(statement, index: 3)),
                    practiceIdentity: sqliteString(statement, index: 4) ?? (opdbID?.components(separatedBy: "-").first ?? libraryEntryID),
                    opdbID: opdbID,
                    area: sqliteString(statement, index: 6),
                    areaOrder: sqliteInt(statement, index: 7),
                    groupNumber: sqliteInt(statement, index: 8),
                    position: sqliteInt(statement, index: 9),
                    bank: sqliteInt(statement, index: 10),
                    name: sqliteString(statement, index: 11) ?? "",
                    variant: sqliteString(statement, index: 12),
                    manufacturer: sqliteString(statement, index: 13),
                    year: sqliteInt(statement, index: 14),
                    slug: sqliteString(statement, index: 15) ?? "",
                    primaryImageURL: sqliteString(statement, index: 16),
                    primaryImageLargeURL: sqliteString(statement, index: 17),
                    playfieldImageURL: sqliteString(statement, index: 18),
                    playfieldLocalPath: sqliteString(statement, index: 19),
                    playfieldSourceLabel: sqliteString(statement, index: 20),
                    gameinfoLocalPath: sqliteString(statement, index: 21),
                    rulesheetLocalPath: sqliteString(statement, index: 22),
                    rulesheetURL: sqliteString(statement, index: 23)
                )
            )
        }
        return rows
    }

    private func loadImportedGames(_ database: OpaquePointer, importedSources: [PinballImportedSourceRecord]) throws -> [PinballGame] {
        guard !importedSources.isEmpty else { return [] }

        let machines = try loadCatalogMachines(database)
        let manufacturersByID = try loadManufacturerRecords(database)
        let overridesByPractice = try loadOverrides(database)
        let overrideRulesheets = try loadOverrideRulesheets(database)
        let overrideVideos = try loadOverrideVideos(database)
        let catalogRulesheets = try loadCatalogRulesheetRecords(database)
        let catalogVideos = try loadCatalogVideoRecords(database)
        let catalogMachines = machines.map(catalogMachineRecord(from:))
        let catalogMachinesByPracticeIdentity = Dictionary(grouping: catalogMachines, by: \.practiceIdentity)
        let catalogMachinesByOPDBID: [String: CatalogMachineRecord] = Dictionary(uniqueKeysWithValues: catalogMachines.compactMap { machine in
            guard let opdbMachineID = machine.opdbMachineID else { return nil }
            return (opdbMachineID, machine)
        })

        var games: [PinballGame] = []
        for source in importedSources {
            let sourceMachines: [CatalogMachineRecord]
            switch source.type {
            case .manufacturer:
                let grouped = Dictionary(grouping: catalogMachines.filter { $0.manufacturerID == source.providerSourceID }) {
                    $0.opdbGroupID ?? $0.practiceIdentity
                }
                sourceMachines = grouped.values.compactMap { group in
                    group.min(by: catalogPreferredManufacturerMachine)
                }
                .sorted {
                    ($0.year ?? Int.max, $0.name.lowercased(), $0.opdbMachineID ?? $0.practiceIdentity)
                        < ($1.year ?? Int.max, $1.name.lowercased(), $1.opdbMachineID ?? $1.practiceIdentity)
                }
            case .venue, .tournament:
                sourceMachines = source.machineIDs.compactMap { machineID in
                    catalogPreferredMachineForSourceLookup(
                        requestedMachineID: machineID,
                        machineByOPDBID: catalogMachinesByOPDBID,
                        machineByPracticeIdentity: catalogMachinesByPracticeIdentity
                    )
                }
            case .category:
                sourceMachines = []
            }

            for machine in sourceMachines {
                let curatedOverride = seedLegacyCuratedOverride(
                    row: overridesByPractice[machine.practiceIdentity],
                    rulesheetLinks: overrideRulesheets[machine.practiceIdentity] ?? [],
                    videos: overrideVideos[machine.practiceIdentity] ?? []
                )
                games.append(
                    resolveImportedGame(
                        machine: machine,
                        source: source,
                        manufacturerByID: manufacturersByID,
                        curatedOverride: curatedOverride,
                        opdbRulesheets: catalogRulesheets[machine.practiceIdentity] ?? [],
                        opdbVideos: catalogVideos[machine.practiceIdentity] ?? []
                    )
                )
            }
        }

        return games
    }

    private func loadCatalogMachines(_ database: OpaquePointer) throws -> [SeedCatalogMachineRow] {
        let sql = """
        SELECT practice_identity, opdb_machine_id, opdb_group_id, slug, name, variant, manufacturer_id, manufacturer_name, year,
               primary_image_medium_url, primary_image_large_url, playfield_image_medium_url, playfield_image_large_url
        FROM machines
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var rows: [SeedCatalogMachineRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(
                SeedCatalogMachineRow(
                    practiceIdentity: sqliteString(statement, index: 0) ?? "",
                    opdbMachineID: sqliteString(statement, index: 1),
                    opdbGroupID: sqliteString(statement, index: 2),
                    slug: sqliteString(statement, index: 3) ?? "",
                    name: sqliteString(statement, index: 4) ?? "",
                    variant: sqliteString(statement, index: 5),
                    manufacturerID: sqliteString(statement, index: 6),
                    manufacturerName: sqliteString(statement, index: 7),
                    year: sqliteInt(statement, index: 8),
                    primaryImageMediumURL: sqliteString(statement, index: 9),
                    primaryImageLargeURL: sqliteString(statement, index: 10),
                    playfieldImageMediumURL: sqliteString(statement, index: 11),
                    playfieldImageLargeURL: sqliteString(statement, index: 12)
                )
            )
        }
        return rows
    }

    private func loadManufacturerRecords(_ database: OpaquePointer) throws -> [String: CatalogManufacturerRecord] {
        let sql = "SELECT id, name FROM manufacturers"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: CatalogManufacturerRecord] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = sqliteString(statement, index: 0), let name = sqliteString(statement, index: 1) {
                out[id] = CatalogManufacturerRecord(id: id, name: name, isModern: nil, featuredRank: nil, gameCount: nil)
            }
        }
        return out
    }

    private func loadOverrides(_ database: OpaquePointer) throws -> [String: SeedOverrideRow] {
        let sql = """
        SELECT practice_identity, name_override, variant_override, manufacturer_override, year_override,
               playfield_local_path, playfield_source_url, gameinfo_local_path, rulesheet_local_path
        FROM overrides
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: SeedOverrideRow] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let row = SeedOverrideRow(
                practiceIdentity: sqliteString(statement, index: 0) ?? "",
                nameOverride: sqliteString(statement, index: 1),
                variantOverride: sqliteString(statement, index: 2),
                manufacturerOverride: sqliteString(statement, index: 3),
                yearOverride: sqliteInt(statement, index: 4),
                playfieldLocalPath: sqliteString(statement, index: 5),
                playfieldSourceURL: sqliteString(statement, index: 6),
                gameinfoLocalPath: sqliteString(statement, index: 7),
                rulesheetLocalPath: sqliteString(statement, index: 8)
            )
            out[row.practiceIdentity] = row
        }
        return out
    }

    private func loadOverrideRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        try loadPracticeScopedRulesheetLinks(database, tableName: "override_rulesheet_links")
    }

    private func loadOverrideVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        try loadPracticeScopedVideos(database, tableName: "override_videos")
    }

    private func loadCatalogRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        try loadPracticeScopedRulesheetLinks(database, tableName: "catalog_rulesheet_links")
    }

    private func loadCatalogRulesheetRecords(_ database: OpaquePointer) throws -> [String: [CatalogRulesheetLinkRecord]] {
        try loadCatalogRulesheetRecords(database)
    }

    private func loadCatalogVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        try loadPracticeScopedVideos(database, tableName: "catalog_video_links")
    }

    private func loadCatalogVideoRecords(_ database: OpaquePointer) throws -> [String: [CatalogVideoLinkRecord]] {
        try loadCatalogVideoRecords(database)
    }

    private func dedupedSources(_ sources: [PinballLibrarySource]) -> [PinballLibrarySource] {
        var seen = Set<String>()
        return sources.filter { seen.insert($0.id).inserted }
    }
}
