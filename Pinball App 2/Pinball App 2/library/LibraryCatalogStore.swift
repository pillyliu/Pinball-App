import Foundation

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
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let state = try? JSONDecoder().decode(PinballLibrarySourceState.self, from: data) else {
            return .empty
        }
        return state
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

        if state.enabledSourceIDs.isEmpty {
            state.enabledSourceIDs = payloadSources.map(\.id)
        }

        if state.pinnedSourceIDs.isEmpty {
            state.pinnedSourceIDs = Array(payloadSources.prefix(maxPinnedSources).map(\.id))
        }

        if let selectedSourceID = state.selectedSourceID, !validIDs.contains(selectedSourceID) {
            state.selectedSourceID = nil
        }

        state.selectedSortBySource = state.selectedSortBySource.filter { validIDs.contains($0.key) }
        state.selectedBankBySource = state.selectedBankBySource.filter { validIDs.contains($0.key) }
        save(state)
        return state
    }

    static func upsertSource(id: String, enable: Bool = true, pinIfPossible: Bool = true) {
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
        return ids.filter { id in
            validIDs.contains(id) && seen.insert(id).inserted
        }
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
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let records = try? JSONDecoder().decode([PinballImportedSourceRecord].self, from: data) else {
            return []
        }
        return records.sorted {
            ($0.type.rawValue, $0.name.lowercased()) < ($1.type.rawValue, $1.name.lowercased())
        }
    }

    static func save(_ records: [PinballImportedSourceRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func upsert(_ record: PinballImportedSourceRecord) {
        var records = load()
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        save(records)
    }

    static func remove(id: String) {
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

private struct CatalogManufacturerRecord: Decodable {
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

private struct CatalogMachineRecord: Decodable {
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

private struct CatalogOverrideRecord: Decodable {
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

private struct CatalogRulesheetLinkRecord: Decodable {
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

private struct CatalogVideoLinkRecord: Decodable {
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

struct ResolvedCatalogRecord {
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
    let practiceIdentity: String
    let primaryImageURL: String?
    let primaryImageLargeURL: String?
    let playfieldImageURL: String?
    let playfieldLocalPath: String?
    let playfieldSourceLabel: String?
    let gameinfoLocalPath: String?
    let rulesheetLocalPath: String?
    let rulesheetURL: String?
    let rulesheetLinks: [PinballGame.ReferenceLink]
    let videos: [PinballGame.Video]
}

private enum CatalogRulesheetProvider: String {
    case local
    case tf
    case pp
    case bob
    case papa
    case opdb
}

private enum CatalogVideoProvider: String {
    case local
    case matchplay
}

struct LegacyCatalogExtraction {
    let payload: PinballLibraryPayload
    let state: PinballLibrarySourceState
}

private struct LegacyCuratedOverride {
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
        seen.append(PinballLibrarySource(id: "the-avenue", name: "The Avenue", type: .venue))
    }
    return seen
}

nonisolated private func catalogNormalizedOptionalString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

func decodeLibraryPayloadWithState(data: Data) throws -> LegacyCatalogExtraction {
    if let normalized = try? JSONDecoder().decode(NormalizedLibraryRoot.self, from: data),
       let machines = normalized.machines, !machines.isEmpty {
        let payload = resolveNormalizedCatalog(root: normalized, machines: machines)
        let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
        return LegacyCatalogExtraction(payload: filterPayload(payload, using: state), state: state)
    }

    let payload = try decodeLegacyLibraryPayload(data: data)
    let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
    return LegacyCatalogExtraction(payload: filterPayload(payload, using: state), state: state)
}

func decodeMergedLibraryPayloadWithState(libraryData: Data, opdbCatalogData: Data) throws -> LegacyCatalogExtraction {
    let legacyPayload = try decodeLegacyLibraryPayload(data: libraryData)
    guard let normalized = try? JSONDecoder().decode(NormalizedLibraryRoot.self, from: opdbCatalogData),
          let machines = normalized.machines, !machines.isEmpty else {
        let state = PinballLibrarySourceStateStore.synchronize(with: legacyPayload.sources)
        return LegacyCatalogExtraction(payload: filterPayload(legacyPayload, using: state), state: state)
    }

    let payload = resolveMergedCatalog(legacyPayload: legacyPayload, root: normalized, machines: machines)
    let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
    return LegacyCatalogExtraction(payload: filterPayload(payload, using: state), state: state)
}

func decodeCatalogManufacturerOptions(data: Data) throws -> [PinballCatalogManufacturerOption] {
    let root = try JSONDecoder().decode(NormalizedLibraryRoot.self, from: data)
    let groupCountsByManufacturerID: [String: Int] = {
        guard let machines = root.machines else { return [:] }
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

private func filterPayload(_ payload: PinballLibraryPayload, using state: PinballLibrarySourceState) -> PinballLibraryPayload {
    let enabled = Set(state.enabledSourceIDs)
    let filteredSources = payload.sources.filter { enabled.contains($0.id) }
    let sourceIDs = Set(filteredSources.map(\.id))
    let filteredGames = payload.games.filter { sourceIDs.contains($0.sourceId) }
    return PinballLibraryPayload(games: filteredGames, sources: filteredSources)
}

private func decodeLegacyLibraryPayload(data: Data) throws -> PinballLibraryPayload {
    let decoder = JSONDecoder()

    if let root = try? decoder.decode(LegacyLibraryRoot.self, from: data) {
        let games = root.games ?? root.items ?? []
        let sourcePayloads = root.sources ?? root.libraries ?? []
        let decodedSources = sourcePayloads.compactMap { (payload: LegacyLibrarySourcePayload) -> PinballLibrarySource? in
            guard let id = (payload.id ?? payload.libraryID)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                return nil
            }
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
    machines: [CatalogMachineRecord]
) -> PinballLibraryPayload {
    let importedSources = PinballImportedSourcesStore.load()
    let machineByPracticeIdentity = Dictionary(grouping: machines, by: \.practiceIdentity)
    let machineByOPDBID: [String: CatalogMachineRecord] = Dictionary(uniqueKeysWithValues: machines.compactMap { machine in
        guard let opdbID = catalogNormalizedOptionalString(machine.opdbMachineID) else { return nil }
        return (opdbID, machine)
    })
    let manufacturerByID = Dictionary(uniqueKeysWithValues: (root.manufacturers ?? []).map { ($0.id, $0) })
    let curatedOverridesByPracticeIdentity = buildLegacyCuratedOverrides(from: legacyPayload.games)
    let opdbRulesheetsByPracticeIdentity = Dictionary(grouping: root.rulesheetLinks ?? [], by: \.practiceIdentity)
    let opdbVideosByPracticeIdentity = Dictionary(grouping: root.videoLinks ?? [], by: \.practiceIdentity)

    let mergedLegacyGames = legacyPayload.games.map { legacyGame in
        resolveLegacyGame(
            legacyGame: legacyGame,
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
                        curatedOverride: curatedOverridesByPracticeIdentity[$0.practiceIdentity],
                        opdbRulesheets: opdbRulesheetsByPracticeIdentity[$0.practiceIdentity] ?? [],
                        opdbVideos: opdbVideosByPracticeIdentity[$0.practiceIdentity] ?? []
                    )
                }
            )
        case .category:
            continue
        case .venue:
            let sourceMachines = importedSource.machineIDs.compactMap { machineID in
                catalogPreferredMachineForSourceLookup(
                    requestedMachineID: machineID,
                    machineByOPDBID: machineByOPDBID,
                    machineByPracticeIdentity: machineByPracticeIdentity
                )
            }
            additionalGames.append(
                contentsOf: sourceMachines.map {
                    resolveImportedGame(
                        machine: $0,
                        source: importedSource,
                        manufacturerByID: manufacturerByID,
                        curatedOverride: curatedOverridesByPracticeIdentity[$0.practiceIdentity],
                        opdbRulesheets: opdbRulesheetsByPracticeIdentity[$0.practiceIdentity] ?? [],
                        opdbVideos: opdbVideosByPracticeIdentity[$0.practiceIdentity] ?? []
                    )
                }
            )
        }
    }

    let mergedSources = catalogDedupedSources(legacyPayload.sources + additionalSources)
    let mergedGames = mergedLegacyGames + additionalGames
    return PinballLibraryPayload(games: mergedGames, sources: mergedSources)
}

private func resolveLegacyGame(
    legacyGame: PinballGame,
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
    let manufacturerName = catalogNormalizedOptionalString(legacyGame.manufacturer)
        ?? machine.manufacturerName
        ?? machine.manufacturerID.flatMap { manufacturerByID[$0]?.name }

    let hasCuratedRulesheet = catalogNormalizedOptionalString(legacyGame.rulesheetLocal) != nil
        || !legacyGame.rulesheetLinks.isEmpty
        || catalogNormalizedOptionalString(legacyGame.rulesheetUrl) != nil
    let hasCuratedVideos = !legacyGame.videos.isEmpty
    let hasCuratedPlayfield = catalogNormalizedOptionalString(legacyGame.playfieldLocalOriginal ?? legacyGame.playfieldLocal) != nil
        || catalogNormalizedOptionalString(legacyGame.playfieldImageUrl) != nil

    let resolvedRulesheets: [PinballGame.ReferenceLink]
    let rulesheetLocalPath: String?
    if hasCuratedRulesheet {
        rulesheetLocalPath = catalogNormalizedOptionalString(legacyGame.rulesheetLocal)
        if !legacyGame.rulesheetLinks.isEmpty {
            resolvedRulesheets = legacyGame.rulesheetLinks
        } else if let rulesheetURL = catalogNormalizedOptionalString(legacyGame.rulesheetUrl) {
            resolvedRulesheets = [PinballGame.ReferenceLink(label: "Rulesheet", url: rulesheetURL)]
        } else {
            resolvedRulesheets = []
        }
    } else {
        let resolved = resolveRulesheetLinks(override: nil, rulesheetLinks: opdbRulesheetsByPracticeIdentity[practiceIdentity] ?? [])
        rulesheetLocalPath = resolved.localPath
        resolvedRulesheets = resolved.links
    }

    let resolvedVideos = hasCuratedVideos
        ? legacyGame.videos
        : resolveVideoLinks(videoLinks: opdbVideosByPracticeIdentity[practiceIdentity] ?? [])

    let playfieldImageURL = hasCuratedPlayfield
        ? catalogNormalizedOptionalString(legacyGame.playfieldImageUrl)
        : catalogNormalizedOptionalString(machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL)

    let record = ResolvedCatalogRecord(
        sourceID: legacyGame.sourceId,
        sourceName: legacyGame.sourceName,
        sourceType: legacyGame.sourceType,
        area: legacyGame.area,
        areaOrder: legacyGame.areaOrder,
        groupNumber: legacyGame.group,
        position: legacyGame.pos,
        bank: legacyGame.bank,
        name: legacyGame.name,
        variant: catalogNormalizedOptionalString(legacyGame.normalizedVariant ?? machine.variant),
        manufacturer: catalogNormalizedOptionalString(manufacturerName),
        year: legacyGame.year ?? machine.year,
        slug: legacyGame.slug,
        opdbID: catalogNormalizedOptionalString(legacyGame.opdbID) ?? catalogNormalizedOptionalString(machine.opdbMachineID),
        practiceIdentity: practiceIdentity,
        primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
        primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
        playfieldImageURL: playfieldImageURL,
        playfieldLocalPath: legacyGame.playfieldLocalOriginal ?? legacyGame.playfieldLocal,
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
    let preferredGroupMachine = catalogNormalizedOptionalString(legacyGame.practiceIdentity ?? legacyGame.opdbGroupID)
        .flatMap { practiceIdentity in
            machineByPracticeIdentity[practiceIdentity]?.min(by: catalogPreferredManufacturerMachine)
        }

    guard let requestedMachineID = catalogNormalizedOptionalString(legacyGame.opdbID),
          let exactMachine = machineByOPDBID[requestedMachineID] else {
        return preferredGroupMachine
    }

    let exactHasPrimary = exactMachine.primaryImage?.mediumURL != nil || exactMachine.primaryImage?.largeURL != nil
    if exactHasPrimary {
        return exactMachine
    }

    return preferredGroupMachine ?? exactMachine
}

private func catalogPreferredMachineForSourceLookup(
    requestedMachineID: String,
    machineByOPDBID: [String: CatalogMachineRecord],
    machineByPracticeIdentity: [String: [CatalogMachineRecord]]
) -> CatalogMachineRecord? {
    let normalizedMachineID = catalogNormalizedOptionalString(requestedMachineID)
    let preferredGroupMachine = normalizedMachineID.flatMap { machineID in
        machineByPracticeIdentity[machineID]?.min(by: catalogPreferredManufacturerMachine)
    }

    guard let normalizedMachineID,
          let exactMachine = machineByOPDBID[normalizedMachineID] else {
        return preferredGroupMachine
    }

    let exactHasPrimary = exactMachine.primaryImage?.mediumURL != nil || exactMachine.primaryImage?.largeURL != nil
    if exactHasPrimary {
        return exactMachine
    }

    let exactGroupMachine = machineByPracticeIdentity[exactMachine.practiceIdentity]?.min(by: catalogPreferredManufacturerMachine)
    return exactGroupMachine ?? preferredGroupMachine ?? exactMachine
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

        current.nameOverride = current.nameOverride ?? catalogNormalizedOptionalString(game.name)
        current.variantOverride = current.variantOverride ?? catalogNormalizedOptionalString(game.normalizedVariant)
        current.manufacturerOverride = current.manufacturerOverride ?? catalogNormalizedOptionalString(game.manufacturer)
        current.yearOverride = current.yearOverride ?? game.year
        current.playfieldLocalPath = current.playfieldLocalPath ?? catalogNormalizedOptionalString(game.playfieldLocalOriginal ?? game.playfieldLocal)
        current.playfieldSourceURL = current.playfieldSourceURL ?? catalogNormalizedOptionalString(game.playfieldImageUrl)
        current.gameinfoLocalPath = current.gameinfoLocalPath ?? catalogNormalizedOptionalString(game.gameinfoLocal)
        current.rulesheetLocalPath = current.rulesheetLocalPath ?? catalogNormalizedOptionalString(game.rulesheetLocal)

        if current.rulesheetLinks.isEmpty {
            if !game.rulesheetLinks.isEmpty {
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

private func resolveImportedGame(
    machine: CatalogMachineRecord,
    source: PinballImportedSourceRecord,
    manufacturerByID: [String: CatalogManufacturerRecord],
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: [CatalogRulesheetLinkRecord],
    opdbVideos: [CatalogVideoLinkRecord]
) -> PinballGame {
    let manufacturerName = curatedOverride?.manufacturerOverride
        ?? machine.manufacturerName
        ?? machine.manufacturerID.flatMap { manufacturerByID[$0]?.name }
    let resolvedRulesheet = resolveImportedRulesheetLinks(
        curatedOverride: curatedOverride,
        opdbRulesheetLinks: opdbRulesheets
    )
    let resolvedVideos = resolveImportedVideos(
        curatedOverride: curatedOverride,
        opdbVideoLinks: opdbVideos
    )
    let playfieldLocalPath = curatedOverride?.playfieldLocalPath
    let playfieldSourceURL = curatedOverride?.playfieldSourceURL
        ?? catalogNormalizedOptionalString(machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL)
    let record = ResolvedCatalogRecord(
        sourceID: source.id,
        sourceName: source.name,
        sourceType: source.type,
        area: nil,
        areaOrder: nil,
        groupNumber: nil,
        position: nil,
        bank: nil,
        name: curatedOverride?.nameOverride ?? machine.name,
        variant: source.type == .manufacturer ? nil : (curatedOverride?.variantOverride ?? catalogNormalizedOptionalString(machine.variant)),
        manufacturer: catalogNormalizedOptionalString(manufacturerName),
        year: curatedOverride?.yearOverride ?? machine.year,
        slug: machine.slug,
        opdbID: catalogNormalizedOptionalString(machine.opdbMachineID),
        practiceIdentity: machine.practiceIdentity,
        primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
        primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
        playfieldImageURL: playfieldSourceURL,
        playfieldLocalPath: playfieldLocalPath,
        playfieldSourceLabel: playfieldLocalPath == nil && machine.playfieldImage != nil ? "Playfield (OPDB)" : nil,
        gameinfoLocalPath: curatedOverride?.gameinfoLocalPath,
        rulesheetLocalPath: resolvedRulesheet.localPath,
        rulesheetURL: resolvedRulesheet.links.first?.url,
        rulesheetLinks: resolvedRulesheet.links,
        videos: resolvedVideos
    )
    return PinballGame(record: record)
}

nonisolated private func catalogPreferredManufacturerMachine(_ lhs: CatalogMachineRecord, _ rhs: CatalogMachineRecord) -> Bool {
    func normalizedVariant(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    let lhsHasPrimary = lhs.primaryImage?.mediumURL != nil || lhs.primaryImage?.largeURL != nil
    let rhsHasPrimary = rhs.primaryImage?.mediumURL != nil || rhs.primaryImage?.largeURL != nil
    if lhsHasPrimary != rhsHasPrimary {
        return lhsHasPrimary
    }

    let lhsVariant = normalizedVariant(lhs.variant)
    let rhsVariant = normalizedVariant(rhs.variant)
    if (lhsVariant == nil) != (rhsVariant == nil) {
        return lhsVariant == nil
    }

    let leftYear = lhs.year ?? Int.max
    let rightYear = rhs.year ?? Int.max
    if leftYear != rightYear {
        return leftYear < rightYear
    }

    let leftName = lhs.name.lowercased()
    let rightName = rhs.name.lowercased()
    if leftName != rightName {
        return leftName < rightName
    }

    return (lhs.opdbMachineID ?? lhs.practiceIdentity) < (rhs.opdbMachineID ?? rhs.practiceIdentity)
}

private func resolveImportedRulesheetLinks(
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheetLinks: [CatalogRulesheetLinkRecord]
) -> (localPath: String?, links: [PinballGame.ReferenceLink]) {
    if let localPath = catalogNormalizedOptionalString(curatedOverride?.rulesheetLocalPath) {
        return (localPath, [])
    }

    if let curatedOverride, !curatedOverride.rulesheetLinks.isEmpty {
        return (nil, curatedOverride.rulesheetLinks)
    }

    return resolveRulesheetLinks(override: nil, rulesheetLinks: opdbRulesheetLinks)
}

private func resolveImportedVideos(
    curatedOverride: LegacyCuratedOverride?,
    opdbVideoLinks: [CatalogVideoLinkRecord]
) -> [PinballGame.Video] {
    if let curatedOverride, !curatedOverride.videos.isEmpty {
        return curatedOverride.videos
    }
    return resolveVideoLinks(videoLinks: opdbVideoLinks)
}

private func catalogDedupedSources(_ sources: [PinballLibrarySource]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    return sources.filter { source in
        seen.insert(source.id).inserted
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
        let resolvedVideos = resolveVideoLinks(videoLinks: videosByPracticeIdentity[membership.practiceIdentity] ?? [])
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
                ?? catalogNormalizedOptionalString(machine.playfieldImage?.largeURL)
                ?? catalogNormalizedOptionalString(machine.playfieldImage?.mediumURL),
            playfieldLocalPath: override?.playfieldLocalPath,
            playfieldSourceLabel: override?.playfieldLocalPath == nil && machine.playfieldImage != nil ? "Playfield (OPDB)" : nil,
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

private func resolveRulesheetLinks(
    override: CatalogOverrideRecord?,
    rulesheetLinks: [CatalogRulesheetLinkRecord]
) -> (localPath: String?, links: [PinballGame.ReferenceLink]) {
    if let local = catalogNormalizedOptionalString(override?.rulesheetLocalPath) {
        return (local, [])
    }

    let sortedLinks = rulesheetLinks.sorted {
        ($0.priority ?? Int.max, $0.label) < ($1.priority ?? Int.max, $1.label)
    }
    let links = sortedLinks.compactMap { link -> PinballGame.ReferenceLink? in
        guard let url = catalogNormalizedOptionalString(link.url) else { return nil }
        return PinballGame.ReferenceLink(label: catalogRulesheetLabel(providerRawValue: link.provider, fallback: link.label), url: url)
    }
    return (catalogNormalizedOptionalString(sortedLinks.first?.localPath), links)
}

private func resolveVideoLinks(videoLinks: [CatalogVideoLinkRecord]) -> [PinballGame.Video] {
    let groupedByProvider = Dictionary(grouping: videoLinks) { link in
        CatalogVideoProvider(rawValue: link.provider.lowercased()) ?? .matchplay
    }
    let preferred = groupedByProvider[.local]?.sorted(by: compareVideoLinks)
        ?? groupedByProvider[.matchplay]?.sorted(by: compareVideoLinks)
        ?? []
    return preferred.map { link in
        PinballGame.Video(kind: link.kind, label: link.label, url: link.url)
    }
}

private func compareVideoLinks(_ lhs: CatalogVideoLinkRecord, _ rhs: CatalogVideoLinkRecord) -> Bool {
    let left = lhs.priority ?? Int.max
    let right = rhs.priority ?? Int.max
    if left != right { return left < right }
    return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
}

private func catalogRulesheetLabel(providerRawValue: String, fallback: String) -> String {
    switch CatalogRulesheetProvider(rawValue: providerRawValue.lowercased()) {
    case .tf:
        return "Rulesheet (TF)"
    case .pp:
        return "Rulesheet (PP)"
    case .bob:
        return "Rulesheet (Bob)"
    case .papa:
        return "Rulesheet (PAPA)"
    case .opdb:
        return "Rulesheet (OPDB)"
    case .local:
        return "Rulesheet"
    case nil:
        return fallback
    }
}
