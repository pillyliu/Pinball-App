import Foundation

struct PinballLibraryPayload {
    let games: [PinballGame]
    let sources: [PinballLibrarySource]
}

private struct PinballLibraryRoot: Decodable {
    let games: [PinballGame]?
    let items: [PinballGame]?
    let sources: [PinballLibrarySourcePayload]?
    let libraries: [PinballLibrarySourcePayload]?
}

private struct PinballLibrarySourcePayload: Decodable {
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

func decodeLibraryPayload(data: Data) throws -> PinballLibraryPayload {
    try decodeLibraryPayloadWithState(data: data).payload
}

nonisolated func libraryInferSources(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen: [PinballLibrarySource] = []
    var ids = Set<String>()
    for game in games {
        if ids.contains(game.sourceId) { continue }
        ids.insert(game.sourceId)
        seen.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
    }
    if seen.isEmpty {
        seen.append(PinballLibrarySource(id: "the-avenue", name: "The Avenue", type: .venue))
    }
    return seen
}

nonisolated func libraryParseSourceType(_ raw: String?) -> PinballLibrarySourceType {
    let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized == "manufacturer" {
        return .manufacturer
    }
    if normalized == "category" {
        return .category
    }
    if normalized == "tournament" {
        return .tournament
    }
    return .venue
}

nonisolated func librarySlugifySourceID(_ value: String) -> String {
    let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lower.isEmpty { return "the-avenue" }
    let mapped = lower
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return mapped.isEmpty ? "the-avenue" : mapped
}

nonisolated func libraryNormalizedOptionalString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
