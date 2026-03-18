import Foundation

private let defaultImportedSourcesResource = "default_pm_venue_sources_v1"

struct PinballLibrarySourceState: Codable {
    var enabledSourceIDs: [String]
    var pinnedSourceIDs: [String]
    var selectedSourceID: String?
    var selectedSortBySource: [String: String]
    var selectedBankBySource: [String: Int]

    static let empty = PinballLibrarySourceState(
        enabledSourceIDs: [],
        pinnedSourceIDs: [],
        selectedSourceID: nil,
        selectedSortBySource: [:],
        selectedBankBySource: [:]
    )
}

enum PinballLibrarySourceStateStore {
    private static let defaultsKey = "pinball-library-source-state-v1"
    static let maxPinnedSources = 10

    static func load() -> PinballLibrarySourceState {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return .empty
        }
        if let state = try? JSONDecoder().decode(PinballLibrarySourceState.self, from: data) {
            return normalized(state)
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .empty
        }
        return normalized(
            PinballLibrarySourceState(
                enabledSourceIDs: (root["enabledSourceIDs"] as? [Any])?.compactMap { canonicalLibrarySourceID(String(describing: $0)) } ?? [],
                pinnedSourceIDs: (root["pinnedSourceIDs"] as? [Any])?.compactMap { canonicalLibrarySourceID(String(describing: $0)) } ?? [],
                selectedSourceID: canonicalLibrarySourceID(root["selectedSourceID"] as? String),
                selectedSortBySource: normalizeStringMap(root["selectedSortBySource"] as? [String: Any]),
                selectedBankBySource: normalizeIntMap(root["selectedBankBySource"] as? [String: Any])
            )
        )
    }

    static func save(_ state: PinballLibrarySourceState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func synchronize(with payloadSources: [PinballLibrarySource]) -> PinballLibrarySourceState {
        let validIDs = Set(payloadSources.map(\.id))
        var state = load()
        state.enabledSourceIDs = filteredKnownIDs(state.enabledSourceIDs, validIDs: validIDs)
        state.pinnedSourceIDs = Array(filteredKnownIDs(state.pinnedSourceIDs, validIDs: validIDs).prefix(maxPinnedSources))
        for sourceID in defaultBuiltinVenueSourceIDs where validIDs.contains(sourceID) && !state.enabledSourceIDs.contains(sourceID) {
            state.enabledSourceIDs.append(sourceID)
        }

        if state.enabledSourceIDs.isEmpty {
            state.enabledSourceIDs = payloadSources.map(\.id)
        }

        if state.pinnedSourceIDs.isEmpty {
            state.pinnedSourceIDs = Array(payloadSources.prefix(maxPinnedSources).map(\.id))
        }

        if let selectedSourceID = canonicalLibrarySourceID(state.selectedSourceID), validIDs.contains(selectedSourceID) {
            state.selectedSourceID = selectedSourceID
        } else {
            state.selectedSourceID = nil
        }

        state.selectedSortBySource = Dictionary(
            uniqueKeysWithValues: state.selectedSortBySource.compactMap { key, value in
                guard let canonicalKey = canonicalLibrarySourceID(key), validIDs.contains(canonicalKey) else { return nil }
                return (canonicalKey, value)
            }
        )
        state.selectedBankBySource = Dictionary(
            uniqueKeysWithValues: state.selectedBankBySource.compactMap { key, value in
                guard let canonicalKey = canonicalLibrarySourceID(key), validIDs.contains(canonicalKey) else { return nil }
                return (canonicalKey, value)
            }
        )
        save(state)
        return state
    }

    static func upsertSource(id: String, enable: Bool = true, pinIfPossible: Bool = true) {
        guard let id = canonicalLibrarySourceID(id) else { return }
        var state = load()
        if enable, !state.enabledSourceIDs.contains(id) {
            state.enabledSourceIDs.append(id)
        }
        if pinIfPossible, !state.pinnedSourceIDs.contains(id), state.pinnedSourceIDs.count < maxPinnedSources {
            state.pinnedSourceIDs.append(id)
        }
        save(state)
    }

    static func setEnabled(sourceID: String, isEnabled: Bool) {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return }
        var state = load()
        if isEnabled {
            if !state.enabledSourceIDs.contains(sourceID) {
                state.enabledSourceIDs.append(sourceID)
            }
        } else {
            state.enabledSourceIDs.removeAll { $0 == sourceID }
            state.pinnedSourceIDs.removeAll { $0 == sourceID }
            if state.selectedSourceID == sourceID {
                state.selectedSourceID = nil
            }
        }
        save(state)
    }

    static func setPinned(sourceID: String, isPinned: Bool) -> Bool {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return false }
        var state = load()
        if isPinned {
            if state.pinnedSourceIDs.contains(sourceID) {
                return true
            }
            guard state.pinnedSourceIDs.count < maxPinnedSources else {
                return false
            }
            if !state.enabledSourceIDs.contains(sourceID) {
                state.enabledSourceIDs.append(sourceID)
            }
            state.pinnedSourceIDs.append(sourceID)
        } else {
            state.pinnedSourceIDs.removeAll { $0 == sourceID }
        }
        save(state)
        return true
    }

    private static func filteredKnownIDs(_ ids: [String], validIDs: Set<String>) -> [String] {
        var seen = Set<String>()
        return ids.compactMap(canonicalLibrarySourceID).filter { id in
            validIDs.contains(id) && seen.insert(id).inserted
        }
    }

    private static func normalized(_ state: PinballLibrarySourceState) -> PinballLibrarySourceState {
        PinballLibrarySourceState(
            enabledSourceIDs: Array(NSOrderedSet(array: state.enabledSourceIDs.compactMap(canonicalLibrarySourceID))) as? [String] ?? [],
            pinnedSourceIDs: Array(NSOrderedSet(array: state.pinnedSourceIDs.compactMap(canonicalLibrarySourceID))) as? [String] ?? [],
            selectedSourceID: canonicalLibrarySourceID(state.selectedSourceID),
            selectedSortBySource: Dictionary(uniqueKeysWithValues: state.selectedSortBySource.compactMap { key, value in
                canonicalLibrarySourceID(key).map { ($0, value) }
            }),
            selectedBankBySource: Dictionary(uniqueKeysWithValues: state.selectedBankBySource.compactMap { key, value in
                canonicalLibrarySourceID(key).map { ($0, value) }
            })
        )
    }
}

extension Notification.Name {
    static let pinballLibrarySourcesDidChange = Notification.Name("pinballLibrarySourcesDidChange")
}

