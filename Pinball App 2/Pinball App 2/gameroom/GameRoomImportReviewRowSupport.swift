import SwiftUI

struct GameRoomImportReviewRowCard: View {
    @Binding var row: ImportDraftRow
    let duplicateWarning: String?
    let matchLabel: (GameRoomCatalogGame) -> String
    let importVariantOptions: (ImportDraftRow, String) -> [String]
    let normalizePurchaseDate: (String?) -> Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.rawTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                confidenceBadge(row.matchConfidence)
            }

            if let rawVariant = row.rawVariant, !rawVariant.isEmpty {
                Text("Variant: \(rawVariant)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField(
                "Purchase date (raw import text)",
                text: purchaseDateBinding
            )
            .textFieldStyle(.roundedBorder)

            if let normalizedPurchaseDate = row.normalizedPurchaseDate {
                Text("Normalized: \(normalizedPurchaseDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let duplicateWarning {
                Text(duplicateWarning)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.yellow)
            }

            Menu {
                ForEach(row.suggestions, id: \.id) { suggestion in
                    Button(matchLabel(suggestion)) {
                        selectSuggestion(suggestion)
                    }
                }
                Button("Clear Match") {
                    clearMatch()
                }
            } label: {
                AppCompactIconMenuLabel(
                    text: matchMenuLabel,
                    systemName: "link"
                )
            }
            .buttonStyle(.plain)

            if let selectedCatalogGameID = row.selectedCatalogGameID {
                let variants = importVariantOptions(row, selectedCatalogGameID)
                if !variants.isEmpty {
                    Menu {
                        Button("None") {
                            row.selectedVariant = nil
                        }
                        ForEach(variants, id: \.self) { variant in
                            Button(variant) {
                                row.selectedVariant = variant
                            }
                        }
                    } label: {
                        AppCompactIconMenuLabel(
                            text: "Variant: \(row.selectedVariant ?? "None")",
                            systemName: "tag"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .appControlStyle()
    }

    private var purchaseDateBinding: Binding<String> {
        Binding(
            get: { row.rawPurchaseDateText ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                row.rawPurchaseDateText = trimmed.isEmpty ? nil : trimmed
                row.normalizedPurchaseDate = normalizePurchaseDate(row.rawPurchaseDateText)
            }
        )
    }

    private var matchMenuLabel: String {
        guard let selectedCatalogGameID = row.selectedCatalogGameID,
              let selected = row.suggestions.first(where: { $0.catalogGameID == selectedCatalogGameID }) else {
            return "No Match Selected"
        }
        return "Match: \(matchLabel(selected))"
    }

    private func selectSuggestion(_ suggestion: GameRoomCatalogGame) {
        row.selectedCatalogGameID = suggestion.catalogGameID
        guard let current = row.selectedVariant else { return }
        let variants = importVariantOptions(row, suggestion.catalogGameID)
        if !variants.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
            row.selectedVariant = nil
        }
    }

    private func clearMatch() {
        row.selectedCatalogGameID = nil
    }

    private func confidenceBadge(_ confidence: MachineImportMatchConfidence) -> some View {
        let color: Color
        switch confidence {
        case .high:
            color = .green
        case .medium:
            color = .yellow
        case .low, .manual:
            color = .red
        }

        return AppTintedStatusChip(
            text: confidence.rawValue.capitalized,
            foreground: color,
            compact: true
        )
    }
}
