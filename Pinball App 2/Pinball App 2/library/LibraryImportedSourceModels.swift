import Foundation

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

func inferredImportedSourceProvider(type: PinballLibrarySourceType, id: String) -> PinballImportedSourceProvider {
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
