import Foundation
import SQLite3

struct SeedCatalogMachineRow {
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

struct SeedOverrideRow {
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

struct SeedBuiltInGameRow {
    let libraryEntryID: String
    let sourceID: String
    let sourceName: String
    let sourceType: PinballLibrarySourceType
    let practiceIdentity: String
    let opdbID: String?
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
    let name: String
    let variant: String?
    let manufacturer: String?
    let year: Int?
    let slug: String
    let primaryImageURL: String?
    let primaryImageLargeURL: String?
    let playfieldImageURL: String?
    let playfieldLocalPath: String?
    let playfieldSourceLabel: String?
    let gameinfoLocalPath: String?
    let rulesheetLocalPath: String?
    let rulesheetURL: String?
}

nonisolated func preferredManufacturerMachine(_ lhs: SeedCatalogMachineRow, _ rhs: SeedCatalogMachineRow) -> Bool {
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

nonisolated func seedMachineHasPrimaryImage(_ machine: SeedCatalogMachineRow) -> Bool {
    machine.primaryImageMediumURL != nil || machine.primaryImageLargeURL != nil
}

nonisolated func preferredSeedGroupMachine(_ group: [SeedCatalogMachineRow]) -> SeedCatalogMachineRow? {
    group.min(by: preferredManufacturerMachine)
}

nonisolated func preferredSeedMachineForVariant(
    candidates: [SeedCatalogMachineRow],
    requestedVariant: String?
) -> SeedCatalogMachineRow? {
    guard !candidates.isEmpty else { return nil }
    guard let requestedVariant = requestedVariant?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
          !requestedVariant.isEmpty else {
        return preferredSeedGroupMachine(candidates)
    }

    let ranked = candidates.sorted { lhs, rhs in
        let lhsScore = catalogVariantMatchScore(machineVariant: lhs.variant, requestedVariant: requestedVariant)
        let rhsScore = catalogVariantMatchScore(machineVariant: rhs.variant, requestedVariant: requestedVariant)
        if lhsScore != rhsScore { return lhsScore > rhsScore }

        let lhsHasPrimary = seedMachineHasPrimaryImage(lhs)
        let rhsHasPrimary = seedMachineHasPrimaryImage(rhs)
        if lhsHasPrimary != rhsHasPrimary { return lhsHasPrimary }

        return preferredManufacturerMachine(lhs, rhs)
    }

    guard let best = ranked.first else { return nil }
    let bestScore = catalogVariantMatchScore(machineVariant: best.variant, requestedVariant: requestedVariant)
    guard bestScore > 0 else { return nil }
    return best
}

nonisolated func dedupeRulesheetLinks(_ links: [PinballGame.ReferenceLink]) -> [PinballGame.ReferenceLink] {
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

nonisolated func preferredRulesheetRank(for url: String) -> Int {
    let normalized = url.lowercased()
    if normalized.contains("tiltforums.com/t/"), !normalized.contains(".json") {
        return 0
    }
    if normalized.hasPrefix("https://") {
        return 1
    }
    return 2
}

enum SeedDatabaseError: Error {
    case missingBundle
    case missingSeed
    case openDatabase(message: String)
    case prepareStatement(message: String)
}

nonisolated func sqliteString(_ statement: OpaquePointer, index: Int32) -> String? {
    guard let cString = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: cString)
}

nonisolated func sqliteInt(_ statement: OpaquePointer, index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int(statement, index))
}

nonisolated func currentSQLiteMessage(from database: OpaquePointer?) -> String {
    guard let database, let message = sqlite3_errmsg(database) else { return "Unknown SQLite error" }
    return String(cString: message)
}

nonisolated func parseSeedSourceType(_ raw: String?) -> PinballLibrarySourceType {
    switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "manufacturer":
        return .manufacturer
    case "category":
        return .category
    default:
        return .venue
    }
}

nonisolated func catalogMachineRecord(from row: SeedCatalogMachineRow) -> CatalogMachineRecord {
    CatalogMachineRecord(
        practiceIdentity: row.practiceIdentity,
        opdbMachineID: row.opdbMachineID,
        opdbGroupID: row.opdbGroupID,
        slug: row.slug,
        name: row.name,
        variant: catalogResolvedVariantLabel(title: row.name, explicitVariant: row.variant),
        manufacturerID: row.manufacturerID,
        manufacturerName: row.manufacturerName,
        year: row.year,
        primaryImage: CatalogMachineRecord.RemoteImageSet(mediumURL: row.primaryImageMediumURL, largeURL: row.primaryImageLargeURL),
        playfieldImage: CatalogMachineRecord.RemoteImageSet(mediumURL: row.playfieldImageMediumURL, largeURL: row.playfieldImageLargeURL)
    )
}

nonisolated func seedLegacyCuratedOverride(
    row: SeedOverrideRow?,
    rulesheetLinks: [PinballGame.ReferenceLink],
    videos: [PinballGame.Video]
) -> LegacyCuratedOverride? {
    guard let row else { return nil }
    return LegacyCuratedOverride(
        practiceIdentity: row.practiceIdentity,
        nameOverride: row.nameOverride,
        variantOverride: row.variantOverride,
        manufacturerOverride: row.manufacturerOverride,
        yearOverride: row.yearOverride,
        playfieldLocalPath: row.playfieldLocalPath,
        playfieldSourceURL: row.playfieldSourceURL,
        gameinfoLocalPath: row.gameinfoLocalPath,
        rulesheetLocalPath: row.rulesheetLocalPath,
        rulesheetLinks: rulesheetLinks,
        videos: videos
    )
}

nonisolated func seedBuiltInResolvedRecord(
    row: SeedBuiltInGameRow,
    resolvedMachine: SeedCatalogMachineRow?,
    rulesheetLinks: [PinballGame.ReferenceLink],
    videos: [PinballGame.Video]
) -> ResolvedCatalogRecord {
    ResolvedCatalogRecord(
        sourceID: row.sourceID,
        sourceName: row.sourceName,
        sourceType: row.sourceType,
        area: row.area,
        areaOrder: row.areaOrder,
        groupNumber: row.groupNumber,
        position: row.position,
        bank: row.bank,
        name: row.name,
        variant: row.variant,
        manufacturer: row.manufacturer,
        year: row.year,
        slug: row.slug,
        opdbID: row.opdbID,
        practiceIdentity: row.practiceIdentity,
        primaryImageURL: row.primaryImageURL ?? resolvedMachine?.primaryImageMediumURL,
        primaryImageLargeURL: row.primaryImageLargeURL ?? resolvedMachine?.primaryImageLargeURL,
        playfieldImageURL: row.playfieldImageURL,
        alternatePlayfieldImageURL: nil,
        playfieldLocalPath: row.playfieldLocalPath,
        playfieldSourceLabel: row.playfieldSourceLabel,
        gameinfoLocalPath: row.gameinfoLocalPath,
        rulesheetLocalPath: row.rulesheetLocalPath,
        rulesheetURL: row.rulesheetURL,
        rulesheetLinks: rulesheetLinks,
        videos: videos
    )
}
