import Foundation

struct VenueLayoutAreaOverlayRecord: Decodable {
    let sourceID: String
    let area: String
    let areaOrder: Int

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case area
        case areaOrder = "area_order"
    }
}

struct VenueMachineLayoutOverlayRecord: Decodable {
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

struct VenueMachineBankOverlayRecord: Decodable {
    let sourceID: String
    let opdbID: String
    let bank: Int

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case opdbID = "opdb_id"
        case bank
    }
}

struct VenueMetadataOverlayIndex {
    let areaOrderByKey: [String: Int]
    let machineLayoutByKey: [String: VenueMachineLayoutOverlayRecord]
    let machineBankByKey: [String: VenueMachineBankOverlayRecord]
}

let emptyVenueMetadataOverlayIndex = VenueMetadataOverlayIndex(
    areaOrderByKey: [:],
    machineLayoutByKey: [:],
    machineBankByKey: [:]
)

struct ResolvedImportedVenueMetadata {
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
}

private struct CAFRecordsRoot<Record: Decodable>: Decodable {
    let records: [Record]
}

private struct CAFRulesheetAssetRecord: Decodable {
    let opdbId: String
    let provider: String
    let label: String
    let url: String?
    let localPath: String?
    let priority: Int?
    let isHidden: Bool
    let isActive: Bool
}

private struct CAFVideoAssetRecord: Decodable {
    let opdbId: String
    let provider: String
    let kind: String
    let label: String
    let url: String
    let priority: Int?
    let isHidden: Bool
    let isActive: Bool
}

private struct CAFPlayfieldAssetRecord: Decodable {
    let practiceIdentity: String
    let sourceOpdbMachineId: String?
    let coveredAliasIds: [String]?
    let playfieldLocalPath: String?
    let playfieldSourceUrl: String?
}

private struct CAFGameinfoAssetRecord: Decodable {
    let opdbId: String
    let localPath: String?
    let isHidden: Bool
    let isActive: Bool
}

private struct CAFVenueLayoutAssetRecord: Decodable {
    let sourceId: String
    let sourceName: String?
    let sourceType: String?
    let practiceIdentity: String?
    let opdbId: String
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
}

func catalogCuratedOverride(
    practiceIdentity: String?,
    opdbGroupID: String?,
    opdbID: String? = nil,
    overridesByKey: [String: LegacyCuratedOverride]
) -> LegacyCuratedOverride? {
    var candidateKeys: [String] = []

    func appendCandidateKey(_ value: String?) {
        guard let normalized = catalogNormalizedOptionalString(value),
              !candidateKeys.contains(normalized) else {
            return
        }
        candidateKeys.append(normalized)
    }

    appendCandidateKey(opdbID)
    appendCandidateKey(practiceIdentity)
    appendCandidateKey(opdbGroupID)

    for key in candidateKeys {
        if let override = overridesByKey[key] {
            return override
        }
    }
    return nil
}

func venueOverlayAreaKey(sourceID: String, area: String) -> String {
    "\(sourceID)::\(area)"
}

func venueOverlayMachineKey(sourceID: String, opdbID: String) -> String {
    "\(sourceID)::\(opdbID)"
}

