import Foundation

nonisolated func canonicalPinsideDisplayedTitle(_ title: String, fallbackVariant: String?) -> (title: String, variant: String?) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedTitle.hasSuffix(")"),
          let openParenIndex = trimmedTitle.lastIndex(of: "(") else {
        return (trimmedTitle, fallbackVariant)
    }

    let baseTitle = String(trimmedTitle[..<openParenIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    let rawVariant = String(trimmedTitle[trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !baseTitle.isEmpty else {
        return (trimmedTitle, fallbackVariant)
    }

    let normalizedVariant = normalizedPinsideVariantLabel(rawVariant)
    let resolvedVariant = preferredPinsideVariantLabel(
        parsedVariant: normalizedVariant,
        fallbackVariant: fallbackVariant
    )
    guard let resolvedVariant else {
        return (trimmedTitle, fallbackVariant)
    }
    return (baseTitle, resolvedVariant)
}

nonisolated func pinsideVariantFromSlug(_ slug: String) -> String? {
    let lowered = slug.lowercased()
    if let anniversary = pinsideAnniversaryVariant(from: lowered) {
        return anniversary
    }
    if lowered.hasSuffix("-premium") { return "Premium" }
    if lowered.hasSuffix("-pro") { return "Pro" }
    if lowered.hasSuffix("-le") || lowered.contains("-limited-edition") { return "LE" }
    if lowered.hasSuffix("-ce") || lowered.contains("-collector") { return "CE" }
    if lowered.hasSuffix("-se") || lowered.contains("-special-edition") { return "SE" }
    return nil
}

nonisolated func resolvedPinsideTitle(for slug: String, groupMap: [String: String]) -> String {
    if let mapped = groupMap[slug]?.trimmingCharacters(in: .whitespacesAndNewlines),
       !mapped.isEmpty,
       mapped != "~" {
        return mapped
    }
    return humanizedPinsideTitle(fromSlug: slug)
}

nonisolated private func preferredPinsideVariantLabel(parsedVariant: String?, fallbackVariant: String?) -> String? {
    let parsedTrimmed = parsedVariant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let normalizedParsed = parsedTrimmed.isEmpty ? nil : parsedTrimmed
    let fallbackTrimmed = fallbackVariant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let normalizedFallback = fallbackTrimmed.isEmpty ? nil : fallbackTrimmed
    guard let normalizedParsed else { return normalizedFallback }
    guard let normalizedFallback else { return normalizedParsed }

    let parsedLower = normalizedParsed.lowercased()
    let fallbackLower = normalizedFallback.lowercased()
    let bothAnniversary = parsedLower.contains("anniversary") && fallbackLower.contains("anniversary")
    if bothAnniversary {
        if parsedLower == fallbackLower {
            return normalizedFallback
        }
        if parsedLower.hasPrefix("\(fallbackLower) ") {
            return normalizedFallback
        }
    }
    return normalizedParsed
}

nonisolated private func normalizedPinsideVariantLabel(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = trimmed.lowercased()
    guard !lowered.isEmpty else { return nil }
    if lowered == "premium" || lowered == "premium edition" { return "Premium" }
    if lowered == "pro" || lowered == "pro edition" { return "Pro" }
    if lowered == "le" || lowered == "limited edition" { return "LE" }
    if lowered == "ce" || lowered.contains("collector") { return "CE" }
    if lowered == "se" || lowered.contains("special edition") { return "SE" }
    if lowered.contains("anniversary") { return trimmed }
    return nil
}

nonisolated private func pinsideAnniversaryVariant(from loweredSlug: String) -> String? {
    let pattern = #"(\d+)(st|nd|rd|th)-anniversary"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return loweredSlug.contains("anniversary") ? "Anniversary" : nil
    }
    let nsRange = NSRange(loweredSlug.startIndex..<loweredSlug.endIndex, in: loweredSlug)
    guard let match = regex.firstMatch(in: loweredSlug, options: [], range: nsRange) else {
        return loweredSlug.contains("anniversary") ? "Anniversary" : nil
    }
    guard
        match.numberOfRanges >= 3,
        let numberRange = Range(match.range(at: 1), in: loweredSlug),
        let suffixRange = Range(match.range(at: 2), in: loweredSlug)
    else {
        return "Anniversary"
    }
    let number = loweredSlug[numberRange]
    let suffix = loweredSlug[suffixRange].lowercased()
    return "\(number)\(suffix) Anniversary"
}

nonisolated private func humanizedPinsideTitle(fromSlug slug: String) -> String {
    slug
        .split(separator: "-")
        .map { $0.capitalized }
        .joined(separator: " ")
}

nonisolated func parsePinsideDisplayedTitle(_ title: String, fallbackVariant: String?) -> (title: String, variant: String?) {
    canonicalPinsideDisplayedTitle(title, fallbackVariant: fallbackVariant)
}
