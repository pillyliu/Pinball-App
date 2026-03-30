import SwiftUI

struct ImportMatcher {
    let store: GameRoomStore
    let catalogLoader: GameRoomCatalogLoader

    func needsReview(_ row: ImportDraftRow) -> Bool {
        row.matchConfidence != .high || row.selectedCatalogGameID == nil || duplicateWarningMessage(for: row) != nil
    }

    func duplicateWarningMessage(for row: ImportDraftRow) -> String? {
        if store.hasImportFingerprint(row.fingerprint) {
            return "Already imported previously."
        }
        guard let selectedCatalogGameID = row.selectedCatalogGameID,
              let selectedGame = catalogLoader.game(for: selectedCatalogGameID) else {
            return nil
        }
        let selectedVariant = row.selectedVariant ?? row.rawVariant
        if let existing = store.existingOwnedMachine(catalogGameID: selectedGame.catalogGameID, displayVariant: selectedVariant) {
            if let variant = existing.displayVariant, !variant.isEmpty {
                return "Duplicate of existing machine: \(existing.displayTitle) (\(variant))."
            }
            return "Duplicate of existing machine: \(existing.displayTitle)."
        }
        return nil
    }

    func importVariantOptions(for row: ImportDraftRow, selectedCatalogGameID: String) -> [String] {
        var variants: [String] = []

        if let currentVariant = row.selectedVariant?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentVariant.isEmpty {
            variants.append(currentVariant)
        }
        if let rawVariant = row.rawVariant?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawVariant.isEmpty,
           !variants.contains(where: { $0.caseInsensitiveCompare(rawVariant) == .orderedSame }) {
            variants.append(rawVariant)
        }
        for variant in catalogLoader.variantOptions(for: selectedCatalogGameID) {
            if !variants.contains(where: { $0.caseInsensitiveCompare(variant) == .orderedSame }) {
                variants.append(variant)
            }
        }

        return variants
    }

    func makeDraftRow(_ machine: PinsideImportedMachine) -> ImportDraftRow {
        let scored = scoredSuggestions(for: machine)
        let suggestions = scored.map(\.game)
        let top = scored.first

        return ImportDraftRow(
            id: machine.id,
            sourceItemKey: machine.slug,
            rawTitle: machine.rawTitle,
            rawPurchaseDateText: machine.rawPurchaseDateText,
            normalizedPurchaseDate: machine.normalizedPurchaseDate,
            matchConfidence: confidence(for: top?.score ?? 0),
            suggestions: suggestions,
            fingerprint: machine.fingerprint,
            selectedCatalogGameID: top?.game.catalogGameID,
            selectedVariant: machine.rawVariant,
            rawVariant: machine.rawVariant
        )
    }
}
