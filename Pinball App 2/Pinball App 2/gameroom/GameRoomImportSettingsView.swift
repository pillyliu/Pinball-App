import SwiftUI

struct GameRoomImportSettingsView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    private let importService = GameRoomPinsideImportService()
    @State private var sourceInput = ""
    @State private var importedSourceURL = ""
    @State private var draftRows: [ImportDraftRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?
    @State private var reviewFilter: ImportReviewFilter = .all

    private var importMatcher: ImportMatcher {
        ImportMatcher(store: store, catalogLoader: catalogLoader)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameRoomImportSourceSection(
                sourceInput: $sourceInput,
                isLoading: isLoading,
                errorMessage: errorMessage,
                canFetchCollection: canFetchCollection,
                onFetchCollection: fetchCollectionIfPossible
            )

            if !draftRows.isEmpty {
                GameRoomImportReviewSection(
                    draftRows: $draftRows,
                    reviewFilter: $reviewFilter,
                    filteredRowIndexes: filteredRowIndexes,
                    duplicateWarningMessage: importMatcher.duplicateWarningMessage(for:),
                    matchLabel: importMatcher.matchLabel(for:),
                    importVariantOptions: importMatcher.importVariantOptions(for:selectedCatalogGameID:),
                    normalizePurchaseDate: importMatcher.normalizedFirstOfMonth(from:),
                    onImport: performImport
                )
            }

            if let resultMessage {
                Text(resultMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Import records stored: \(store.state.importRecords.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var canFetchCollection: Bool {
        !isLoading && !sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredRowIndexes: [Int] {
        draftRows.indices.filter { index in
            switch reviewFilter {
            case .all:
                return true
            case .needsReview:
                return importMatcher.needsReview(draftRows[index])
            }
        }
    }

    private func fetchCollectionIfPossible() {
        guard canFetchCollection else { return }
        fetchCollection()
    }

    private func fetchCollection() {
        errorMessage = nil
        resultMessage = nil
        isLoading = true
        let input = sourceInput

        Task {
            do {
                let result = try await importService.fetchCollectionMachines(sourceInput: input)
                let rows = result.machines.map(importMatcher.makeDraftRow)
                await MainActor.run {
                    importedSourceURL = result.sourceURL
                    draftRows = rows
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    importedSourceURL = ""
                    draftRows = []
                    isLoading = false
                }
            }
        }
    }

    private func performImport() {
        guard !draftRows.isEmpty else { return }

        var importedCount = 0
        var skippedDuplicates = 0
        var skippedUnmatched = 0

        for row in draftRows {
            guard let selectedCatalogGameID = row.selectedCatalogGameID,
                  let game = catalogLoader.game(for: selectedCatalogGameID) else {
                skippedUnmatched += 1
                continue
            }

            if store.hasImportFingerprint(row.fingerprint) ||
                store.hasOwnedMachine(catalogGameID: game.catalogGameID, displayVariant: row.selectedVariant ?? row.rawVariant) {
                skippedDuplicates += 1
                continue
            }

            _ = store.importOwnedMachine(
                game: game,
                sourceUserOrURL: importedSourceURL,
                sourceItemKey: row.sourceItemKey,
                rawTitle: row.rawTitle,
                rawVariant: row.selectedVariant ?? row.rawVariant,
                rawPurchaseDateText: row.rawPurchaseDateText,
                normalizedPurchaseDate: row.normalizedPurchaseDate,
                matchConfidence: row.matchConfidence,
                fingerprint: row.fingerprint
            )
            importedCount += 1
        }

        resultMessage = "Imported \(importedCount). Skipped \(skippedDuplicates) duplicates, \(skippedUnmatched) unmatched."
    }
}
