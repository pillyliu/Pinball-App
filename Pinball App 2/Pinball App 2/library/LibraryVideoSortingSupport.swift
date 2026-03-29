import Foundation

nonisolated func compareResolvedVideos(_ lhs: PinballGame.Video, _ rhs: PinballGame.Video) -> Bool {
    let leftKind = videoKindOrder(lhs.kind)
    let rightKind = videoKindOrder(rhs.kind)
    if leftKind != rightKind { return leftKind < rightKind }

    let leftLabel = resolvedVideoSortLabel(label: lhs.label, kind: lhs.kind)
    let rightLabel = resolvedVideoSortLabel(label: rhs.label, kind: rhs.kind)
    let labelComparison = naturalVideoLabelComparison(leftLabel, rightLabel)
    if labelComparison != .orderedSame { return labelComparison == .orderedAscending }

    let leftURL = catalogNormalizedOptionalString(lhs.url) ?? ""
    let rightURL = catalogNormalizedOptionalString(rhs.url) ?? ""
    if leftURL != rightURL {
        return leftURL.localizedCaseInsensitiveCompare(rightURL) == .orderedAscending
    }

    return false
}

nonisolated func videoProviderOrder(_ provider: String) -> Int {
    switch provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "local", "pinprof":
        return 0
    case "matchplay":
        return 1
    default:
        return 99
    }
}

nonisolated func videoKindOrder(_ kind: String?) -> Int {
    switch kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "tutorial":
        return 0
    case "gameplay":
        return 1
    case "competition":
        return 2
    default:
        return 99
    }
}

nonisolated private func resolvedVideoSortLabel(label: String?, kind: String?) -> String {
    if let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedLabel.isEmpty {
        return trimmedLabel
    }
    if let trimmedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedKind.isEmpty {
        return trimmedKind.replacingOccurrences(of: "_", with: " ")
    }
    return ""
}

nonisolated func naturalVideoLabelComparison(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let leftTokens = naturalVideoLabelTokens(lhs)
    let rightTokens = naturalVideoLabelTokens(rhs)
    let count = min(leftTokens.count, rightTokens.count)

    for index in 0..<count {
        let left = leftTokens[index]
        let right = rightTokens[index]

        if left.isNumber && right.isNumber {
            let leftValue = Int(left.text) ?? Int.max
            let rightValue = Int(right.text) ?? Int.max
            if leftValue != rightValue {
                return leftValue < rightValue ? .orderedAscending : .orderedDescending
            }
            if left.text.count != right.text.count {
                return left.text.count < right.text.count ? .orderedAscending : .orderedDescending
            }
            continue
        }

        let comparison = left.text.localizedCaseInsensitiveCompare(right.text)
        if comparison != .orderedSame {
            return comparison
        }
    }

    if leftTokens.count != rightTokens.count {
        return leftTokens.count < rightTokens.count ? .orderedAscending : .orderedDescending
    }

    return lhs.localizedCaseInsensitiveCompare(rhs)
}

nonisolated private struct NaturalVideoLabelToken {
    let text: String
    let isNumber: Bool
}

nonisolated private func naturalVideoLabelTokens(_ label: String) -> [NaturalVideoLabelToken] {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return [] }

    var tokens: [NaturalVideoLabelToken] = []
    var current = String(first)
    var currentIsNumber = first.isNumber

    for character in trimmed.dropFirst() {
        if character.isNumber == currentIsNumber {
            current.append(character)
        } else {
            tokens.append(NaturalVideoLabelToken(text: current, isNumber: currentIsNumber))
            current = String(character)
            currentIsNumber = character.isNumber
        }
    }

    tokens.append(NaturalVideoLabelToken(text: current, isNumber: currentIsNumber))
    return tokens
}
