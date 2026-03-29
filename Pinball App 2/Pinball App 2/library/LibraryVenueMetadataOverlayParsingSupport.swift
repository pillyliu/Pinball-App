import Foundation

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
