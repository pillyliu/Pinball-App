import Foundation

private let humanNameSuffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv", "v"]

private func normalizedHumanNameTokens(_ raw: String) -> [String] {
    raw
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        .split(separator: " ")
        .map(String.init)
}

private func relaxedHumanNameTokens(_ raw: String) -> [String] {
    let baseTokens = normalizedHumanNameTokens(raw)
    guard !baseTokens.isEmpty else { return [] }

    let withoutSuffixes = baseTokens.filter { !humanNameSuffixes.contains($0) }
    guard withoutSuffixes.count > 2 else { return withoutSuffixes }

    return withoutSuffixes.enumerated().compactMap { index, token in
        let isFirstOrLast = index == 0 || index == withoutSuffixes.count - 1
        if isFirstOrLast || token.count > 1 {
            return token
        }
        return nil
    }
}

private func joinedHumanNameTokens(_ tokens: [String]) -> String {
    tokens.joined(separator: " ")
}

private func humanNameKeys(_ raw: String) -> Set<String> {
    let strict = joinedHumanNameTokens(normalizedHumanNameTokens(raw))
    let relaxed = joinedHumanNameTokens(relaxedHumanNameTokens(raw))
    return Set([strict, relaxed].filter { !$0.isEmpty })
}

private func softHumanNameMatches(_ left: String, _ right: String) -> Bool {
    let leftTokens = relaxedHumanNameTokens(left)
    let rightTokens = relaxedHumanNameTokens(right)
    guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }
    if leftTokens == rightTokens {
        return true
    }
    guard leftTokens.count >= 2, rightTokens.count >= 2 else { return false }
    guard leftTokens.last == rightTokens.last else { return false }

    let leftFirst = leftTokens[0]
    let rightFirst = rightTokens[0]
    if leftFirst == rightFirst {
        return true
    }
    guard min(leftFirst.count, rightFirst.count) >= 3 else { return false }
    return leftFirst.hasPrefix(rightFirst) || rightFirst.hasPrefix(leftFirst)
}

extension PracticeStore {
    func normalizeHumanName(_ raw: String) -> String {
        raw
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

extension Array where Element == PracticeStore.LeagueIFPAPlayerRecord {
    func matchedApprovedIFPAPlayer(for inputName: String) -> PracticeStore.LeagueIFPAPlayerRecord? {
        let inputKeys = humanNameKeys(inputName)
        let exactMatches = filter { record in
            let candidateKeys = humanNameKeys(record.player).union(humanNameKeys(record.ifpaName))
            return !candidateKeys.isDisjoint(with: inputKeys)
        }
        if exactMatches.count == 1 {
            return exactMatches[0]
        }
        if exactMatches.count > 1 {
            return nil
        }

        let softMatches = filter { record in
            softHumanNameMatches(inputName, record.player) || softHumanNameMatches(inputName, record.ifpaName)
        }
        return softMatches.count == 1 ? softMatches[0] : nil
    }
}
