import Foundation

nonisolated let pmAvenueLibrarySourceID = "venue--pm-8760"
nonisolated let pmRLMLibrarySourceID = "venue--pm-16470"
nonisolated let gameRoomLibrarySourceID = "venue--gameroom"

nonisolated private let builtinVenueSourceIDAliases: [String: String] = [
    "the-avenue": pmAvenueLibrarySourceID,
    "the-avenue-cafe": pmAvenueLibrarySourceID,
    "venue--the-avenue-cafe": pmAvenueLibrarySourceID,
    "rlm-amusements": pmRLMLibrarySourceID,
    "venue--rlm-amusements": pmRLMLibrarySourceID
]

nonisolated private let builtinVenueSourceNames: [String: String] = [
    pmRLMLibrarySourceID: "RLM Amusements",
    pmAvenueLibrarySourceID: "The Avenue Cafe",
    gameRoomLibrarySourceID: "GameRoom"
]

nonisolated let defaultBuiltinVenueSourceIDs: [String] = []

private struct LegacyPinballMapVenueMigrationTarget {
    let id: String
    let name: String
    let providerSourceID: String
}

nonisolated private let legacyPinballMapVenueMigrationTargets: [LegacyPinballMapVenueMigrationTarget] = [
    LegacyPinballMapVenueMigrationTarget(
        id: pmAvenueLibrarySourceID,
        name: "The Avenue Cafe",
        providerSourceID: "8760"
    ),
    LegacyPinballMapVenueMigrationTarget(
        id: pmRLMLibrarySourceID,
        name: "RLM Amusements",
        providerSourceID: "16470"
    )
]

nonisolated func canonicalBuiltinVenueLibrarySourceID(_ rawID: String?) -> String? {
    guard let trimmed = rawID?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return builtinVenueSourceIDAliases[trimmed]
}

nonisolated func canonicalLibrarySourceID(_ rawID: String?) -> String? {
    guard let trimmed = rawID?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return canonicalBuiltinVenueLibrarySourceID(trimmed) ?? trimmed
}

nonisolated func builtinVenueSources(includeGameRoom: Bool = false) -> [PinballLibrarySource] {
    var sourceIDs = defaultBuiltinVenueSourceIDs
    if includeGameRoom {
        sourceIDs.append(gameRoomLibrarySourceID)
    }
    return sourceIDs.compactMap { sourceID in
        guard let name = builtinVenueSourceNames[sourceID] else { return nil }
        return PinballLibrarySource(id: sourceID, name: name, type: .venue)
    }
}

nonisolated func isAvenueLibrarySourceID(_ rawID: String?) -> Bool {
    canonicalLibrarySourceID(rawID) == pmAvenueLibrarySourceID
}

nonisolated func isImportedPinballMapSourceID(_ rawID: String?) -> Bool {
    canonicalLibrarySourceID(rawID)?.lowercased().hasPrefix("venue--pm-") == true
}

func migrateLegacyPinnedVenueImportsIfNeeded() async {
    let sourceState = PinballLibrarySourceStateStore.load()
    let importedSources = PinballImportedSourcesStore.load()
    let importedIDs = Set(importedSources.map(\.id))
    let referencedSourceIDs = Set(
        sourceState.enabledSourceIDs +
        sourceState.pinnedSourceIDs +
        [sourceState.selectedSourceID].compactMap { $0 }
    )

    let targets = legacyPinballMapVenueMigrationTargets.filter { target in
        referencedSourceIDs.contains(target.id) && !importedIDs.contains(target.id)
    }
    guard !targets.isEmpty else { return }

    var didChange = false
    for target in targets {
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: target.providerSourceID)
            let record = PinballImportedSourceRecord(
                id: target.id,
                name: target.name,
                type: .venue,
                provider: .pinballMap,
                providerSourceID: target.providerSourceID,
                machineIDs: machineIDs,
                lastSyncedAt: Date(),
                searchQuery: nil,
                distanceMiles: nil
            )
            PinballImportedSourcesStore.upsert(record)
            didChange = true
        } catch {
            continue
        }
    }

    if didChange {
        postPinballLibrarySourcesDidChange()
    }
}