func postPinballLibrarySourcesDidChange() {
    NotificationCenter.default.post(name: .pinballLibrarySourcesDidChange, object: nil)
}

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

    static func load() -> [PinballImportedSourceRecord] {
        let bundledDefaults = loadBundledDefaults()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return bundledDefaults
        }
        if let records = try? JSONDecoder().decode([PinballImportedSourceRecord].self, from: data) {
            return mergedDefaults(bundledDefaults, with: records)
        }
        guard let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return bundledDefaults
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
        return mergedDefaults(bundledDefaults, with: records)
    }

    static func save(_ records: [PinballImportedSourceRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func upsert(_ record: PinballImportedSourceRecord) {
        var records = load()
        let canonicalRecord = PinballImportedSourceRecord(
            id: canonicalLibrarySourceID(record.id) ?? record.id,
            name: record.name,
            type: record.type,
            provider: record.provider,
            providerSourceID: record.providerSourceID,
            machineIDs: record.machineIDs,
            lastSyncedAt: record.lastSyncedAt,
            searchQuery: record.searchQuery,
            distanceMiles: record.distanceMiles
        )
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

        var state = PinballLibrarySourceStateStore.load()
        state.enabledSourceIDs.removeAll { $0 == id }
        state.pinnedSourceIDs.removeAll { $0 == id }
        if state.selectedSourceID == id {
            state.selectedSourceID = nil
        }
        PinballLibrarySourceStateStore.save(state)
    }

    private static func mergedDefaults(
        _ defaults: [PinballImportedSourceRecord],
        with stored: [PinballImportedSourceRecord]
    ) -> [PinballImportedSourceRecord] {
        var byID: [String: PinballImportedSourceRecord] = [:]
        defaults.forEach { byID[$0.id] = $0 }
        stored.forEach { byID[$0.id] = $0 }
        return byID.values.sorted {
            ($0.type.rawValue, $0.name.lowercased()) < ($1.type.rawValue, $1.name.lowercased())
        }
    }

    private static func loadBundledDefaults() -> [PinballImportedSourceRecord] {
        guard
            let url = Bundle.main.url(
                forResource: defaultImportedSourcesResource,
                withExtension: "json",
                subdirectory: "pinball/data"
            ),
            let data = try? Data(contentsOf: url)
        else {
            return []
        }
        struct Root: Decodable {
            let records: [PinballImportedSourceRecord]
        }
        return (try? JSONDecoder().decode(Root.self, from: data).records) ?? []
    }
}

private func normalizeStringMap(_ raw: [String: Any]?) -> [String: String] {
    Dictionary(uniqueKeysWithValues: (raw ?? [:]).compactMap { key, value in
        guard let canonicalKey = canonicalLibrarySourceID(key), let stringValue = value as? String else { return nil }
        return (canonicalKey, stringValue)
    })
}

private func normalizeIntMap(_ raw: [String: Any]?) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: (raw ?? [:]).compactMap { key, value in
        guard let canonicalKey = canonicalLibrarySourceID(key) else { return nil }
        if let intValue = value as? Int { return (canonicalKey, intValue) }
        if let numberValue = value as? NSNumber { return (canonicalKey, numberValue.intValue) }
        return nil
    })
}

private func inferredImportedSourceProvider(type: PinballLibrarySourceType, id: String) -> PinballImportedSourceProvider {
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

struct PinballCatalogManufacturerOption: Identifiable, Hashable {
    let id: String
    let name: String
    let gameCount: Int
    let isModern: Bool
    let featuredRank: Int?
    let sortBucket: Int
}

struct PinballLibraryVenueSearchResult: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let state: String?
    let zip: String?
    let distanceMiles: Double?
    let machineCount: Int
}

private struct NormalizedLibraryRoot: Decodable {
    let schemaVersion: Int?
    let generatedAt: String?
    let manufacturers: [CatalogManufacturerRecord]?
    let machines: [CatalogMachineRecord]?
    let sources: [CatalogSourceRecord]?
    let sourceMemberships: [CatalogMembershipRecord]?
    let memberships: [CatalogMembershipRecord]?
    let overrides: [CatalogOverrideRecord]?
    let rulesheetLinks: [CatalogRulesheetLinkRecord]?
    let videoLinks: [CatalogVideoLinkRecord]?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case manufacturers
        case machines
        case sources
        case sourceMemberships = "source_memberships"
        case memberships
        case overrides
        case rulesheetLinks = "rulesheet_links"
        case videoLinks = "video_links"
    }
}

struct CatalogManufacturerRecord: Decodable {
    let id: String
    let name: String
    let isModern: Bool?
    let featuredRank: Int?
    let gameCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isModern = "is_modern"
        case featuredRank = "featured_rank"
        case gameCount = "game_count"
    }
}

struct CatalogMachineRecord: Decodable {
    struct RemoteImageSet: Decodable {
        let mediumURL: String?
        let largeURL: String?

        enum CodingKeys: String, CodingKey {
            case mediumURL = "medium_url"
            case largeURL = "large_url"
        }
    }

    let practiceIdentity: String
    let opdbMachineID: String?
    let opdbGroupID: String?
    let slug: String
    let name: String
    let variant: String?
    let manufacturerID: String?
    let manufacturerName: String?
    let year: Int?
    let opdbName: String?
    let opdbCommonName: String?
    let opdbShortname: String?
    let opdbDescription: String?
    let opdbType: String?
    let opdbDisplay: String?
    let opdbPlayerCount: Int?
    let opdbManufactureDate: String?
    let opdbIpdbID: Int?
    let opdbGroupShortname: String?
    let opdbGroupDescription: String?
    let primaryImage: RemoteImageSet?
    let playfieldImage: RemoteImageSet?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case opdbMachineID = "opdb_machine_id"
        case opdbGroupID = "opdb_group_id"
        case slug
        case name
        case variant
        case manufacturerID = "manufacturer_id"
        case manufacturerName = "manufacturer_name"
        case year
        case opdbName = "opdb_name"
        case opdbCommonName = "opdb_common_name"
        case opdbShortname = "opdb_shortname"
        case opdbDescription = "opdb_description"
        case opdbType = "opdb_type"
        case opdbDisplay = "opdb_display"
        case opdbPlayerCount = "opdb_player_count"
        case opdbManufactureDate = "opdb_manufacture_date"
        case opdbIpdbID = "opdb_ipdb_id"
        case opdbGroupShortname = "opdb_group_shortname"
        case opdbGroupDescription = "opdb_group_description"
        case primaryImage = "primary_image"
        case playfieldImage = "playfield_image"
    }
}

private struct CatalogSourceRecord: Decodable {
    let id: String
    let type: String
    let name: String
    let provider: String?
    let providerSourceID: String?
    let isBuiltin: Bool?
    let isEnabled: Bool?
    let isPinned: Bool?
    let pinRank: Int?
    let defaultSort: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case provider
        case providerSourceID = "provider_source_id"
        case isBuiltin = "is_builtin"
        case isEnabled = "is_enabled"
        case isPinned = "is_pinned"
        case pinRank = "pin_rank"
        case defaultSort = "default_sort"
    }
}

private struct CatalogMembershipRecord: Decodable {
    let sourceID: String
    let practiceIdentity: String
    let sortName: String?
    let sortYear: Int?
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case practiceIdentity = "practice_identity"
        case sortName = "sort_name"
        case sortYear = "sort_year"
        case area
        case areaOrder = "area_order"
        case groupNumber = "group_number"
        case position
        case bank
    }
}

struct CatalogOverrideRecord: Decodable {
    let practiceIdentity: String
    let rulesheetLocalPath: String?
    let playfieldLocalPath: String?
    let playfieldSourceURL: String?
    let gameinfoLocalPath: String?
    let nameOverride: String?
    let variantOverride: String?
    let manufacturerOverride: String?
    let yearOverride: Int?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case rulesheetLocalPath = "rulesheet_local_path"
        case playfieldLocalPath = "playfield_local_path"
        case playfieldSourceURL = "playfield_source_url"
        case gameinfoLocalPath = "gameinfo_local_path"
        case nameOverride = "name_override"
        case variantOverride = "variant_override"
        case manufacturerOverride = "manufacturer_override"
        case yearOverride = "year_override"
    }
}

