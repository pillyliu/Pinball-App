import Foundation

nonisolated func parseBasicPinsideMachines(from html: String, groupMap: [String: String]) throws -> [PinsideImportedMachine] {
    try validatePinsideCollectionPageHTML(html)
    if looksLikePinsideCloudflareChallenge(html) {
        throw GameRoomPinsideImportError.parseFailed
    }

    let slugs = extractPinsideCollectionSlugs(from: html)
    guard !slugs.isEmpty else {
        throw GameRoomPinsideImportError.noMachinesFound
    }

    return slugs.map { slug in
        let rawTitle = resolvedPinsideTitle(for: slug, groupMap: groupMap)
        return PinsideImportedMachine(
            id: slug,
            slug: slug,
            rawTitle: rawTitle,
            rawVariant: pinsideVariantFromSlug(slug),
            manufacturerLabel: nil,
            manufactureYear: nil,
            rawPurchaseDateText: nil,
            normalizedPurchaseDate: nil
        )
    }
}
