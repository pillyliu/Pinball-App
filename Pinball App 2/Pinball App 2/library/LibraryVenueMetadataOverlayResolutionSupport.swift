import Foundation

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
