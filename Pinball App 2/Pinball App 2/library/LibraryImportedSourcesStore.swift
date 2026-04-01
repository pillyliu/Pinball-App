import Foundation

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
            records[index] = canonicalRecord
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
}
