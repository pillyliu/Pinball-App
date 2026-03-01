import Foundation

struct LibraryGameLookupEntry {
    let normalizedName: String
    let area: String?
    let bank: Int?
    let group: Int?
    let position: Int?
    let order: Int
}

enum LibraryGameLookup {
    static let machineAliases: [String: [String]] = [
        "tmnt": ["teenagemutantninjaturtles"],
        "thegetaway": ["thegetawayhighspeedii"],
        "starwars2017": ["starwars"],
        "jurassicparkstern2019": ["jurassicpark", "jurassicpark2019"],
        "attackfrommars": ["attackfrommarsremake"],
        "dungeonsanddragons": ["dungeonsdragons"]
    ]

    static func buildEntries(games: [PinballGame]) -> [LibraryGameLookupEntry] {
        games.enumerated().compactMap { index, game -> LibraryGameLookupEntry? in
            let normalizedName = normalizeMachineName(game.name)
            guard !normalizedName.isEmpty else { return nil }
            return LibraryGameLookupEntry(
                normalizedName: normalizedName,
                area: game.area?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                bank: game.bank,
                group: game.group,
                position: game.pos,
                order: weightedOrder(index: index, group: game.group, position: game.pos)
            )
        }
    }

    static func bestMatch(gameName: String, entries: [LibraryGameLookupEntry]) -> LibraryGameLookupEntry? {
        let candidateKeys = Self.candidateKeys(gameName: gameName)
        guard !candidateKeys.isEmpty else { return nil }

        return entries.first(where: { candidateKeys.contains($0.normalizedName) })
            ?? entries.first(where: { entry in
                candidateKeys.contains { key in
                    entry.normalizedName.contains(key) || key.contains(entry.normalizedName)
                }
            })
    }

    static func bestMatch(gameName: String, games: [PinballGame]) -> PinballGame? {
        let candidateKeys = Self.candidateKeys(gameName: gameName)
        guard !candidateKeys.isEmpty else { return nil }

        return games.first(where: { candidateKeys.contains(normalizeMachineName($0.name)) })
            ?? games.first(where: { game in
                let normalizedName = normalizeMachineName(game.name)
                return candidateKeys.contains { key in
                    normalizedName.contains(key) || key.contains(normalizedName)
                }
            })
    }

    static func candidateKeys(gameName: String) -> [String] {
        let normalizedTarget = normalizeMachineName(gameName)
        guard !normalizedTarget.isEmpty else { return [] }
        return [normalizedTarget] + (machineAliases[normalizedTarget] ?? [])
    }

    static func normalizeMachineName(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func weightedOrder(index: Int, group: Int?, position: Int?) -> Int {
        if let group, let position {
            return (group * 1000) + position
        }
        return 100_000 + index
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