struct CatalogRulesheetLinkRecord: Decodable {
    let practiceIdentity: String
    let provider: String
    let label: String
    let localPath: String?
    let url: String?
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case provider
        case label
        case localPath = "local_path"
        case url
        case priority
    }
}

struct CatalogVideoLinkRecord: Decodable {
    let practiceIdentity: String
    let provider: String
    let kind: String
    let label: String
    let url: String
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case provider
        case kind
        case label
        case url
        case priority
    }
}

nonisolated struct ResolvedCatalogRecord {
    let sourceID: String
    let sourceName: String
    let sourceType: PinballLibrarySourceType
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
    let opdbID: String?
    let opdbMachineID: String?
    let practiceIdentity: String
    let opdbName: String?
    let opdbCommonName: String?
    let opdbShortname: String?
    let opdbDescription: String?
    let opdbType: String?
    let opdbDisplay: String?
    let opdbPlayerCount: Int?
    let opdbManufactureDate: String?
    let opdbIpdbID: Int?
    let opdbGroupShortname: String?
    let opdbGroupDescription: String?
    let primaryImageURL: String?
    let primaryImageLargeURL: String?
    let playfieldImageURL: String?
    let alternatePlayfieldImageURL: String?
    let playfieldLocalPath: String?
    let playfieldSourceLabel: String?
    let gameinfoLocalPath: String?
    let rulesheetLocalPath: String?
    let rulesheetURL: String?
    let rulesheetLinks: [PinballGame.ReferenceLink]
    let videos: [PinballGame.Video]

    init(
        sourceID: String,
        sourceName: String,
        sourceType: PinballLibrarySourceType,
        area: String?,
        areaOrder: Int?,
        groupNumber: Int?,
        position: Int?,
        bank: Int?,
        name: String,
        variant: String?,
        manufacturer: String?,
        year: Int?,
        slug: String,
        opdbID: String?,
        opdbMachineID: String? = nil,
        practiceIdentity: String,
        opdbName: String? = nil,
        opdbCommonName: String? = nil,
        opdbShortname: String? = nil,
        opdbDescription: String? = nil,
        opdbType: String? = nil,
        opdbDisplay: String? = nil,
        opdbPlayerCount: Int? = nil,
        opdbManufactureDate: String? = nil,
        opdbIpdbID: Int? = nil,
        opdbGroupShortname: String? = nil,
        opdbGroupDescription: String? = nil,
        primaryImageURL: String?,
        primaryImageLargeURL: String?,
        playfieldImageURL: String?,
        alternatePlayfieldImageURL: String?,
        playfieldLocalPath: String?,
        playfieldSourceLabel: String?,
        gameinfoLocalPath: String?,
        rulesheetLocalPath: String?,
        rulesheetURL: String?,
        rulesheetLinks: [PinballGame.ReferenceLink],
        videos: [PinballGame.Video]
    ) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.sourceType = sourceType
        self.area = area
        self.areaOrder = areaOrder
        self.groupNumber = groupNumber
        self.position = position
        self.bank = bank
        self.name = name
        self.variant = variant
        self.manufacturer = manufacturer
        self.year = year
        self.slug = slug
        self.opdbID = opdbID
        self.opdbMachineID = opdbMachineID
        self.practiceIdentity = practiceIdentity
        self.opdbName = opdbName
        self.opdbCommonName = opdbCommonName
        self.opdbShortname = opdbShortname
        self.opdbDescription = opdbDescription
        self.opdbType = opdbType
        self.opdbDisplay = opdbDisplay
        self.opdbPlayerCount = opdbPlayerCount
        self.opdbManufactureDate = opdbManufactureDate
        self.opdbIpdbID = opdbIpdbID
        self.opdbGroupShortname = opdbGroupShortname
        self.opdbGroupDescription = opdbGroupDescription
        self.primaryImageURL = primaryImageURL
        self.primaryImageLargeURL = primaryImageLargeURL
        self.playfieldImageURL = playfieldImageURL
        self.alternatePlayfieldImageURL = alternatePlayfieldImageURL
        self.playfieldLocalPath = playfieldLocalPath
        self.playfieldSourceLabel = playfieldSourceLabel
        self.gameinfoLocalPath = gameinfoLocalPath
        self.rulesheetLocalPath = rulesheetLocalPath
        self.rulesheetURL = rulesheetURL
        self.rulesheetLinks = rulesheetLinks
        self.videos = videos
    }
}

enum CatalogRulesheetProvider: String {
    case local
    case prof
    case tf
    case pp
    case bob
    case papa
    case opdb
}

enum CatalogVideoProvider: String {
    case local
    case matchplay
}

struct LegacyCatalogExtraction {
    let payload: PinballLibraryPayload
    let state: PinballLibrarySourceState
}

struct LegacyCuratedOverride {
    let practiceIdentity: String
    var nameOverride: String?
    var variantOverride: String?
    var manufacturerOverride: String?
    var yearOverride: Int?
    var playfieldLocalPath: String?
    var playfieldSourceURL: String?
    var gameinfoLocalPath: String?
    var rulesheetLocalPath: String?
    var rulesheetLinks: [PinballGame.ReferenceLink]
    var videos: [PinballGame.Video]
}

private struct PublicLibraryOverridesRoot: Decodable {
    let playfieldOverrides: [PublicLibraryPlayfieldOverrideRecord]
}

private struct PublicLibraryPlayfieldOverrideRecord: Decodable {
    let practiceIdentity: String
    let opdbGroupId: String?
    let playfieldLocalPath: String?
    let playfieldSourceUrl: String?
}

private struct VenueMetadataOverlaysRoot: Decodable {
    let layoutAreas: [VenueLayoutAreaOverlayRecord]
    let machineLayout: [VenueMachineLayoutOverlayRecord]
    let machineBank: [VenueMachineBankOverlayRecord]

    enum CodingKeys: String, CodingKey {
        case layoutAreas = "layout_areas"
        case machineLayout = "machine_layout"
        case machineBank = "machine_bank"
    }
}

private struct VenueLayoutAreaOverlayRecord: Decodable {
    let sourceID: String
    let area: String
    let areaOrder: Int

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case area
        case areaOrder = "area_order"
    }
}

private struct VenueMachineLayoutOverlayRecord: Decodable {
    let sourceID: String
    let opdbID: String
    let area: String?
    let groupNumber: Int?
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case opdbID = "opdb_id"
        case area
        case groupNumber = "group_number"
        case position
    }
}

private struct VenueMachineBankOverlayRecord: Decodable {
    let sourceID: String
    let opdbID: String
    let bank: Int

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case opdbID = "opdb_id"
        case bank
    }
}

private struct VenueMetadataOverlayIndex {
    let areaOrderByKey: [String: Int]
    let machineLayoutByKey: [String: VenueMachineLayoutOverlayRecord]
    let machineBankByKey: [String: VenueMachineBankOverlayRecord]
}

struct ResolvedImportedVenueMetadata {
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
}

private func catalogCuratedOverride(
    practiceIdentity: String?,
    opdbGroupID: String?,
    overridesByKey: [String: LegacyCuratedOverride]
) -> LegacyCuratedOverride? {
    let candidateKeys = [
        catalogNormalizedOptionalString(practiceIdentity),
        catalogNormalizedOptionalString(opdbGroupID)
    ].compactMap { $0 }

    for key in candidateKeys {
        if let override = overridesByKey[key] {
            return override
        }
    }
    return nil
}

