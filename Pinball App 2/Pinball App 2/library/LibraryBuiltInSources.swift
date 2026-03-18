import Foundation

let pmAvenueLibrarySourceID = "venue--pm-8760"
let pmRLMLibrarySourceID = "venue--pm-16470"
let gameRoomLibrarySourceID = "venue--gameroom"

private let builtinVenueSourceIDAliases: [String: String] = [
    "the-avenue": pmAvenueLibrarySourceID,
    "the-avenue-cafe": pmAvenueLibrarySourceID,
    "venue--the-avenue-cafe": pmAvenueLibrarySourceID,
    "rlm-amusements": pmRLMLibrarySourceID,
    "venue--rlm-amusements": pmRLMLibrarySourceID
]

private let builtinVenueSourceNames: [String: String] = [
    pmRLMLibrarySourceID: "RLM Amusements",
    pmAvenueLibrarySourceID: "The Avenue Cafe",
    gameRoomLibrarySourceID: "GameRoom"
]

let defaultBuiltinVenueSourceIDs = [
    pmRLMLibrarySourceID,
    pmAvenueLibrarySourceID
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

nonisolated func builtinVenueSourceName(for rawID: String?) -> String? {
    guard let canonicalID = canonicalLibrarySourceID(rawID) else { return nil }
    return builtinVenueSourceNames[canonicalID]
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
