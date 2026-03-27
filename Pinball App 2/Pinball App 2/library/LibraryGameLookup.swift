import Foundation

enum LibraryGameLookup {
    static let machineAliases: [String: [String]] = [
        "tmnt": ["teenagemutantninjaturtles"],
        "thegetaway": ["thegetawayhighspeedii"],
        "starwars2017": ["starwars"],
        "jurassicparkstern2019": ["jurassicpark", "jurassicpark2019"],
        "attackfrommars": ["attackfrommarsremake"],
        "dungeonsanddragons": ["dungeonsdragons"]
    ]

    static func candidateKeys(gameName: String) -> [String] {
        let normalizedTarget = normalizeMachineName(gameName)
        guard !normalizedTarget.isEmpty else { return [] }
        return [normalizedTarget] + (machineAliases[normalizedTarget] ?? [])
    }

    static func equivalentKeys(gameName: String) -> Set<String> {
        equivalentKeys(normalizedName: normalizeMachineName(gameName))
    }

    static func equivalentKeys(normalizedName: String) -> Set<String> {
        guard !normalizedName.isEmpty else { return [] }

        var keys: Set<String> = [normalizedName]
        keys.formUnion(machineAliases[normalizedName] ?? [])

        for (primary, aliases) in machineAliases where aliases.contains(normalizedName) {
            keys.insert(primary)
            keys.formUnion(aliases)
        }

        return keys
    }

    static func normalizeMachineName(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}
