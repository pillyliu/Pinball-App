import Foundation

enum PinballImportedSourceProvider: String, Codable {
    case opdb
    case pinballMap = "pinball_map"
    case matchPlay = "match_play"
}

struct PinballImportedSourceRecord: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: PinballLibrarySourceType
    var provider: PinballImportedSourceProvider
    var providerSourceID: String
    var machineIDs: [String]
    var lastSyncedAt: Date?
    var searchQuery: String?
    var distanceMiles: Int?
}

enum PinballImportedSourcesStore {
    private static let defaultsKey = "pinball-imported-sources-v1"

    static func hasPersistedSources() -> Bool {
        UserDefaults.standard.data(forKey: defaultsKey) != nil
    }

    static func load() -> [PinballImportedSourceRecord] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            guard !PinballLibrarySourceStateStore.hasPersistedState() else {
                return []
            }
            let defaults = loadBundledDefaults()
            if !defaults.isEmpty {
                save(defaults)
            }
            return defaults
        }
        if let records = try? JSONDecoder().decode([PinballImportedSourceRecord].self, from: data) {
            let migrated = normalizedImportedRecords(records)
            if migrated != records {
                save(migrated)
            }
            return migrated
        }
        guard let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return []
        }
        let iso = ISO8601DateFormatter()
        let records = array.compactMap { item -> PinballImportedSourceRecord? in
            guard let id = canonicalLibrarySourceID(item["id"] as? String),
                  let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
                  let typeRaw = item["type"] as? String,
                  let type = PinballLibrarySourceType(rawValue: typeRaw),
                  let providerSourceID = (item["providerSourceID"] as? String ?? item["providerSourceId"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !providerSourceID.isEmpty else {
                return nil
            }
            let provider = (item["provider"] as? String).flatMap(PinballImportedSourceProvider.init(rawValue:))
                ?? inferredImportedSourceProvider(type: type, id: id)
            let lastSyncedAt = (item["lastSyncedAt"] as? String).flatMap { iso.date(from: $0) }
            let machineIDs = (item["machineIDs"] as? [Any] ?? item["machineIds"] as? [Any] ?? []).compactMap {
                ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            return PinballImportedSourceRecord(
                id: id,
                name: name,
                type: type,
                provider: provider,
                providerSourceID: providerSourceID,
                machineIDs: machineIDs,
                lastSyncedAt: lastSyncedAt,
                searchQuery: (item["searchQuery"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                distanceMiles: item["distanceMiles"] as? Int
            )
        }
        let migrated = normalizedImportedRecords(records)
        save(migrated)
        return migrated
    }

    static func save(_ records: [PinballImportedSourceRecord]) {
        let normalized = normalizedImportedRecords(records)
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func upsert(_ record: PinballImportedSourceRecord) {
        var records = load()
        guard let canonicalRecord = normalizedImportedRecord(record) else { return }
        if let index = records.firstIndex(where: { $0.id == canonicalRecord.id }) {
            records[index] = mergedImportedSourceRecord(records[index], canonicalRecord)
        } else {
            records.append(canonicalRecord)
        }
        save(records)
    }

    static func remove(id: String) {
        guard let id = canonicalLibrarySourceID(id) else { return }
        var records = load()
        records.removeAll { $0.id == id }
        save(records)
        PinballLibrarySourceStateStore.removeSourcePreferences(sourceID: id)
    }

    private static func loadBundledDefaults() -> [PinballImportedSourceRecord] {
        guard !PinballLibrarySourceStateStore.hasPersistedState() else {
            return []
        }

        return [
            PinballImportedSourceRecord(
                id: pmAvenueLibrarySourceID,
                name: pmAvenueLibrarySourceName,
                type: .venue,
                provider: .pinballMap,
                providerSourceID: "8760",
                machineIDs: bundledAvenueVenueMachineIDs,
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: pmElectricBatLibrarySourceID,
                name: pmElectricBatLibrarySourceName,
                type: .venue,
                provider: .pinballMap,
                providerSourceID: "10819",
                machineIDs: bundledElectricBatVenueMachineIDs,
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: sternManufacturerLibrarySourceID,
                name: sternManufacturerLibrarySourceName,
                type: .manufacturer,
                provider: .opdb,
                providerSourceID: "manufacturer-12",
                machineIDs: [],
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: jerseyJackManufacturerLibrarySourceID,
                name: jerseyJackManufacturerLibrarySourceName,
                type: .manufacturer,
                provider: .opdb,
                providerSourceID: "manufacturer-74",
                machineIDs: [],
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: spookyManufacturerLibrarySourceID,
                name: spookyManufacturerLibrarySourceName,
                type: .manufacturer,
                provider: .opdb,
                providerSourceID: "manufacturer-95",
                machineIDs: [],
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
        ]
    }
}

private let bundledAvenueVenueMachineIDs: [String] = [
    "G43W4-MdEjy",
    "G4do5-MW9z8",
    "Gj66P-MXr0E-A1nx0",
    "GD7Ld-MBRP4-A1e4P",
    "G4835-M2YPK-ARkb7",
    "G6lnq-Mq1kv",
    "GK1Ej-MePok-A1zKx",
    "GZVOd-MwNxZ-AR8vV",
    "GpeoL-MkPz1-A944p",
    "G41d5-M9REd",
    "GR9Nr-MVKol",
    "GweeP-Ml9pZ-A9vXB",
    "GweeP-Ml9pZ-ARZoY",
    "G4xZy-MLno6",
    "G4dOQ-MyNbb",
    "GLWll-M1r8O-A1kx7",
    "GQKyP-MP3OK-A1KoX",
    "GQK1P-Ml95Z-A9bjw",
    "GK17D-MdEqz",
    "GEL0V-MyN8E-ARq7n",
    "G4qX5-Ml9jb",
    "G5pe4-MePZv",
    "GRBE4-MQK1Z",
    "Gr3EW-MD3Nj",
    "GoEkx-MdEzN-AR50E",
    "G2Lkd-M0ope-A97xV",
    "G4xbP-Mp45Y",
    "Gryw4-MNEKn",
    "G5vLR-MwNwy",
    "Gxv81-Mo1rp-A9Qew",
    "Gzy89-M0oPy-A9xXV",
    "GrkL5-MJoNN",
    "G4llj-MQYb2",
    "Gd2Xb-MRjpZ-A92v0",
    "G4ODR-MDXEy",
    "Grx8Y-MKNe9",
    "GBLLP-MW900-AOEEN",
    "GbPde-M5Rkv",
    "GRvBL-MP3Ev",
    "G7ZEz-MyN3K-ARl3o",
    "G3EBl-MRj6e-ARzbx",
]

private let bundledElectricBatVenueMachineIDs: [String] = [
    "Gr16e-MnKEX",
    "GrXOZ-MLyb0",
    "G4do5-MkPnV",
    "Gj66P-M3dxn",
    "GRoz4-MjBV6",
    "G4jQw-MJ5rl",
    "G5nbD-MDyXb",
    "GD7Ld-ME0BP",
    "G41do-MP3Py",
    "G5Woz-MKNq6",
    "GrknN-MQrdv",
    "GrNd0-MJNW1",
    "GrNWn-MQdqZ",
    "G6lnq-Mq1kv",
    "G43Yq-MJ7o4",
    "GK1Ej-MwNZr",
    "GrN7J-MJ78q",
    "GZVOd-MwNxZ-AOLoy",
    "GYWvw-MKNP4",
    "G5VDd-MJpqO",
    "G5Wxd-MLxl3",
    "GpeoL-MyNPq",
    "GrdDB-ML8xK",
    "GR9Nr-Mz2dY",
    "GweeP-Ml9pZ-ARZoY",
    "GrENE-MD0dz",
    "G4dOQ-MyNbb",
    "GRVq4-M4oNp",
    "GLWll-MXr4N",
    "Ge1Dy-M9Rrp",
    "GQKyP-MP3OK-AOEEx",
    "GQK1P-MW9pj",
    "GR6W8-Mb55B",
    "GR9o1-MQjj8",
    "GK17D-MdEqz",
    "GEL0V-MBRyb",
    "G5pe4-MyNkp",
    "GO0q3-MOEy8-ARol7",
    "GryQj-MLvN7",
    "GrP6q-M5Rp1",
    "Gr2Y2-MDxZq",
    "GrkOB-MJVvl",
    "GV8wB-Mq12N",
    "GoEkx-MdEzN-ARJQz",
    "G2Lkd-MNEdK",
    "G4xbP-Mp45Y",
    "G4xqN-MD1Rj",
    "GRDqo-MDbPx",
    "G4qxv-MJPyv",
    "Gxv81-M610r",
    "GrXEW-MDEwr",
    "Gzy89-M0oPy-A1zrL",
    "GrleW-MYeod",
    "GR6wO-MDvzk",
    "GR9Bx-MQkd5",
    "G4ODR-MDXEy",
    "Grx8Y-MKNe9",
    "GbPde-Mp43l-AOQwL",
    "G7ZEz-MBRYn",
    "G5nz5-M3d38",
    "GrXzD-MjBPX",
    "G3EBl-Mq1zy",
    "G57kN-MQ71K",
    "GrE7e-MQ9N1",
    "G42E2-MQP9e",
]

private func normalizedImportedVenueProviderSourceID(
    rawProviderSourceID: String,
    canonicalID: String
) -> String {
    if canonicalID.hasPrefix("venue--pm-") {
        return canonicalID.replacingOccurrences(of: "venue--pm-", with: "")
    }
    return rawProviderSourceID
}

private func normalizedImportedRecord(_ record: PinballImportedSourceRecord) -> PinballImportedSourceRecord? {
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

private func mergedImportedSourceRecord(
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

private func normalizedImportedRecords(_ records: [PinballImportedSourceRecord]) -> [PinballImportedSourceRecord] {
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

func inferredImportedSourceProvider(type: PinballLibrarySourceType, id: String) -> PinballImportedSourceProvider {
    switch type {
    case .manufacturer:
        return .opdb
    case .tournament:
        return .matchPlay
    case .venue:
        return id.hasPrefix("venue--pm-") ? .pinballMap : .opdb
    case .category:
        return .opdb
    }
}
