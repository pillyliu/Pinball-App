import Foundation

struct LeagueMachineMappingRecord: Decodable {
    let machine: String
    let practiceIdentity: String?
    let opdbID: String?

    enum CodingKeys: String, CodingKey {
        case machine
        case practiceIdentity = "practice_identity"
        case opdbID = "opdb_id"
    }
}

private struct LeagueMachineMappingsRoot: Decodable {
    let version: Int
    let items: [LeagueMachineMappingRecord]
}

func parseLeagueMachineMappings(text: String) -> [String: LeagueMachineMappingRecord] {
    guard let data = text.data(using: .utf8) ?? text.data(using: .unicode) else { return [:] }
    let decoder = JSONDecoder()
    guard let root = try? decoder.decode(LeagueMachineMappingsRoot.self, from: data), root.version >= 1 else {
        return [:]
    }

    var out: [String: LeagueMachineMappingRecord] = [:]
    for record in root.items {
        let key = LibraryGameLookup.normalizeMachineName(record.machine)
        guard !key.isEmpty else { continue }
        out[key] = record
    }
    return out
}
