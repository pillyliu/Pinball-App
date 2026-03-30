import SwiftUI

struct GameRoomImportReviewSection: View {
    @Binding var draftRows: [ImportDraftRow]
    @Binding var reviewFilter: ImportReviewFilter
    let filteredRowIndexes: [Int]
    let duplicateWarningMessage: (ImportDraftRow) -> String?
    let matchLabel: (GameRoomCatalogGame) -> String
    let importVariantOptions: (ImportDraftRow, String) -> [String]
    let normalizePurchaseDate: (String?) -> Date?
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review matches (\(draftRows.count))")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)

            Picker("Review Filter", selection: $reviewFilter) {
                ForEach(ImportReviewFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .appSegmentedControlStyle()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredRowIndexes, id: \.self) { index in
                        GameRoomImportReviewRowCard(
                            row: $draftRows[index],
                            duplicateWarning: duplicateWarningMessage(draftRows[index]),
                            matchLabel: matchLabel,
                            importVariantOptions: importVariantOptions,
                            normalizePurchaseDate: normalizePurchaseDate
                        )
                    }
                }
            }
            .frame(maxHeight: 360)

            Button("Import Selected Matches", action: onImport)
                .buttonStyle(AppPrimaryActionButtonStyle())
        }
    }
}
