import Foundation

nonisolated func normalizedSearchTokens(_ value: String) -> [String] {
    value
        .folding(options: [.diacriticInsensitive], locale: .current)
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
}

nonisolated func matchesSearchQuery(_ query: String, fields: [String?]) -> Bool {
    let queryTokens = normalizedSearchTokens(query)
    guard !queryTokens.isEmpty else { return true }

    let haystackTokens = fields.flatMap { normalizedSearchTokens($0 ?? "") }
    guard !haystackTokens.isEmpty else { return false }

    return matchesSearchTokens(queryTokens, haystackTokens: haystackTokens)
}

nonisolated func matchesSearchTokens(_ queryTokens: [String], haystackTokens: [String]) -> Bool {
    guard !queryTokens.isEmpty else { return true }
    guard !haystackTokens.isEmpty else { return false }
    return queryTokens.allSatisfy { queryToken in
        haystackTokens.contains { haystackToken in
            haystackToken.contains(queryToken)
        }
    }
}