private func emptyVenueMetadataOverlayIndex() -> VenueMetadataOverlayIndex {
    VenueMetadataOverlayIndex(
        areaOrderByKey: [:],
        machineLayoutByKey: [:],
        machineBankByKey: [:]
    )
}

private func venueOverlayAreaKey(sourceID: String, area: String) -> String {
    "\(sourceID)::\(area)"
}

private func venueOverlayMachineKey(sourceID: String, opdbID: String) -> String {
    "\(sourceID)::\(opdbID)"
}

private func parseVenueMetadataOverlays(data: Data?) -> VenueMetadataOverlayIndex {
    guard let data,
          !data.isEmpty,
          let root = try? JSONDecoder().decode(VenueMetadataOverlaysRoot.self, from: data) else {
        return emptyVenueMetadataOverlayIndex()
    }

    let areaOrderByKey = Dictionary(uniqueKeysWithValues: root.layoutAreas.map {
        (venueOverlayAreaKey(sourceID: $0.sourceID, area: $0.area), $0.areaOrder)
    })
    let machineLayoutByKey = Dictionary(uniqueKeysWithValues: root.machineLayout.map {
        (venueOverlayMachineKey(sourceID: $0.sourceID, opdbID: $0.opdbID), $0)
    })
    let machineBankByKey = Dictionary(uniqueKeysWithValues: root.machineBank.map {
        (venueOverlayMachineKey(sourceID: $0.sourceID, opdbID: $0.opdbID), $0)
    })
    return VenueMetadataOverlayIndex(
        areaOrderByKey: areaOrderByKey,
        machineLayoutByKey: machineLayoutByKey,
        machineBankByKey: machineBankByKey
    )
}

private func resolvedImportedVenueMetadata(
    sourceID: String,
    requestedOpdbID: String,
    machine: CatalogMachineRecord,
    overlays: VenueMetadataOverlayIndex
) -> ResolvedImportedVenueMetadata? {
    func expandedOverlayCandidateIDs(_ value: String?) -> [String] {
        guard let normalized = catalogNormalizedOptionalString(value) else { return [] }
        var out: [String] = []
        var current: String? = normalized
        while let currentValue = current {
            if !out.contains(currentValue) {
                out.append(currentValue)
            }
            guard let dashIndex = currentValue.lastIndex(of: "-"), dashIndex > currentValue.startIndex else {
                break
            }
            current = String(currentValue[..<dashIndex])
        }
        return out
    }

    var candidateIDs: [String] = []
    for candidateID in (
        expandedOverlayCandidateIDs(requestedOpdbID) +
        expandedOverlayCandidateIDs(machine.opdbMachineID) +
        expandedOverlayCandidateIDs(machine.opdbGroupID) +
        expandedOverlayCandidateIDs(machine.practiceIdentity)
    ) {
        if !candidateIDs.contains(candidateID) {
            candidateIDs.append(candidateID)
        }
    }

    for candidateID in candidateIDs {
        let layout = overlays.machineLayoutByKey[venueOverlayMachineKey(sourceID: sourceID, opdbID: candidateID)]
        let bank = overlays.machineBankByKey[venueOverlayMachineKey(sourceID: sourceID, opdbID: candidateID)]
        if layout == nil && bank == nil {
            continue
        }

        let area = catalogNormalizedOptionalString(layout?.area)
        return ResolvedImportedVenueMetadata(
            area: area,
            areaOrder: area.flatMap { overlays.areaOrderByKey[venueOverlayAreaKey(sourceID: sourceID, area: $0)] },
            groupNumber: layout?.groupNumber,
            position: layout?.position,
            bank: bank?.bank
        )
    }

    return nil
}

private struct LegacyLibraryRoot: Decodable {
    let games: [PinballGame]?
    let items: [PinballGame]?
    let sources: [LegacyLibrarySourcePayload]?
    let libraries: [LegacyLibrarySourcePayload]?
}

private struct LegacyLibrarySourcePayload: Decodable {
    let id: String?
    let libraryID: String?
    let name: String?
    let libraryName: String?
    let type: String?
    let libraryType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case libraryID = "library_id"
        case name
        case libraryName = "library_name"
        case type
        case libraryType = "library_type"
    }
}

private func catalogParseSourceType(_ raw: String?) -> PinballLibrarySourceType {
    let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "manufacturer":
        return .manufacturer
    case "category":
        return .category
    default:
        return .venue
    }
}

private func catalogInferSources(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen: [PinballLibrarySource] = []
    var ids = Set<String>()
    for game in games {
        if ids.insert(game.sourceId).inserted {
            seen.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
        }
    }
    if seen.isEmpty {
        if let avenueSource = builtinVenueSources().first(where: { $0.id == pmAvenueLibrarySourceID }) {
            seen.append(avenueSource)
        }
    }
    return seen
}

nonisolated func catalogNormalizedOptionalString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

func decodeLibraryPayloadWithState(
    data: Data,
    filterBySourceState: Bool = true
) throws -> LegacyCatalogExtraction {
    if let normalized = try? JSONDecoder().decode(NormalizedLibraryRoot.self, from: data),
       let machines = normalized.machines, !machines.isEmpty {
        let payload = resolveNormalizedCatalog(root: normalized, machines: catalogResolvedMachines(machines))
        let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
        return legacyCatalogExtraction(payload: payload, state: state, filterBySourceState: filterBySourceState)
    }

    let payload = try decodeLegacyLibraryPayload(data: data)
    let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
    return legacyCatalogExtraction(payload: payload, state: state, filterBySourceState: filterBySourceState)
}

func decodeMergedLibraryPayloadWithState(
    libraryData: Data,
    opdbCatalogData: Data,
    publicOverridesData: Data? = nil,
    venueMetadataData: Data? = nil,
    filterBySourceState: Bool = true
) throws -> LegacyCatalogExtraction {
    let legacyPayload = try decodeLegacyLibraryPayload(data: libraryData)
    guard let normalized = try? JSONDecoder().decode(NormalizedLibraryRoot.self, from: opdbCatalogData),
          let decodedMachines = normalized.machines, !decodedMachines.isEmpty else {
        let state = PinballLibrarySourceStateStore.synchronize(with: legacyPayload.sources)
        return legacyCatalogExtraction(payload: legacyPayload, state: state, filterBySourceState: filterBySourceState)
    }
    let machines = catalogResolvedMachines(decodedMachines)

    let payload = resolveMergedCatalog(
        legacyPayload: legacyPayload,
        root: normalized,
        machines: machines,
        publicOverrides: parsePublicLibraryOverrides(data: publicOverridesData),
        venueMetadataOverlays: parseVenueMetadataOverlays(data: venueMetadataData)
    )
    let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
    return legacyCatalogExtraction(payload: payload, state: state, filterBySourceState: filterBySourceState)
}