func resolvedImportedVenueMetadata(
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

private func decodeCAFRecords<Record: Decodable>(_ type: Record.Type, data: Data?) -> [Record] {
    guard let data,
          !data.isEmpty,
          let root = try? JSONDecoder().decode(CAFRecordsRoot<Record>.self, from: data) else {
        return []
    }
    return root.records
}

func buildCAFOverrides(
    playfieldData: Data?,
    gameinfoData: Data?
) -> [String: LegacyCuratedOverride] {
    var overrides: [String: LegacyCuratedOverride] = [:]

    func upsertOverride(for key: String, mutate: (inout LegacyCuratedOverride) -> Void) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { return }
        var current = overrides[normalizedKey] ?? LegacyCuratedOverride(
            practiceIdentity: normalizedKey,
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
        mutate(&current)
        overrides[normalizedKey] = current
    }

    for asset in decodeCAFRecords(CAFPlayfieldAssetRecord.self, data: playfieldData) {
        let playfieldLocalPath = catalogNormalizedOptionalString(asset.playfieldLocalPath)
        let playfieldSourceURL = catalogNormalizedOptionalString(asset.playfieldSourceUrl)
        guard playfieldLocalPath != nil || playfieldSourceURL != nil else { continue }

        let keys = Array(
            Set(
                [
                    catalogNormalizedOptionalString(asset.practiceIdentity),
                    catalogNormalizedOptionalString(asset.sourceOpdbMachineId)
                ]
                .compactMap { $0 } + (asset.coveredAliasIds ?? []).compactMap(catalogNormalizedOptionalString)
            )
        )

        for key in keys {
            upsertOverride(for: key) { current in
                current.playfieldLocalPath = current.playfieldLocalPath ?? playfieldLocalPath
                current.playfieldSourceURL = current.playfieldSourceURL ?? playfieldSourceURL
            }
        }
    }

    for asset in decodeCAFRecords(CAFGameinfoAssetRecord.self, data: gameinfoData) where asset.isActive && !asset.isHidden {
        guard let localPath = catalogNormalizedOptionalString(asset.localPath) else { continue }
        let keys = [catalogNormalizedOptionalString(asset.opdbId)].compactMap { $0 }
        for key in keys {
            upsertOverride(for: key) { current in
                current.gameinfoLocalPath = current.gameinfoLocalPath ?? localPath
            }
        }
    }

    return overrides
}

func buildCAFGroupedRulesheetLinks(data: Data?) -> [String: [CatalogRulesheetLinkRecord]] {
    let records = decodeCAFRecords(CAFRulesheetAssetRecord.self, data: data)
        .filter { $0.isActive && !$0.isHidden }
        .compactMap { asset -> CatalogRulesheetLinkRecord? in
            let practiceIdentity = catalogNormalizedOptionalString(asset.opdbId)
            guard let practiceIdentity else { return nil }
            return CatalogRulesheetLinkRecord(
                practiceIdentity: practiceIdentity,
                provider: asset.provider,
                label: asset.label,
                localPath: catalogNormalizedOptionalString(asset.localPath),
                url: catalogNormalizedOptionalString(asset.url),
                priority: asset.priority
            )
        }
    return Dictionary(grouping: records, by: \.practiceIdentity)
}

func buildCAFGroupedVideoLinks(data: Data?) -> [String: [CatalogVideoLinkRecord]] {
    let records = decodeCAFRecords(CAFVideoAssetRecord.self, data: data)
        .filter { $0.isActive && !$0.isHidden }
        .compactMap { asset -> CatalogVideoLinkRecord? in
            let practiceIdentity = catalogNormalizedOptionalString(asset.opdbId)
            guard let practiceIdentity else { return nil }
            return CatalogVideoLinkRecord(
                practiceIdentity: practiceIdentity,
                provider: asset.provider,
                kind: asset.kind,
                label: asset.label,
                url: asset.url,
                priority: asset.priority
            )
        }
    return Dictionary(grouping: records, by: \.practiceIdentity)
}

func parseCAFVenueLayoutAssets(data: Data?) -> VenueMetadataOverlayIndex {
    let records = decodeCAFRecords(CAFVenueLayoutAssetRecord.self, data: data)
    let areaOrderByKey = dictionaryPreservingLastValue(records.compactMap { record -> (String, Int)? in
        guard let sourceID = canonicalLibrarySourceID(record.sourceId) ?? catalogNormalizedOptionalString(record.sourceId),
              let area = catalogNormalizedOptionalString(record.area),
              let areaOrder = record.areaOrder else {
            return nil
        }
        return (venueOverlayAreaKey(sourceID: sourceID, area: area), areaOrder)
    })
    let machineLayoutByKey = dictionaryPreservingLastValue(records.compactMap { record -> (String, VenueMachineLayoutOverlayRecord)? in
        guard let sourceID = canonicalLibrarySourceID(record.sourceId) ?? catalogNormalizedOptionalString(record.sourceId),
              record.groupNumber != nil || record.position != nil || catalogNormalizedOptionalString(record.area) != nil else {
            return nil
        }
        let layout = VenueMachineLayoutOverlayRecord(
            sourceID: sourceID,
            opdbID: record.opdbId,
            area: record.area,
            groupNumber: record.groupNumber,
            position: record.position
        )
        return (venueOverlayMachineKey(sourceID: sourceID, opdbID: record.opdbId), layout)
    })
    let machineBankByKey = dictionaryPreservingLastValue(records.compactMap { record -> (String, VenueMachineBankOverlayRecord)? in
        guard let sourceID = canonicalLibrarySourceID(record.sourceId) ?? catalogNormalizedOptionalString(record.sourceId),
              let bank = record.bank else { return nil }
        let bankRecord = VenueMachineBankOverlayRecord(
            sourceID: sourceID,
            opdbID: record.opdbId,
            bank: bank
        )
        return (venueOverlayMachineKey(sourceID: sourceID, opdbID: record.opdbId), bankRecord)
    })
    return VenueMetadataOverlayIndex(
        areaOrderByKey: areaOrderByKey,
        machineLayoutByKey: machineLayoutByKey,
        machineBankByKey: machineBankByKey
    )
}

func mergeVenueMetadataOverlayIndices(
    _ lhs: VenueMetadataOverlayIndex,
    _ rhs: VenueMetadataOverlayIndex
) -> VenueMetadataOverlayIndex {
    VenueMetadataOverlayIndex(
        areaOrderByKey: lhs.areaOrderByKey.merging(rhs.areaOrderByKey) { _, new in new },
        machineLayoutByKey: lhs.machineLayoutByKey.merging(rhs.machineLayoutByKey) { _, new in new },
        machineBankByKey: lhs.machineBankByKey.merging(rhs.machineBankByKey) { _, new in new }
    )
}

func buildCAFLibraryPayload(
    machines: [CatalogMachineRecord],
    importedSources: [PinballImportedSourceRecord],
    rulesheetLinksByPracticeIdentity: [String: [CatalogRulesheetLinkRecord]],
    videoLinksByPracticeIdentity: [String: [CatalogVideoLinkRecord]],
    curatedOverridesByKey: [String: LegacyCuratedOverride],
    venueMetadataOverlays: VenueMetadataOverlayIndex
) -> PinballLibraryPayload {
    guard !importedSources.isEmpty else {
        return PinballLibraryPayload(games: [], sources: [])
    }

    let machineByPracticeIdentity = Dictionary(grouping: machines, by: \.practiceIdentity)
    let machineByOPDBID = Dictionary(uniqueKeysWithValues: machines.compactMap { machine in
        catalogNormalizedOptionalString(machine.opdbMachineID).map { ($0, machine) }
    })

    var resolvedSources: [PinballLibrarySource] = []
    var resolvedGames: [PinballGame] = []

    for importedSource in importedSources {
        resolvedSources.append(
            PinballLibrarySource(id: importedSource.id, name: importedSource.name, type: importedSource.type)
        )

        switch importedSource.type {
        case .manufacturer:
            let groupedMachines = Dictionary(
                grouping: machines.filter { $0.manufacturerID == importedSource.providerSourceID },
                by: \.practiceIdentity
            )
            let sourceMachines = groupedMachines.values.compactMap { group in
                group.min(by: catalogPreferredManufacturerMachine)
            }
            .sorted { lhs, rhs in
                let leftYear = lhs.year ?? Int.max
                let rightYear = rhs.year ?? Int.max
                if leftYear != rightYear { return leftYear < rightYear }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            resolvedGames.append(contentsOf: sourceMachines.map { machine in
                resolveImportedGame(
                    machine: machine,
                    source: importedSource,
                    manufacturerByID: [:],
                    curatedOverride: catalogCuratedOverride(
                        practiceIdentity: machine.practiceIdentity,
                        opdbGroupID: machine.opdbGroupID,
                        opdbID: machine.opdbMachineID,
                        overridesByKey: curatedOverridesByKey
                    ),
                    opdbRulesheets: rulesheetLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    opdbVideos: videoLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    venueMetadata: nil
                )
            })
        case .venue, .tournament:
            let sourceMachines = importedSource.machineIDs.compactMap { requestedMachineID -> (String, CatalogMachineRecord)? in
                guard let machine = catalogPreferredMachineForSourceLookup(
                    requestedMachineID: requestedMachineID,
                    machineByOPDBID: machineByOPDBID,
                    machineByPracticeIdentity: machineByPracticeIdentity
                ) else {
                    return nil
                }
                return (requestedMachineID, machine)
            }

            resolvedGames.append(contentsOf: sourceMachines.map { requestedOpdbID, machine in
                resolveImportedGame(
                    machine: machine,
                    source: importedSource,
                    manufacturerByID: [:],
                    curatedOverride: catalogCuratedOverride(
                        practiceIdentity: machine.practiceIdentity,
                        opdbGroupID: machine.opdbGroupID,
                        opdbID: requestedOpdbID,
                        overridesByKey: curatedOverridesByKey
                    ),
                    opdbRulesheets: rulesheetLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    opdbVideos: videoLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    venueMetadata: importedSource.type == .venue
                        ? resolvedImportedVenueMetadata(
                            sourceID: importedSource.id,
                            requestedOpdbID: requestedOpdbID,
                            machine: machine,
                            overlays: venueMetadataOverlays
                        )
                        : nil
                )
            })
        case .category:
            continue
        }
    }

    return PinballLibraryPayload(
        games: resolvedGames,
        sources: catalogDedupedSources(resolvedSources)
    )
}

func buildCAFLibraryExtraction(
    opdbExportData: Data,
    practiceIdentityCurationsData: Data?,
    rulesheetAssetsData: Data?,
    videoAssetsData: Data?,
    playfieldAssetsData: Data?,
    gameinfoAssetsData: Data?,
    importedSources: [PinballImportedSourceRecord],
    venueMetadataOverlays: VenueMetadataOverlayIndex,
    filterBySourceState: Bool
) throws -> LibraryExtraction {
    let machines = try decodeOPDBExportCatalogMachines(data: opdbExportData, practiceIdentityCurationsData: practiceIdentityCurationsData)
    let payload = buildCAFLibraryPayload(
        machines: machines,
        importedSources: importedSources,
        rulesheetLinksByPracticeIdentity: buildCAFGroupedRulesheetLinks(data: rulesheetAssetsData),
        videoLinksByPracticeIdentity: buildCAFGroupedVideoLinks(data: videoAssetsData),
        curatedOverridesByKey: buildCAFOverrides(
            playfieldData: playfieldAssetsData,
            gameinfoData: gameinfoAssetsData
        ),
        venueMetadataOverlays: venueMetadataOverlays
    )
    let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
    return libraryExtraction(payload: payload, state: state, filterBySourceState: filterBySourceState)
}
