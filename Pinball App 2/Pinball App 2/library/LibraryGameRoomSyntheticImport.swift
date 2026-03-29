import Foundation

struct GameRoomLibrarySyntheticImport {
    let importedSource: PinballImportedSourceRecord
    let venueMetadataOverlays: VenueMetadataOverlayIndex
}

func loadGameRoomLibrarySyntheticImport() -> GameRoomLibrarySyntheticImport? {
    switch GameRoomStateCodec.loadFromDefaults(
        UserDefaults.standard,
        storageKey: GameRoomStore.storageKey,
        legacyStorageKey: GameRoomStore.legacyStorageKey
    ) {
    case .missing, .failed:
        return nil
    case let .loaded(state, _, _):
        return buildGameRoomLibrarySyntheticImport(from: state)
    }
}

private func buildGameRoomLibrarySyntheticImport(
    from state: GameRoomPersistedState
) -> GameRoomLibrarySyntheticImport? {
    let venueName = normalizedGameRoomVenueName(state.venueName)
    let areasByID = Dictionary(uniqueKeysWithValues: state.areas.map { ($0.id, $0) })
    let activeMachines = state.ownedMachines
        .filter { $0.status.countsAsActiveInventory }
        .sorted { lhs, rhs in
            compareGameRoomOwnedMachinesForLibrary(lhs: lhs, rhs: rhs, areasByID: areasByID)
        }

    guard !activeMachines.isEmpty else {
        return nil
    }

    var seenMachineIDs = Set<String>()
    var orderedMachineIDs: [String] = []
    var areaOrderPairs: [(String, Int)] = []
    var machineLayoutPairs: [(String, VenueMachineLayoutOverlayRecord)] = []

    for ownedMachine in activeMachines {
        guard let exactOpdbID = gameRoomExactOpdbID(ownedMachine) else {
            print("GameRoom synthetic library import skipped machine without exact opdb_id: \(ownedMachine.id.uuidString)")
            continue
        }

        if !seenMachineIDs.insert(exactOpdbID).inserted {
            print("GameRoom synthetic library import found duplicate opdb_id: \(exactOpdbID)")
            continue
        }

        orderedMachineIDs.append(exactOpdbID)

        let area = ownedMachine.gameRoomAreaID.flatMap { areasByID[$0] }
        if let normalizedArea = catalogNormalizedOptionalString(area?.name) {
            areaOrderPairs.append((
                venueOverlayAreaKey(sourceID: gameRoomLibrarySourceID, area: normalizedArea),
                max(area?.areaOrder ?? 1, 1)
            ))
        }

        guard area != nil || ownedMachine.groupNumber != nil || ownedMachine.position != nil else {
            continue
        }

        machineLayoutPairs.append((
            venueOverlayMachineKey(sourceID: gameRoomLibrarySourceID, opdbID: exactOpdbID),
            VenueMachineLayoutOverlayRecord(
                sourceID: gameRoomLibrarySourceID,
                opdbID: exactOpdbID,
                area: area?.name,
                groupNumber: ownedMachine.groupNumber,
                position: ownedMachine.position
            )
        ))
    }

    guard !orderedMachineIDs.isEmpty else {
        return nil
    }

    return GameRoomLibrarySyntheticImport(
        importedSource: PinballImportedSourceRecord(
            id: gameRoomLibrarySourceID,
            name: venueName,
            type: .venue,
            provider: .opdb,
            providerSourceID: gameRoomLibrarySourceID,
            machineIDs: orderedMachineIDs,
            lastSyncedAt: nil,
            searchQuery: nil,
            distanceMiles: nil
        ),
        venueMetadataOverlays: VenueMetadataOverlayIndex(
            areaOrderByKey: dictionaryPreservingLastValue(areaOrderPairs),
            machineLayoutByKey: dictionaryPreservingLastValue(machineLayoutPairs),
            machineBankByKey: [:]
        )
    )
}

private func normalizedGameRoomVenueName(_ rawValue: String) -> String {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? GameRoomPersistedState.defaultVenueName : trimmed
}

private func compareGameRoomOwnedMachinesForLibrary(
    lhs: OwnedMachine,
    rhs: OwnedMachine,
    areasByID: [UUID: GameRoomArea]
) -> Bool {
    let lhsArea = lhs.gameRoomAreaID.flatMap { areasByID[$0] }
    let rhsArea = rhs.gameRoomAreaID.flatMap { areasByID[$0] }

    let lhsAreaOrder = lhsArea?.areaOrder ?? Int.max
    let rhsAreaOrder = rhsArea?.areaOrder ?? Int.max
    if lhsAreaOrder != rhsAreaOrder { return lhsAreaOrder < rhsAreaOrder }

    let lhsAreaName = lhsArea?.name.lowercased() ?? ""
    let rhsAreaName = rhsArea?.name.lowercased() ?? ""
    if lhsAreaName != rhsAreaName { return lhsAreaName < rhsAreaName }

    let lhsGroup = lhs.groupNumber ?? Int.max
    let rhsGroup = rhs.groupNumber ?? Int.max
    if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

    let lhsPosition = lhs.position ?? Int.max
    let rhsPosition = rhs.position ?? Int.max
    if lhsPosition != rhsPosition { return lhsPosition < rhsPosition }

    let lhsTitle = lhs.displayTitle.lowercased()
    let rhsTitle = rhs.displayTitle.lowercased()
    if lhsTitle != rhsTitle { return lhsTitle < rhsTitle }

    return lhs.id.uuidString < rhs.id.uuidString
}

private func gameRoomExactOpdbID(_ ownedMachine: OwnedMachine) -> String? {
    catalogNormalizedOptionalString(ownedMachine.opdbID)
}
