import Foundation
import SQLite3

extension LibrarySeedDatabase {
    func loadBuiltInGames(_ database: OpaquePointer) throws -> [PinballGame] {
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
                requestedVariant: row.variant,
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

    func loadImportedGames(_ database: OpaquePointer, importedSources: [PinballImportedSourceRecord]) throws -> [PinballGame] {
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

    func preferredSeedMachineForBuiltInGame(
        requestedMachineID: String?,
        requestedVariant: String?,
        practiceIdentity: String,
        machinesByPracticeIdentity: [String: [SeedCatalogMachineRow]],
        machinesByOPDBID: [String: SeedCatalogMachineRow]
    ) -> SeedCatalogMachineRow? {
        let groupCandidates = machinesByPracticeIdentity[practiceIdentity] ?? []
        let preferredGroupMachine = preferredSeedGroupMachine(groupCandidates)
        let groupArtFallback = groupCandidates
            .filter(seedMachineHasPrimaryImage)
            .min(by: preferredManufacturerMachine)
        let normalizedRequestedVariant = requestedVariant?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let requestedMachineID,
              let exactMachine = machinesByOPDBID[requestedMachineID] else {
            if let variantMatch = preferredSeedMachineForVariant(
                candidates: groupCandidates,
                requestedVariant: normalizedRequestedVariant
            ),
               seedMachineHasPrimaryImage(variantMatch) {
                return variantMatch
            }
            if let preferredGroupMachine, seedMachineHasPrimaryImage(preferredGroupMachine) {
                return preferredGroupMachine
            }
            if let groupArtFallback {
                return groupArtFallback
            }
            return preferredGroupMachine
        }

        let variantCandidates = machinesByPracticeIdentity[exactMachine.practiceIdentity] ?? groupCandidates
        let variantMatch = preferredSeedMachineForVariant(
            candidates: variantCandidates,
            requestedVariant: normalizedRequestedVariant
        )
        if let variantMatch, seedMachineHasPrimaryImage(variantMatch) {
            return variantMatch
        }

        if seedMachineHasPrimaryImage(exactMachine) {
            return exactMachine
        }

        let preferredExactGroupMachine = preferredSeedGroupMachine(machinesByPracticeIdentity[exactMachine.practiceIdentity] ?? [])
        if let preferredExactGroupMachine, seedMachineHasPrimaryImage(preferredExactGroupMachine) {
            return preferredExactGroupMachine
        }
        if let preferredGroupMachine, seedMachineHasPrimaryImage(preferredGroupMachine) {
            return preferredGroupMachine
        }
        if let groupArtFallback {
            return groupArtFallback
        }
        return preferredExactGroupMachine ?? preferredGroupMachine ?? variantMatch ?? exactMachine
    }

    func loadBuiltInRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        try loadEntryScopedRulesheetLinks(database, tableName: "built_in_rulesheet_links")
    }

    func loadBuiltInVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        try loadEntryScopedVideos(database, tableName: "built_in_videos")
    }

    func loadBuiltInGameRows(_ database: OpaquePointer) throws -> [SeedBuiltInGameRow] {
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

    func loadCatalogMachines(_ database: OpaquePointer) throws -> [SeedCatalogMachineRow] {
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
                    variant: catalogResolvedVariantLabel(
                        title: sqliteString(statement, index: 4) ?? "",
                        explicitVariant: sqliteString(statement, index: 5)
                    ),
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

    func loadManufacturerRecords(_ database: OpaquePointer) throws -> [String: CatalogManufacturerRecord] {
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

    func loadOverrides(_ database: OpaquePointer) throws -> [String: SeedOverrideRow] {
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

    func loadOverrideRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        try loadPracticeScopedRulesheetLinks(database, tableName: "override_rulesheet_links")
    }

    func loadOverrideVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        try loadPracticeScopedVideos(database, tableName: "override_videos")
    }

    func loadCatalogRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        try loadPracticeScopedRulesheetLinks(database, tableName: "catalog_rulesheet_links")
    }

    func loadCatalogRulesheetRecordsForPractice(_ database: OpaquePointer) throws -> [String: [CatalogRulesheetLinkRecord]] {
        try loadCatalogRulesheetRecords(database)
    }

    func loadCatalogVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        try loadPracticeScopedVideos(database, tableName: "catalog_video_links")
    }

    func loadCatalogVideoRecordsForPractice(_ database: OpaquePointer) throws -> [String: [CatalogVideoLinkRecord]] {
        try loadCatalogVideoRecords(database)
    }
}
