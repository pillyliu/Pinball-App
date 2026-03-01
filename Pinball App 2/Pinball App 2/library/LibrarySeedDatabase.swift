import Foundation
import SQLite3

private struct SeedCatalogMachineRow {
    let practiceIdentity: String
    let opdbMachineID: String?
    let opdbGroupID: String?
    let slug: String
    let name: String
    let variant: String?
    let manufacturerID: String?
    let manufacturerName: String?
    let year: Int?
    let primaryImageMediumURL: String?
    let primaryImageLargeURL: String?
    let playfieldImageMediumURL: String?
    let playfieldImageLargeURL: String?
}

private struct SeedOverrideRow {
    let practiceIdentity: String
    let nameOverride: String?
    let variantOverride: String?
    let manufacturerOverride: String?
    let yearOverride: Int?
    let playfieldLocalPath: String?
    let playfieldSourceURL: String?
    let gameinfoLocalPath: String?
    let rulesheetLocalPath: String?
}

nonisolated private func preferredManufacturerMachine(_ lhs: SeedCatalogMachineRow, _ rhs: SeedCatalogMachineRow) -> Bool {
    let lhsHasPrimary = lhs.primaryImageMediumURL != nil || lhs.primaryImageLargeURL != nil
    let rhsHasPrimary = rhs.primaryImageMediumURL != nil || rhs.primaryImageLargeURL != nil
    if lhsHasPrimary != rhsHasPrimary {
        return lhsHasPrimary
    }

    let lhsVariant = lhs.variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let rhsVariant = rhs.variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let lhsHasVariant = !lhsVariant.isEmpty
    let rhsHasVariant = !rhsVariant.isEmpty
    if lhsHasVariant != rhsHasVariant {
        return !lhsHasVariant
    }

    let lhsYear = lhs.year ?? Int.max
    let rhsYear = rhs.year ?? Int.max
    if lhsYear != rhsYear {
        return lhsYear < rhsYear
    }

    let lhsName = lhs.name.lowercased()
    let rhsName = rhs.name.lowercased()
    if lhsName != rhsName {
        return lhsName < rhsName
    }

    return (lhs.opdbMachineID ?? lhs.practiceIdentity) < (rhs.opdbMachineID ?? rhs.practiceIdentity)
}

nonisolated private func seedMachineHasPrimaryImage(_ machine: SeedCatalogMachineRow) -> Bool {
    machine.primaryImageMediumURL != nil || machine.primaryImageLargeURL != nil
}

nonisolated private func preferredSeedGroupMachine(_ group: [SeedCatalogMachineRow]) -> SeedCatalogMachineRow? {
    group.min(by: preferredManufacturerMachine)
}

nonisolated private func dedupeRulesheetLinks(_ links: [PinballGame.ReferenceLink]) -> [PinballGame.ReferenceLink] {
    let grouped = Dictionary(grouping: links, by: \.label)
    return grouped.values.compactMap { group in
        group.min {
            let left = preferredRulesheetRank(for: $0.url)
            let right = preferredRulesheetRank(for: $1.url)
            if left != right { return left < right }
            return $0.url < $1.url
        }
    }
}

