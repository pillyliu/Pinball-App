import Foundation
import SQLite3

extension LibrarySeedDatabase {
    func withReadOnlyDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        let databaseURL = try ensureDatabaseReady()
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            throw SeedDatabaseError.openDatabase(message: currentSQLiteMessage(from: database))
        }
        defer { sqlite3_close(database) }
        return try body(database)
    }

    func loadManufacturerOptionsRows(_ database: OpaquePointer) throws -> [PinballCatalogManufacturerOption] {
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

    func loadBuiltInSources(_ database: OpaquePointer) throws -> [PinballLibrarySource] {
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

    func ensureDatabaseReady() throws -> URL {
        let fileManager = FileManager.default
        let seedFileName = "pinball_library_seed_v1.sqlite"
        let localURL = try localDatabaseURL(fileManager: fileManager, seedFileName: seedFileName)
        let bundledURL = try bundledDatabaseURL(fileManager: fileManager, seedFileName: seedFileName)

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
}

private func localDatabaseURL(fileManager: FileManager, seedFileName: String) throws -> URL {
    let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return base.appendingPathComponent(seedFileName)
}

private func bundledDatabaseURL(fileManager: FileManager, seedFileName: String) throws -> URL {
    guard let starterBundleURL = Bundle.main.url(forResource: "PinballStarter", withExtension: "bundle") else {
        throw SeedDatabaseError.missingBundle
    }
    let url = starterBundleURL.appendingPathComponent("pinball/data/\(seedFileName)")
    guard fileManager.fileExists(atPath: url.path) else {
        throw SeedDatabaseError.missingSeed
    }
    return url
}
