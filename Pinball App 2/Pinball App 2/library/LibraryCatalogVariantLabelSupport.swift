import Foundation

nonisolated func catalogNormalizedVariant(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

nonisolated func catalogResolvedVariantLabel(title: String, explicitVariant: String?) -> String? {
    if let explicitVariant = catalogNormalizedVariantLabel(explicitVariant) {
        return explicitVariant
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedTitle.hasSuffix(")") else { return nil }
    guard let openParenIndex = trimmedTitle.lastIndex(of: "("), openParenIndex > trimmedTitle.startIndex else {
        return nil
    }

    let rawSuffix = trimmedTitle[trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)]
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard catalogLooksLikeVariantSuffix(rawSuffix) else { return nil }
    return catalogNormalizedVariantLabel(rawSuffix)
}

nonisolated func catalogResolvedDisplayTitle(title: String, explicitVariant: String?) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedTitle.hasSuffix(")") else { return trimmedTitle }
    guard let openParenIndex = trimmedTitle.lastIndex(of: "("), openParenIndex > trimmedTitle.startIndex else {
        return trimmedTitle
    }

    let rawSuffix = trimmedTitle[trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)]
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard catalogLooksLikeVariantSuffix(rawSuffix) else { return trimmedTitle }

    let normalizedSuffix = catalogNormalizedVariantLabel(rawSuffix)
    let normalizedExplicit = catalogNormalizedVariantLabel(explicitVariant)
    if let normalizedExplicit, let normalizedSuffix, normalizedExplicit != normalizedSuffix {
        return trimmedTitle
    }

    let baseTitle = trimmedTitle[..<openParenIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    return baseTitle.isEmpty ? trimmedTitle : baseTitle
}

nonisolated func catalogNormalizedVariantLabel(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    let lowered = trimmed.localizedLowercase
    if lowered == "null" || lowered == "none" {
        return nil
    }
    if lowered == "premium" { return "Premium" }
    if lowered == "pro" { return "Pro" }
    if lowered == "le" || lowered.contains("limited edition") { return "LE" }
    if lowered == "ce" || lowered.contains("collector") { return "CE" }
    if lowered == "se" || lowered.contains("special edition") { return "SE" }
    if lowered == "arcade" { return "Arcade" }
    if lowered == "wizard" { return "Wizard" }
    if lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" {
        return "Premium/LE"
    }
    if lowered.contains("anniversary") {
        return trimmed
            .split(separator: " ")
            .map { token in
                let loweredToken = token.localizedLowercase
                switch loweredToken {
                case "le", "ce", "se":
                    return loweredToken.uppercased()
                default:
                    return token.prefix(1).uppercased() + token.dropFirst()
                }
            }
            .joined(separator: " ")
    }
    return trimmed
}

private nonisolated func catalogLooksLikeVariantSuffix(_ value: String) -> Bool {
    let lowered = value.localizedLowercase
    return lowered == "premium" ||
        lowered == "pro" ||
        lowered == "le" ||
        lowered == "ce" ||
        lowered == "se" ||
        lowered == "home" ||
        lowered == "arcade" ||
        lowered == "wizard" ||
        lowered.contains("anniversary") ||
        lowered.contains("limited edition") ||
        lowered.contains("special edition") ||
        lowered.contains("collector") ||
        lowered == "premium/le" ||
        lowered == "premium le" ||
        lowered == "premium-le"
}
