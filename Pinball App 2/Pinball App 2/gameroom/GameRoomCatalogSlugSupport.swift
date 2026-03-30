import Foundation
import OSLog

extension GameRoomCatalogLoader {
    static func slugMatches(from machines: [CatalogMachineRecord]) -> [String: GameRoomCatalogSlugMatch] {
        var matches: [String: GameRoomCatalogSlugMatch] = [:]

        for machine in machines {
            let catalogGameID = machine.practiceIdentity
            let parsedName = parsedCatalogName(title: machine.name, explicitVariant: machine.variant)
            let match = GameRoomCatalogSlugMatch(
                catalogGameID: catalogGameID,
                canonicalPracticeIdentity: machine.practiceIdentity,
                variant: parsedName.variant
            )
            for key in buildSlugKeys(from: machine.slug) {
                if let existing = matches[key] {
                    gameRoomCatalogLogger.warning(
                        "Duplicate GameRoom catalog slug key \(key, privacy: .public); keeping existing catalog game \(existing.catalogGameID, privacy: .public) and ignoring \(match.catalogGameID, privacy: .public)"
                    )
                    continue
                }
                matches[key] = match
            }
        }

        return matches
    }

    static func buildSlugKeys(from slug: String) -> [String] {
        let lowered = slug.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !lowered.isEmpty else { return [] }

        var keys: [String] = []

        func appendKey(_ value: String) {
            guard !value.isEmpty, !keys.contains(value) else { return }
            keys.append(value)
        }

        appendKey(lowered)
        let normalized = normalizedSlugForMatching(lowered)
        appendKey(normalized)
        let stripped = stripVariantSuffix(from: normalized)
        if !stripped.isEmpty {
            appendKey(stripped)
        }
        return keys
    }

    static func normalizedSlugForMatching(_ slug: String) -> String {
        let prefixTokens = Set([
            "stern",
            "williams",
            "bally",
            "gottlieb",
            "spooky",
            "jersey",
            "jack",
            "american",
            "pinball",
            "chicago",
            "gaming",
            "company",
            "sega",
            "data",
            "east"
        ])

        var tokens = slug.split(separator: "-").map(String.init)
        while let first = tokens.first, prefixTokens.contains(first) {
            tokens.removeFirst()
        }

        let yearPattern = try? NSRegularExpression(pattern: #"^(19|20)\d{2}$"#)
        let filtered = tokens.filter { token in
            let range = NSRange(token.startIndex..<token.endIndex, in: token)
            return yearPattern?.firstMatch(in: token, options: [], range: range) == nil
        }
        return filtered.joined(separator: "-")
    }

    static func stripVariantSuffix(from slug: String) -> String {
        let suffixTokens = Set([
            "premium",
            "pro",
            "le",
            "ce",
            "se",
            "limited",
            "edition",
            "collector",
            "collectors"
        ])

        var tokens = slug.split(separator: "-").map(String.init)
        while let last = tokens.last, suffixTokens.contains(last) {
            tokens.removeLast()
        }
        return tokens.joined(separator: "-")
    }

    static func resolveURL(pathOrURL: String) -> URL? {
        if let direct = URL(string: pathOrURL), direct.scheme != nil {
            return direct
        }
        if pathOrURL.hasPrefix("/") {
            return URL(string: "https://pillyliu.com\(pathOrURL)")
        }
        return URL(string: "https://pillyliu.com/\(pathOrURL)")
    }
}
