import Foundation

private func normalizedImportedVenueProviderSourceID(
    rawProviderSourceID: String,
    canonicalID: String
) -> String {
    if canonicalID.hasPrefix("venue--pm-") {
        return canonicalID.replacingOccurrences(of: "venue--pm-", with: "")
    }
    return rawProviderSourceID
}

func normalizedImportedRecord(_ record: PinballImportedSourceRecord) -> PinballImportedSourceRecord? {
    let canonicalID = canonicalLibrarySourceID(record.id) ?? record.id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !canonicalID.isEmpty else { return nil }

    let trimmedName = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return nil }

    let inferredProvider = inferredImportedSourceProvider(type: record.type, id: canonicalID)
    let provider = record.provider == .opdb && canonicalID.hasPrefix("venue--pm-")
        ? .pinballMap
        : record.provider

    let rawProviderSourceID = record.providerSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
    let providerSourceID = normalizedImportedVenueProviderSourceID(
        rawProviderSourceID: rawProviderSourceID,
        canonicalID: canonicalID
    )
    let normalizedProvider = provider == .opdb && canonicalID.hasPrefix("venue--pm-") ? inferredProvider : provider
    let machineIDs = Array(NSOrderedSet(array: record.machineIDs.compactMap(catalogNormalizedOptionalString))) as? [String] ?? []

    return PinballImportedSourceRecord(
        id: canonicalID,
        name: trimmedName,
        type: record.type,
        provider: normalizedProvider,
        providerSourceID: providerSourceID,
        machineIDs: machineIDs,
        lastSyncedAt: record.lastSyncedAt,
        searchQuery: catalogNormalizedOptionalString(record.searchQuery),
        distanceMiles: record.distanceMiles
    )
}

func mergedImportedSourceRecord(
    _ lhs: PinballImportedSourceRecord,
    _ rhs: PinballImportedSourceRecord
) -> PinballImportedSourceRecord {
    let machineIDs = Array(NSOrderedSet(array: lhs.machineIDs + rhs.machineIDs)) as? [String] ?? []
    let latestSyncedAt: Date? = {
        switch (lhs.lastSyncedAt, rhs.lastSyncedAt) {
        case let (left?, right?):
            return max(left, right)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }()

    return PinballImportedSourceRecord(
        id: rhs.id,
        name: rhs.name.isEmpty ? lhs.name : rhs.name,
        type: rhs.type,
        provider: rhs.provider,
        providerSourceID: rhs.providerSourceID.isEmpty ? lhs.providerSourceID : rhs.providerSourceID,
        machineIDs: machineIDs,
        lastSyncedAt: latestSyncedAt,
        searchQuery: rhs.searchQuery ?? lhs.searchQuery,
        distanceMiles: rhs.distanceMiles ?? lhs.distanceMiles
    )
}

func normalizedImportedRecords(_ records: [PinballImportedSourceRecord]) -> [PinballImportedSourceRecord] {
    var byID: [String: PinballImportedSourceRecord] = [:]
    for record in records {
        guard let normalized = normalizedImportedRecord(record) else { continue }
        if let existing = byID[normalized.id] {
            byID[normalized.id] = mergedImportedSourceRecord(existing, normalized)
        } else {
            byID[normalized.id] = normalized
        }
    }
    return byID.values.sorted {
        ($0.type.rawValue, $0.name.lowercased(), $0.id) < ($1.type.rawValue, $1.name.lowercased(), $1.id)
    }
}
