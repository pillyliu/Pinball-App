import Foundation

struct CAFRecordsRoot<Record: Decodable>: Decodable {
    let records: [Record]
}

struct CAFRulesheetAssetRecord: Decodable {
    let opdbId: String
    let provider: String
    let label: String
    let url: String?
    let localPath: String?
    let priority: Int?
    let isHidden: Bool
    let isActive: Bool
}

struct CAFVideoAssetRecord: Decodable {
    let opdbId: String
    let provider: String
    let kind: String
    let label: String
    let url: String
    let priority: Int?
    let isHidden: Bool
    let isActive: Bool
}

struct CAFPlayfieldAssetRecord: Decodable {
    let practiceIdentity: String
    let sourceOpdbMachineId: String?
    let coveredAliasIds: [String]?
    let playfieldLocalPath: String?
    let playfieldSourceUrl: String?
}

struct CAFGameinfoAssetRecord: Decodable {
    let opdbId: String
    let localPath: String?
    let isHidden: Bool
    let isActive: Bool
}

struct CAFVenueLayoutAssetRecord: Decodable {
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

func decodeCAFRecords<Record: Decodable>(_ type: Record.Type, data: Data?) -> [Record] {
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