func decodeCatalogManufacturerOptions(data: Data) throws -> [PinballCatalogManufacturerOption] {
    let root = try JSONDecoder().decode(NormalizedLibraryRoot.self, from: data)
    let groupCountsByManufacturerID: [String: Int] = {
        guard let machines = root.machines.map(catalogResolvedMachines) else { return [:] }
        let grouped = Dictionary(grouping: machines) { machine in
            machine.manufacturerID ?? ""
        }
        return grouped.reduce(into: [:]) { partialResult, entry in
            let manufacturerID = entry.key
            guard !manufacturerID.isEmpty else { return }
            partialResult[manufacturerID] = Set(entry.value.map { $0.opdbGroupID ?? $0.practiceIdentity }).count
        }
    }()
    return (root.manufacturers ?? [])
        .map { record in
            PinballCatalogManufacturerOption(
                id: record.id,
                name: record.name,
                gameCount: groupCountsByManufacturerID[record.id] ?? record.gameCount ?? 0,
                isModern: record.isModern ?? false,
                featuredRank: record.featuredRank,
                sortBucket: (record.isModern ?? false) ? 0 : (record.featuredRank == nil ? 2 : 1)
            )
        }
        .sorted {
            ($0.sortBucket, $0.featuredRank ?? Int.max, $0.name.lowercased())
                < ($1.sortBucket, $1.featuredRank ?? Int.max, $1.name.lowercased())
        }
}

private func catalogResolvedMachines(_ machines: [CatalogMachineRecord]) -> [CatalogMachineRecord] {
    machines.map { machine in
        CatalogMachineRecord(
            practiceIdentity: machine.practiceIdentity,
            opdbMachineID: machine.opdbMachineID,
            opdbGroupID: machine.opdbGroupID,
            slug: machine.slug,
            name: machine.name,
            variant: catalogResolvedVariantLabel(title: machine.name, explicitVariant: machine.variant),
            manufacturerID: machine.manufacturerID,
            manufacturerName: machine.manufacturerName,
            year: machine.year,
            opdbName: machine.opdbName,
            opdbCommonName: machine.opdbCommonName,
            opdbShortname: machine.opdbShortname,
            opdbDescription: machine.opdbDescription,
            opdbType: machine.opdbType,
            opdbDisplay: machine.opdbDisplay,
            opdbPlayerCount: machine.opdbPlayerCount,
            opdbManufactureDate: machine.opdbManufactureDate,
            opdbIpdbID: machine.opdbIpdbID,
            opdbGroupShortname: machine.opdbGroupShortname,
            opdbGroupDescription: machine.opdbGroupDescription,
            primaryImage: machine.primaryImage,
            playfieldImage: machine.playfieldImage
        )
    }
}

private func filterPayload(_ payload: PinballLibraryPayload, using state: PinballLibrarySourceState) -> PinballLibraryPayload {
    let enabled = Set(state.enabledSourceIDs)
    let filteredSources = payload.sources.filter { enabled.contains($0.id) }
    let sourceIDs = Set(filteredSources.map(\.id))
    let filteredGames = payload.games.filter { sourceIDs.contains($0.sourceId) }
    return PinballLibraryPayload(games: filteredGames, sources: filteredSources)
}

private func legacyCatalogExtraction(
    payload: PinballLibraryPayload,
    state: PinballLibrarySourceState,
    filterBySourceState: Bool
) -> LegacyCatalogExtraction {
    LegacyCatalogExtraction(
        payload: filterBySourceState ? filterPayload(payload, using: state) : payload,
        state: state
    )
}

private func decodeLegacyLibraryPayload(data: Data) throws -> PinballLibraryPayload {
    let decoder = JSONDecoder()

    if let root = try? decoder.decode(LegacyLibraryRoot.self, from: data) {
        let games = root.games ?? root.items ?? []
        let sourcePayloads = root.sources ?? root.libraries ?? []
        let decodedSources = sourcePayloads.compactMap { (payload: LegacyLibrarySourcePayload) -> PinballLibrarySource? in
            guard let rawID = (payload.id ?? payload.libraryID)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !rawID.isEmpty else {
                return nil
            }
            let id = libraryCanonicalSourceID(rawID) ?? rawID
            let rawName = payload.name ?? payload.libraryName
            let trimmedName = rawName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = (trimmedName?.isEmpty == false) ? trimmedName : nil
            return PinballLibrarySource(
                id: id,
                name: normalizedName ?? id,
                type: catalogParseSourceType(payload.type ?? payload.libraryType)
            )
        }
        let sources = decodedSources.isEmpty ? catalogInferSources(from: games) : decodedSources
        return PinballLibraryPayload(games: games, sources: sources)
    }

    let games = try decoder.decode([PinballGame].self, from: data)
    let sources = catalogInferSources(from: games)
    return PinballLibraryPayload(games: games, sources: sources)
}