nonisolated private func preferredRulesheetRank(for url: String) -> Int {
    let normalized = url.lowercased()
    if normalized.contains("tiltforums.com/t/"), !normalized.contains(".json") {
        return 0
    }
    if normalized.hasPrefix("https://") {
        return 1
    }
    return 2
}

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

        var games: [PinballGame] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let libraryEntryID = sqliteString(statement, index: 0) ?? UUID().uuidString
            let practiceIdentity = sqliteString(statement, index: 4) ?? (sqliteString(statement, index: 5)?.components(separatedBy: "-").first ?? libraryEntryID)
            let resolvedMachine = preferredSeedMachineForBuiltInGame(
                requestedMachineID: sqliteString(statement, index: 5),
                practiceIdentity: practiceIdentity,
                machinesByPracticeIdentity: machinesByPracticeIdentity,
                machinesByOPDBID: machinesByOPDBID
            )
            let primaryImageURL = sqliteString(statement, index: 16)
                ?? resolvedMachine?.primaryImageMediumURL
            let primaryImageLargeURL = sqliteString(statement, index: 17)
                ?? resolvedMachine?.primaryImageLargeURL
            let record = ResolvedCatalogRecord(
                sourceID: sqliteString(statement, index: 1) ?? "",
                sourceName: sqliteString(statement, index: 2) ?? "",
                sourceType: parseSeedSourceType(sqliteString(statement, index: 3)),
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
                opdbID: sqliteString(statement, index: 5),
                practiceIdentity: practiceIdentity,
                primaryImageURL: primaryImageURL,
                primaryImageLargeURL: primaryImageLargeURL,
                playfieldImageURL: sqliteString(statement, index: 18),
                playfieldLocalPath: sqliteString(statement, index: 19),
                playfieldSourceLabel: sqliteString(statement, index: 20),
                gameinfoLocalPath: sqliteString(statement, index: 21),
                rulesheetLocalPath: sqliteString(statement, index: 22),
                rulesheetURL: sqliteString(statement, index: 23),
                rulesheetLinks: rulesheetsByEntry[libraryEntryID] ?? [],
                videos: videosByEntry[libraryEntryID] ?? []
            )
            games.append(PinballGame(record: record))
        }
        return games
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
        let sql = "SELECT library_entry_id, label, url FROM built_in_rulesheet_links ORDER BY library_entry_id ASC, priority ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: [PinballGame.ReferenceLink]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let entryID = sqliteString(statement, index: 0),
                  let label = sqliteString(statement, index: 1),
                  let url = sqliteString(statement, index: 2) else { continue }
            out[entryID, default: []].append(.init(label: label, url: url))
        }
        return out.mapValues(dedupeRulesheetLinks)
    }

    private func loadBuiltInVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        let sql = "SELECT library_entry_id, kind, label, url FROM built_in_videos ORDER BY library_entry_id ASC, priority ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: [PinballGame.Video]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let entryID = sqliteString(statement, index: 0) else { continue }
            out[entryID, default: []].append(
                .init(
                    kind: sqliteString(statement, index: 1),
                    label: sqliteString(statement, index: 2),
                    url: sqliteString(statement, index: 3)
                )
            )
        }
        return out
    }

    private func loadImportedGames(_ database: OpaquePointer, importedSources: [PinballImportedSourceRecord]) throws -> [PinballGame] {
        guard !importedSources.isEmpty else { return [] }

        let machines = try loadCatalogMachines(database)
        let manufacturersByID = try loadManufacturerNames(database)
        let overridesByPractice = try loadOverrides(database)
        let overrideRulesheets = try loadOverrideRulesheets(database)
        let overrideVideos = try loadOverrideVideos(database)
        let catalogRulesheets = try loadCatalogRulesheets(database)
        let catalogVideos = try loadCatalogVideos(database)

        var games: [PinballGame] = []
        for source in importedSources {
            let sourceMachines: [SeedCatalogMachineRow]
            switch source.type {
            case .manufacturer:
                let grouped = Dictionary(grouping: machines.filter { $0.manufacturerID == source.providerSourceID }) {
                    $0.opdbGroupID ?? $0.practiceIdentity
                }
                sourceMachines = grouped.values.compactMap { group in
                    group.min(by: { lhs, rhs in
                        preferredManufacturerMachine(lhs, rhs)
                    })
                }
                .sorted {
                    ($0.year ?? Int.max, $0.name.lowercased(), $0.opdbMachineID ?? "")
                        < ($1.year ?? Int.max, $1.name.lowercased(), $1.opdbMachineID ?? "")
                }
            case .venue:
                let ids = Set(source.machineIDs)
                sourceMachines = machines.filter { machine in
                    if let opdbMachineID = machine.opdbMachineID, ids.contains(opdbMachineID) {
                        return true
                    }
                    return ids.contains(machine.practiceIdentity)
                }
            case .category:
                sourceMachines = []
            }

            for machine in sourceMachines {
                let override = overridesByPractice[machine.practiceIdentity]
                let rulesheetLocalPath = override?.rulesheetLocalPath
                let rulesheetLinks: [PinballGame.ReferenceLink]
                if rulesheetLocalPath != nil {
                    rulesheetLinks = []
                } else if let curated = overrideRulesheets[machine.practiceIdentity], !curated.isEmpty {
                    rulesheetLinks = curated
                } else {
                    rulesheetLinks = catalogRulesheets[machine.practiceIdentity] ?? []
                }
                let videos = overrideVideos[machine.practiceIdentity].flatMap { $0.isEmpty ? nil : $0 }
                    ?? catalogVideos[machine.practiceIdentity]
                    ?? []
                let manufacturerName = override?.manufacturerOverride
                    ?? machine.manufacturerName
                    ?? machine.manufacturerID.flatMap { manufacturersByID[$0] }
                let playfieldLocalPath = override?.playfieldLocalPath
                let playfieldImageURL = override?.playfieldSourceURL ?? machine.playfieldImageLargeURL ?? machine.playfieldImageMediumURL
                let record = ResolvedCatalogRecord(
                    sourceID: source.id,
                    sourceName: source.name,
                    sourceType: source.type,
                    area: nil,
                    areaOrder: nil,
                    groupNumber: nil,
                    position: nil,
                    bank: nil,
                    name: override?.nameOverride ?? machine.name,
                    variant: source.type == .manufacturer ? nil : (override?.variantOverride ?? machine.variant),
                    manufacturer: manufacturerName,
                    year: override?.yearOverride ?? machine.year,
                    slug: machine.slug,
                    opdbID: machine.opdbMachineID,
                    practiceIdentity: machine.practiceIdentity,
                    primaryImageURL: machine.primaryImageMediumURL,
                    primaryImageLargeURL: machine.primaryImageLargeURL,
                    playfieldImageURL: playfieldImageURL,
                    playfieldLocalPath: playfieldLocalPath,
                    playfieldSourceLabel: playfieldLocalPath == nil && playfieldImageURL != nil ? "Playfield (OPDB)" : nil,
                    gameinfoLocalPath: override?.gameinfoLocalPath,
                    rulesheetLocalPath: rulesheetLocalPath,
                    rulesheetURL: rulesheetLinks.first?.url,
                    rulesheetLinks: rulesheetLinks,
                    videos: videos
                )
                games.append(PinballGame(record: record))
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

    private func loadManufacturerNames(_ database: OpaquePointer) throws -> [String: String] {
        let sql = "SELECT id, name FROM manufacturers"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = sqliteString(statement, index: 0), let name = sqliteString(statement, index: 1) {
                out[id] = name
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
        let sql = "SELECT practice_identity, label, url FROM override_rulesheet_links ORDER BY practice_identity ASC, priority ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: [PinballGame.ReferenceLink]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let practiceIdentity = sqliteString(statement, index: 0),
                  let label = sqliteString(statement, index: 1),
                  let url = sqliteString(statement, index: 2) else { continue }
            out[practiceIdentity, default: []].append(.init(label: label, url: url))
        }
        return out.mapValues(dedupeRulesheetLinks)
    }

    private func loadOverrideVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        let sql = "SELECT practice_identity, kind, label, url FROM override_videos ORDER BY practice_identity ASC, priority ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: [PinballGame.Video]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let practiceIdentity = sqliteString(statement, index: 0) else { continue }
            out[practiceIdentity, default: []].append(
                .init(kind: sqliteString(statement, index: 1), label: sqliteString(statement, index: 2), url: sqliteString(statement, index: 3))
            )
        }
        return out
    }

    private func loadCatalogRulesheets(_ database: OpaquePointer) throws -> [String: [PinballGame.ReferenceLink]] {
        let sql = "SELECT practice_identity, label, url FROM catalog_rulesheet_links ORDER BY practice_identity ASC, priority ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: [PinballGame.ReferenceLink]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let practiceIdentity = sqliteString(statement, index: 0),
                  let label = sqliteString(statement, index: 1),
                  let url = sqliteString(statement, index: 2) else { continue }
            out[practiceIdentity, default: []].append(.init(label: label, url: url))
        }
        return out.mapValues(dedupeRulesheetLinks)
    }

    private func loadCatalogVideos(_ database: OpaquePointer) throws -> [String: [PinballGame.Video]] {
        let sql = "SELECT practice_identity, kind, label, url FROM catalog_video_links ORDER BY practice_identity ASC, priority ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        var out: [String: [PinballGame.Video]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let practiceIdentity = sqliteString(statement, index: 0) else { continue }
            out[practiceIdentity, default: []].append(
                .init(kind: sqliteString(statement, index: 1), label: sqliteString(statement, index: 2), url: sqliteString(statement, index: 3))
            )
        }
        return out
    }

    private func dedupedSources(_ sources: [PinballLibrarySource]) -> [PinballLibrarySource] {
        var seen = Set<String>()
        return sources.filter { seen.insert($0.id).inserted }
    }
}

private enum SeedDatabaseError: Error {
    case missingBundle
    case missingSeed
    case openDatabase(message: String)
    case prepareStatement(message: String)
}

nonisolated private func sqliteString(_ statement: OpaquePointer, index: Int32) -> String? {
    guard let cString = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: cString)
}

nonisolated private func sqliteInt(_ statement: OpaquePointer, index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int(statement, index))
}

nonisolated private func currentSQLiteMessage(from database: OpaquePointer?) -> String {
    guard let database, let message = sqlite3_errmsg(database) else { return "Unknown SQLite error" }
    return String(cString: message)
}

nonisolated private func parseSeedSourceType(_ raw: String?) -> PinballLibrarySourceType {
    switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "manufacturer":
        return .manufacturer
    case "category":
        return .category
    default:
        return .venue
    }
}
