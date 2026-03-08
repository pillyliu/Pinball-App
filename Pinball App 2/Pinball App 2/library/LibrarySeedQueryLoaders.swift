import Foundation
import SQLite3

func loadEntryScopedRulesheetLinks(
    _ database: OpaquePointer,
    tableName: String
) throws -> [String: [PinballGame.ReferenceLink]] {
    let sql = "SELECT library_entry_id, label, url FROM \(tableName) ORDER BY library_entry_id ASC, priority ASC"
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

func loadEntryScopedVideos(
    _ database: OpaquePointer,
    tableName: String
) throws -> [String: [PinballGame.Video]] {
    let sql = "SELECT library_entry_id, kind, label, url FROM \(tableName) ORDER BY library_entry_id ASC, priority ASC"
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

func loadPracticeScopedRulesheetLinks(
    _ database: OpaquePointer,
    tableName: String
) throws -> [String: [PinballGame.ReferenceLink]] {
    let sql = "SELECT practice_identity, label, url FROM \(tableName) ORDER BY practice_identity ASC, priority ASC"
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

func loadPracticeScopedVideos(
    _ database: OpaquePointer,
    tableName: String
) throws -> [String: [PinballGame.Video]] {
    let sql = "SELECT practice_identity, kind, label, url FROM \(tableName) ORDER BY practice_identity ASC, priority ASC"
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

func loadCatalogRulesheetRecords(_ database: OpaquePointer) throws -> [String: [CatalogRulesheetLinkRecord]] {
    let sql = "SELECT practice_identity, provider, label, url, priority FROM catalog_rulesheet_links ORDER BY practice_identity ASC, priority ASC"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
    }
    defer { sqlite3_finalize(statement) }

    var out: [String: [CatalogRulesheetLinkRecord]] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let practiceIdentity = sqliteString(statement, index: 0) else { continue }
        out[practiceIdentity, default: []].append(
            CatalogRulesheetLinkRecord(
                practiceIdentity: practiceIdentity,
                provider: sqliteString(statement, index: 1) ?? "",
                label: sqliteString(statement, index: 2) ?? "Rulesheet",
                localPath: nil,
                url: sqliteString(statement, index: 3),
                priority: sqliteInt(statement, index: 4)
            )
        )
    }
    return out
}

func loadCatalogVideoRecords(_ database: OpaquePointer) throws -> [String: [CatalogVideoLinkRecord]] {
    let sql = "SELECT practice_identity, kind, label, url, priority FROM catalog_video_links ORDER BY practice_identity ASC, priority ASC"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw SeedDatabaseError.prepareStatement(message: currentSQLiteMessage(from: database))
    }
    defer { sqlite3_finalize(statement) }

    var out: [String: [CatalogVideoLinkRecord]] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let practiceIdentity = sqliteString(statement, index: 0),
              let url = sqliteString(statement, index: 3) else { continue }
        out[practiceIdentity, default: []].append(
            CatalogVideoLinkRecord(
                practiceIdentity: practiceIdentity,
                provider: "matchplay",
                kind: sqliteString(statement, index: 1) ?? "tutorial",
                label: sqliteString(statement, index: 2) ?? "Tutorial 1",
                url: url,
                priority: sqliteInt(statement, index: 4)
            )
        )
    }
    return out
}