private func resolveMergedCatalog(
    legacyPayload: PinballLibraryPayload,
    root: NormalizedLibraryRoot,
    machines: [CatalogMachineRecord],
    publicOverrides: PublicLibraryOverridesRoot,
    venueMetadataOverlays: VenueMetadataOverlayIndex
) -> PinballLibraryPayload {
    let importedSources = PinballImportedSourcesStore.load()
    let machineByPracticeIdentity = Dictionary(grouping: machines, by: \.practiceIdentity)
    let machineByOPDBID: [String: CatalogMachineRecord] = Dictionary(uniqueKeysWithValues: machines.compactMap { machine in
        guard let opdbID = catalogNormalizedOptionalString(machine.opdbMachineID) else { return nil }
        return (opdbID, machine)
    })
    let manufacturerByID = Dictionary(uniqueKeysWithValues: (root.manufacturers ?? []).map { ($0.id, $0) })
    var curatedOverridesByPracticeIdentity = buildLegacyCuratedOverrides(from: legacyPayload.games)
    applyPublicPlayfieldOverrides(&curatedOverridesByPracticeIdentity, publicOverrides: publicOverrides)
    let opdbRulesheetsByPracticeIdentity = Dictionary(grouping: root.rulesheetLinks ?? [], by: \.practiceIdentity)
    let opdbVideosByPracticeIdentity = Dictionary(grouping: root.videoLinks ?? [], by: \.practiceIdentity)

    let importedSourceIDs = Set(importedSources.map(\.id))
    let filteredLegacyGames = legacyPayload.games.filter { !importedSourceIDs.contains($0.sourceId) }
    let filteredLegacySources = legacyPayload.sources.filter { !importedSourceIDs.contains($0.id) }

    let mergedLegacyGames = filteredLegacyGames.map { legacyGame in
        resolveLegacyGame(
            legacyGame: legacyGame,
            curatedOverridesByPracticeIdentity: curatedOverridesByPracticeIdentity,
            machineByPracticeIdentity: machineByPracticeIdentity,
            machineByOPDBID: machineByOPDBID,
            manufacturerByID: manufacturerByID,
            opdbRulesheetsByPracticeIdentity: opdbRulesheetsByPracticeIdentity,
            opdbVideosByPracticeIdentity: opdbVideosByPracticeIdentity
        )
    }

    guard !importedSources.isEmpty else {
        return PinballLibraryPayload(games: mergedLegacyGames, sources: legacyPayload.sources)
    }

    var additionalGames: [PinballGame] = []
    var additionalSources: [PinballLibrarySource] = []

    for importedSource in importedSources {
        additionalSources.append(
            PinballLibrarySource(id: importedSource.id, name: importedSource.name, type: importedSource.type)
        )

        switch importedSource.type {
        case .manufacturer:
            let groupedMachines = Dictionary(grouping: machines.filter { $0.manufacturerID == importedSource.providerSourceID }) {
                $0.opdbGroupID ?? $0.practiceIdentity
            }
            let sourceMachines = groupedMachines.values.compactMap { group in
                group.min(by: catalogPreferredManufacturerMachine)
            }
            .sorted { lhs, rhs in
                let leftYear = lhs.year ?? Int.max
                let rightYear = rhs.year ?? Int.max
                if leftYear != rightYear { return leftYear < rightYear }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            additionalGames.append(
                contentsOf: sourceMachines.map {
                    resolveImportedGame(
                        machine: $0,
                        source: importedSource,
                        manufacturerByID: manufacturerByID,
                        curatedOverride: catalogCuratedOverride(
                            practiceIdentity: $0.practiceIdentity,
                            opdbGroupID: $0.opdbGroupID,
                            overridesByKey: curatedOverridesByPracticeIdentity
                        ),
                        opdbRulesheets: opdbRulesheetsByPracticeIdentity[$0.practiceIdentity] ?? [],
                        opdbVideos: opdbVideosByPracticeIdentity[$0.practiceIdentity] ?? [],
                        venueMetadata: nil
                    )
                }
            )
        case .category:
            continue
        case .venue, .tournament:
            let sourceMachines: [(requestedOpdbID: String, machine: CatalogMachineRecord)] =
                importedSource.machineIDs.compactMap { machineID in
                guard let machine = catalogPreferredMachineForSourceLookup(
                    requestedMachineID: machineID,
                    machineByOPDBID: machineByOPDBID,
                    machineByPracticeIdentity: machineByPracticeIdentity
                ) else {
                    return nil
                }
                return (requestedOpdbID: machineID, machine: machine)
            }
            additionalGames.append(
                contentsOf: sourceMachines.map {
                    resolveImportedGame(
                        machine: $0.machine,
                        source: importedSource,
                        manufacturerByID: manufacturerByID,
                        curatedOverride: catalogCuratedOverride(
                            practiceIdentity: $0.machine.practiceIdentity,
                            opdbGroupID: $0.machine.opdbGroupID,
                            overridesByKey: curatedOverridesByPracticeIdentity
                        ),
                        opdbRulesheets: opdbRulesheetsByPracticeIdentity[$0.machine.practiceIdentity] ?? [],
                        opdbVideos: opdbVideosByPracticeIdentity[$0.machine.practiceIdentity] ?? [],
                        venueMetadata: resolvedImportedVenueMetadata(
                            sourceID: importedSource.id,
                            requestedOpdbID: $0.requestedOpdbID,
                            machine: $0.machine,
                            overlays: venueMetadataOverlays
                        )
                    )
                }
            )
        }
    }

    let mergedSources = catalogDedupedSources(filteredLegacySources + additionalSources)
    let mergedGames = mergedLegacyGames + additionalGames
    return PinballLibraryPayload(games: mergedGames, sources: mergedSources)
}

private func resolveLegacyGame(
    legacyGame: PinballGame,
    curatedOverridesByPracticeIdentity: [String: LegacyCuratedOverride],
    machineByPracticeIdentity: [String: [CatalogMachineRecord]],
    machineByOPDBID: [String: CatalogMachineRecord],
    manufacturerByID: [String: CatalogManufacturerRecord],
    opdbRulesheetsByPracticeIdentity: [String: [CatalogRulesheetLinkRecord]],
    opdbVideosByPracticeIdentity: [String: [CatalogVideoLinkRecord]]
) -> PinballGame {
    let machine = catalogPreferredMachineForLegacyGame(
        legacyGame: legacyGame,
        machineByOPDBID: machineByOPDBID,
        machineByPracticeIdentity: machineByPracticeIdentity
    )
    guard let machine else { return legacyGame }

    let practiceIdentity = legacyGame.practiceIdentity ?? machine.practiceIdentity
    let curatedOverride = catalogCuratedOverride(
        practiceIdentity: practiceIdentity,
        opdbGroupID: legacyGame.opdbGroupID ?? machine.opdbGroupID,
        overridesByKey: curatedOverridesByPracticeIdentity
    )
    let manufacturerName = catalogNormalizedOptionalString(legacyGame.manufacturer)
        ?? machine.manufacturerName
        ?? machine.manufacturerID.flatMap { manufacturerByID[$0]?.name }

    let hasRemoteLegacyRulesheet = !isImportedPinballMapSourceID(legacyGame.sourceId)
        && (!legacyGame.rulesheetLinks.isEmpty || catalogNormalizedOptionalString(legacyGame.rulesheetUrl) != nil)
    let hasCuratedRulesheet = catalogNormalizedOptionalString(legacyGame.rulesheetLocal) != nil
        || hasRemoteLegacyRulesheet
    let hasCuratedVideos = !legacyGame.videos.isEmpty
    let playfieldLocalPath = catalogNormalizedOptionalString(legacyGame.playfieldLocalOriginal ?? legacyGame.playfieldLocal)
        ?? catalogNormalizedOptionalString(curatedOverride?.playfieldLocalPath)
    let curatedPlayfieldImageURL = catalogNormalizedOptionalString(curatedOverride?.playfieldSourceURL)
        ?? preferredLegacyPlayfieldOverride(for: legacyGame)
    let hasCuratedPlayfield = playfieldLocalPath != nil || curatedPlayfieldImageURL != nil
    let opdbPlayfieldImageURL = catalogNormalizedOptionalString(
        machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL
    )

    let resolvedCatalogRulesheets = resolveRulesheetLinks(override: nil, rulesheetLinks: opdbRulesheetsByPracticeIdentity[practiceIdentity] ?? [])
    let resolvedRulesheets: [PinballGame.ReferenceLink]
    let rulesheetLocalPath: String?
    if hasCuratedRulesheet {
        rulesheetLocalPath = catalogNormalizedOptionalString(legacyGame.rulesheetLocal)
        if !isImportedPinballMapSourceID(legacyGame.sourceId), !legacyGame.rulesheetLinks.isEmpty {
            resolvedRulesheets = mergeRulesheetLinks(primary: legacyGame.rulesheetLinks, secondary: resolvedCatalogRulesheets.links)
        } else if !isImportedPinballMapSourceID(legacyGame.sourceId),
                  let rulesheetURL = catalogNormalizedOptionalString(legacyGame.rulesheetUrl) {
            resolvedRulesheets = mergeRulesheetLinks(
                primary: [PinballGame.ReferenceLink(label: "Rulesheet", url: rulesheetURL)],
                secondary: resolvedCatalogRulesheets.links
            )
        } else {
            resolvedRulesheets = resolvedCatalogRulesheets.links
        }
    } else {
        rulesheetLocalPath = resolvedCatalogRulesheets.localPath
        resolvedRulesheets = resolvedCatalogRulesheets.links
    }

    let resolvedVideos = mergeResolvedVideos(
        primary: hasCuratedVideos ? legacyGame.videos : [],
        secondary: resolveVideoLinks(videoLinks: opdbVideosByPracticeIdentity[practiceIdentity] ?? [])
    )

    let playfieldImageURL = hasCuratedPlayfield
        ? curatedPlayfieldImageURL
        : opdbPlayfieldImageURL

    let record = ResolvedCatalogRecord(
        sourceID: legacyGame.sourceId,
        sourceName: legacyGame.sourceName,
        sourceType: legacyGame.sourceType,
        area: legacyGame.area,
        areaOrder: legacyGame.areaOrder,
        groupNumber: legacyGame.group,
        position: legacyGame.pos,
        bank: legacyGame.bank,
        name: catalogNormalizedOptionalString(curatedOverride?.nameOverride)
            ?? catalogResolvedDisplayTitle(title: machine.name, explicitVariant: machine.variant),
        variant: catalogNormalizedOptionalString(legacyGame.normalizedVariant ?? machine.variant),
        manufacturer: catalogNormalizedOptionalString(manufacturerName),
        year: legacyGame.year ?? machine.year,
        slug: legacyGame.slug,
        opdbID: catalogNormalizedOptionalString(legacyGame.opdbID) ?? catalogNormalizedOptionalString(machine.opdbMachineID),
        practiceIdentity: practiceIdentity,
        primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
        primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
        playfieldImageURL: playfieldImageURL,
        alternatePlayfieldImageURL: hasCuratedPlayfield ? opdbPlayfieldImageURL : nil,
        playfieldLocalPath: playfieldLocalPath,
        playfieldSourceLabel: hasCuratedPlayfield ? nil : (machine.playfieldImage == nil ? nil : "Playfield (OPDB)"),
        gameinfoLocalPath: legacyGame.gameinfoLocal,
        rulesheetLocalPath: rulesheetLocalPath,
        rulesheetURL: resolvedRulesheets.first?.url,
        rulesheetLinks: resolvedRulesheets,
        videos: resolvedVideos
    )
    return PinballGame(record: record)
}

private func catalogPreferredMachineForLegacyGame(
    legacyGame: PinballGame,
    machineByOPDBID: [String: CatalogMachineRecord],
    machineByPracticeIdentity: [String: [CatalogMachineRecord]]
) -> CatalogMachineRecord? {
    let requestedVariant = catalogNormalizedOptionalString(legacyGame.normalizedVariant)
    let groupCandidates = catalogNormalizedOptionalString(legacyGame.practiceIdentity ?? legacyGame.opdbGroupID)
        .flatMap { practiceIdentity in machineByPracticeIdentity[practiceIdentity] }
        ?? []
    let preferredGroupMachine = groupCandidates.min(by: catalogPreferredGroupDefaultMachine)
    let groupArtFallback = groupCandidates
        .filter(catalogMachineHasPrimaryImage)
        .min(by: catalogPreferredManufacturerMachine)

    guard let requestedMachineID = catalogNormalizedOptionalString(legacyGame.opdbID),
          let exactMachine = machineByOPDBID[requestedMachineID] else {
        if let variantMatch = catalogPreferredMachineForVariant(candidates: groupCandidates, requestedVariant: requestedVariant),
           catalogMachineHasPrimaryImage(variantMatch) {
            return variantMatch
        }
        if let preferredGroupMachine, catalogMachineHasPrimaryImage(preferredGroupMachine) {
            return preferredGroupMachine
        }
        if let groupArtFallback {
            return groupArtFallback
        }
        return preferredGroupMachine
    }

    let variantCandidates = machineByPracticeIdentity[exactMachine.practiceIdentity] ?? groupCandidates
    let variantMatch = catalogPreferredMachineForVariant(candidates: variantCandidates, requestedVariant: requestedVariant)
    let exactHasPrimary = catalogMachineHasPrimaryImage(exactMachine)

    // Fallback ladder: variant art -> exact machine art -> group default -> any group variant with art.
    if let variantMatch, catalogMachineHasPrimaryImage(variantMatch) {
        return variantMatch
    }
    if exactHasPrimary {
        return exactMachine
    }
    if let preferredGroupMachine, catalogMachineHasPrimaryImage(preferredGroupMachine) {
        return preferredGroupMachine
    }
    if let groupArtFallback {
        return groupArtFallback
    }
    return preferredGroupMachine ?? variantMatch ?? exactMachine
}

private func buildLegacyCuratedOverrides(from games: [PinballGame]) -> [String: LegacyCuratedOverride] {
    var out: [String: LegacyCuratedOverride] = [:]

    for game in games {
        guard let practiceIdentity = catalogNormalizedOptionalString(game.practiceIdentity ?? game.opdbGroupID) else { continue }
        var current = out[practiceIdentity] ?? LegacyCuratedOverride(
            practiceIdentity: practiceIdentity,
            nameOverride: nil,
            variantOverride: nil,
            manufacturerOverride: nil,
            yearOverride: nil,
            playfieldLocalPath: nil,
            playfieldSourceURL: nil,
            gameinfoLocalPath: nil,
            rulesheetLocalPath: nil,
            rulesheetLinks: [],
            videos: []
        )

        if !isImportedPinballMapSourceID(game.sourceId) {
            current.nameOverride = current.nameOverride ?? preferredLegacyNameOverride(for: game)
            current.variantOverride = current.variantOverride ?? catalogNormalizedOptionalString(game.normalizedVariant)
            current.manufacturerOverride = current.manufacturerOverride ?? catalogNormalizedOptionalString(game.manufacturer)
            current.yearOverride = current.yearOverride ?? game.year
        }
        current.playfieldLocalPath = current.playfieldLocalPath ?? catalogNormalizedOptionalString(game.playfieldLocalOriginal ?? game.playfieldLocal)
        current.playfieldSourceURL = current.playfieldSourceURL ?? preferredLegacyPlayfieldOverride(for: game)
        current.gameinfoLocalPath = current.gameinfoLocalPath ?? catalogNormalizedOptionalString(game.gameinfoLocal)
        current.rulesheetLocalPath = current.rulesheetLocalPath ?? catalogNormalizedOptionalString(game.rulesheetLocal)

        if current.rulesheetLinks.isEmpty {
            if isImportedPinballMapSourceID(game.sourceId) {
                current.rulesheetLinks = []
            } else if !game.rulesheetLinks.isEmpty {
                current.rulesheetLinks = game.rulesheetLinks
            } else if let url = catalogNormalizedOptionalString(game.rulesheetUrl) {
                current.rulesheetLinks = [PinballGame.ReferenceLink(label: "Rulesheet", url: url)]
            }
        }

        if current.videos.isEmpty && !game.videos.isEmpty {
            current.videos = game.videos
        }

        out[practiceIdentity] = current
    }

    return out
}

private func preferredLegacyNameOverride(for game: PinballGame) -> String? {
    guard let name = catalogNormalizedOptionalString(game.name) else { return nil }
    if game.sourceId == "venue--gameroom" { return name }
    if game.sourceType != .venue { return name }
    if name.contains(":") { return name }
    return nil
}

private func preferredLegacyPlayfieldOverride(for game: PinballGame) -> String? {
    guard let playfieldURL = catalogNormalizedOptionalString(game.playfieldImageUrl),
          libraryIsPinProfPlayfieldURL(libraryResolveURL(pathOrURL: playfieldURL)) else {
        return nil
    }
    return playfieldURL
}

private func parsePublicLibraryOverrides(data: Data?) -> PublicLibraryOverridesRoot {
    guard let data,
          let root = try? JSONDecoder().decode(PublicLibraryOverridesRoot.self, from: data) else {
        return PublicLibraryOverridesRoot(playfieldOverrides: [])
    }
    return root
}

private func applyPublicPlayfieldOverrides(
    _ curatedOverridesByPracticeIdentity: inout [String: LegacyCuratedOverride],
    publicOverrides: PublicLibraryOverridesRoot
) {
    for override in publicOverrides.playfieldOverrides {
        guard let practiceIdentity = catalogNormalizedOptionalString(override.practiceIdentity) else { continue }
        let playfieldLocalPath = catalogNormalizedOptionalString(override.playfieldLocalPath)
        let playfieldSourceURL = catalogNormalizedOptionalString(override.playfieldSourceUrl)
        guard playfieldLocalPath != nil || playfieldSourceURL != nil else { continue }
        let opdbGroupID = catalogNormalizedOptionalString(override.opdbGroupId)

        for key in [practiceIdentity, opdbGroupID].compactMap({ $0 }) {
            var current = curatedOverridesByPracticeIdentity[key] ?? LegacyCuratedOverride(
                practiceIdentity: key,
                nameOverride: nil,
                variantOverride: nil,
                manufacturerOverride: nil,
                yearOverride: nil,
                playfieldLocalPath: nil,
                playfieldSourceURL: nil,
                gameinfoLocalPath: nil,
                rulesheetLocalPath: nil,
                rulesheetLinks: [],
                videos: []
            )
            current.playfieldLocalPath = playfieldLocalPath
            if let playfieldSourceURL {
                current.playfieldSourceURL = playfieldSourceURL
            }
            curatedOverridesByPracticeIdentity[key] = current
        }
    }
}

private func resolveNormalizedCatalog(root: NormalizedLibraryRoot, machines: [CatalogMachineRecord]) -> PinballLibraryPayload {
    let machineByPracticeIdentity = Dictionary(uniqueKeysWithValues: machines.map { ($0.practiceIdentity, $0) })
    let manufacturerByID = Dictionary(uniqueKeysWithValues: (root.manufacturers ?? []).map { ($0.id, $0) })
    let overrideByPracticeIdentity = Dictionary(uniqueKeysWithValues: (root.overrides ?? []).map { ($0.practiceIdentity, $0) })
    let rulesheetsByPracticeIdentity = Dictionary(grouping: root.rulesheetLinks ?? [], by: \.practiceIdentity)
    let videosByPracticeIdentity = Dictionary(grouping: root.videoLinks ?? [], by: \.practiceIdentity)

    var sources = (root.sources ?? []).map { source -> PinballLibrarySource in
        PinballLibrarySource(
            id: source.id,
            name: source.name,
            type: catalogParseSourceType(source.type)
        )
    }

    let memberships = root.sourceMemberships ?? root.memberships ?? []
    if sources.isEmpty {
        var seen = Set<String>()
        sources = memberships.compactMap { membership in
            guard seen.insert(membership.sourceID).inserted else { return nil }
            let sourceType = catalogParseSourceType(
                membership.area == nil && membership.bank == nil && membership.groupNumber == nil ? "manufacturer" : "venue"
            )
            return PinballLibrarySource(id: membership.sourceID, name: membership.sourceID, type: sourceType)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    let resolvedGames = memberships.compactMap { membership -> PinballGame? in
        guard let machine = machineByPracticeIdentity[membership.practiceIdentity] else { return nil }
        let source = sources.first(where: { $0.id == membership.sourceID }) ?? PinballLibrarySource(
            id: membership.sourceID,
            name: membership.sourceID,
            type: .venue
        )
        let override = overrideByPracticeIdentity[membership.practiceIdentity]
        let manufacturerName = override?.manufacturerOverride
            ?? machine.manufacturerName
            ?? machine.manufacturerID.flatMap { manufacturerByID[$0]?.name }
        let resolvedRulesheet = resolveRulesheetLinks(
            override: override,
            rulesheetLinks: rulesheetsByPracticeIdentity[membership.practiceIdentity] ?? []
        )
        let resolvedVideos = resolveVideoLinks(
            videoLinks: videosByPracticeIdentity[membership.practiceIdentity] ?? []
        )
        let hasOverridePlayfield = override?.playfieldLocalPath != nil || override?.playfieldSourceURL != nil
        let opdbPlayfieldImageURL = catalogNormalizedOptionalString(
            machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL
        )
        let record = ResolvedCatalogRecord(
            sourceID: source.id,
            sourceName: source.name,
            sourceType: source.type,
            area: catalogNormalizedOptionalString(membership.area),
            areaOrder: membership.areaOrder,
            groupNumber: membership.groupNumber,
            position: membership.position,
            bank: membership.bank,
            name: override?.nameOverride ?? machine.name,
            variant: catalogNormalizedOptionalString(override?.variantOverride ?? machine.variant),
            manufacturer: catalogNormalizedOptionalString(manufacturerName),
            year: override?.yearOverride ?? machine.year,
            slug: catalogNormalizedOptionalString(machine.slug) ?? membership.practiceIdentity,
            opdbID: catalogNormalizedOptionalString(machine.opdbMachineID),
            practiceIdentity: membership.practiceIdentity,
            primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
            primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
            playfieldImageURL: override?.playfieldSourceURL
                ?? opdbPlayfieldImageURL,
            alternatePlayfieldImageURL: hasOverridePlayfield ? opdbPlayfieldImageURL : nil,
            playfieldLocalPath: override?.playfieldLocalPath,
            playfieldSourceLabel: hasOverridePlayfield ? nil : (machine.playfieldImage != nil ? "Playfield (OPDB)" : nil),
            gameinfoLocalPath: override?.gameinfoLocalPath,
            rulesheetLocalPath: resolvedRulesheet.localPath,
            rulesheetURL: resolvedRulesheet.links.first?.url,
            rulesheetLinks: resolvedRulesheet.links,
            videos: resolvedVideos
        )
        return PinballGame(record: record)
    }

    return PinballLibraryPayload(games: resolvedGames, sources: sources)
}

func decodePracticeCatalogGames(data: Data) throws -> [PinballGame] {
    let root = try JSONDecoder().decode(NormalizedLibraryRoot.self, from: data)
    let machines = catalogResolvedMachines(root.machines ?? [])
    guard !machines.isEmpty else { return [] }

    let manufacturerByID = Dictionary(uniqueKeysWithValues: (root.manufacturers ?? []).map { ($0.id, $0) })
    let rulesheetsByPracticeIdentity = Dictionary(grouping: root.rulesheetLinks ?? [], by: \.practiceIdentity)
    let videosByPracticeIdentity = Dictionary(grouping: root.videoLinks ?? [], by: \.practiceIdentity)
    let source = PinballImportedSourceRecord(
        id: "catalog--opdb-practice",
        name: "All OPDB Games",
        type: .category,
        provider: .opdb,
        providerSourceID: "opdb-catalog",
        machineIDs: [],
        lastSyncedAt: nil,
        searchQuery: nil,
        distanceMiles: nil
    )

    return Dictionary(grouping: machines, by: { $0.opdbGroupID ?? $0.practiceIdentity })
        .values
        .compactMap { group -> PinballGame? in
            guard let machine = group.min(by: catalogPreferredGroupDefaultMachine) else { return nil }
            return resolveImportedGame(
                machine: machine,
                source: source,
                manufacturerByID: manufacturerByID,
                curatedOverride: nil,
                opdbRulesheets: rulesheetsByPracticeIdentity[machine.practiceIdentity] ?? [],
                opdbVideos: videosByPracticeIdentity[machine.practiceIdentity] ?? [],
                venueMetadata: nil
            )
        }
        .sorted {
            let nameCompare = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameCompare != .orderedSame { return nameCompare == .orderedAscending }
            return $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending
        }
}
