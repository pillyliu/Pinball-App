import Foundation

extension GameRoomCatalogLoader {
    static func variantPreferenceRank(_ value: String?) -> Int {
        guard let normalized = normalizedVariant(value)?.localizedLowercase else {
            return 80
        }
        if normalized == "premium/le" || normalized == "premium le" || normalized == "premium-le" { return 30 }
        if normalized == "premium" || normalized.contains("premium") { return 0 }
        if normalized == "le" || normalized.contains("limited") { return 1 }
        if normalized == "pro" || normalized.contains("pro") { return 2 }
        if normalized.contains("standard") { return 10 }
        if normalized.contains("anniversary") { return 40 }
        if normalized.contains("home") { return 50 }
        return 20
    }

    static func sanitizedVariantOptions(_ values: [String]) -> [String] {
        var normalized = Set(values.compactMap(normalizedVariant))
        guard normalized.contains("Premium/LE") else {
            return Array(normalized)
        }

        normalized.remove("Premium/LE")
        normalized.insert("Premium")
        normalized.insert("LE")
        return Array(normalized)
    }

    static func normalizedVariant(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.localizedLowercase
        if lowered == "null" || lowered == "none" {
            return nil
        }
        if lowered == "premium" { return "Premium" }
        if lowered == "pro" { return "Pro" }
        if lowered == "le" || lowered.contains("limited edition") { return "LE" }
        if lowered == "ce" || lowered.contains("collector") { return "CE" }
        if lowered == "se" || lowered.contains("special edition") { return "SE" }
        if lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" {
            return "Premium/LE"
        }
        if lowered.contains("anniversary") {
            return trimmed
                .split(separator: " ")
                .map { token in
                    let loweredToken = token.localizedLowercase
                    if loweredToken == "le" || loweredToken == "ce" || loweredToken == "se" {
                        return loweredToken.uppercased()
                    }
                    return token.prefix(1).uppercased() + token.dropFirst().localizedLowercase
                }
                .joined(separator: " ")
        }
        return trimmed
    }

    static func variantMatchesSelection(candidate: String?, selected: String?) -> Bool {
        guard let candidate = normalizedVariant(candidate)?.localizedLowercase,
              let selected = normalizedVariant(selected)?.localizedLowercase else {
            return false
        }
        if candidate == selected {
            return true
        }
        if candidate == "premium/le" {
            return selected == "premium" || selected == "le"
        }
        return false
    }

    static func exactVariantMatchesSelection(candidate: String?, selected: String?) -> Bool {
        guard let candidate = normalizedVariant(candidate)?.localizedLowercase,
              let selected = normalizedVariant(selected)?.localizedLowercase else {
            return false
        }
        return candidate == selected
    }

    static func parsedCatalogName(title: String, explicitVariant: String?) -> (title: String, variant: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            catalogResolvedDisplayTitle(title: trimmedTitle, explicitVariant: explicitVariant),
            catalogResolvedVariantLabel(title: trimmedTitle, explicitVariant: explicitVariant)
        )
    }
}
