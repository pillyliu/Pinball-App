import SwiftUI

struct GameRoomAddMachinePanel: View {
    @Binding var searchText: String
    @Binding var manufacturerQuery: String
    @Binding var yearQuery: String
    @Binding var selectedType: GameRoomAddMachineTypeFilter?
    @Binding var isAdvancedExpanded: Bool
    let catalogErrorMessage: String?
    let isCatalogLoading: Bool
    let hasSearchFilters: Bool
    let filteredGameCount: Int
    let filteredCatalogGames: [GameRoomCatalogGame]
    let filteredManufacturerSuggestions: [String]
    let showManufacturerSuggestions: Bool
    let pendingVariantPickerGameID: String?
    let pendingVariantPickerTitle: String
    let pendingVariantPickerOptions: [String]
    let onSelectManufacturer: (String) -> Void
    let onSelectType: (GameRoomAddMachineTypeFilter?) -> Void
    let onClearFilters: () -> Void
    let onBeginAddMachineSelection: (GameRoomCatalogGame) -> Void
    let onDismissVariantPicker: () -> Void
    let onSelectPendingVariant: (String) -> Void
    let resultMetaLine: (GameRoomCatalogGame) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let catalogErrorMessage {
                AppInlineTaskStatus(text: catalogErrorMessage, isError: true)
            }

            AppNativeClearTextField(
                placeholder: "Game name",
                text: $searchText,
                style: .roundedBorder
            )

            GameRoomAddMachineAdvancedFilters(
                manufacturerQuery: $manufacturerQuery,
                yearQuery: $yearQuery,
                selectedType: $selectedType,
                isExpanded: $isAdvancedExpanded,
                filteredManufacturerSuggestions: filteredManufacturerSuggestions,
                showManufacturerSuggestions: showManufacturerSuggestions,
                hasSearchFilters: hasSearchFilters,
                onSelectManufacturer: onSelectManufacturer,
                onSelectType: onSelectType,
                onClearFilters: onClearFilters
            )

            statusContent

            if hasSearchFilters {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredCatalogGames, id: \.id) { game in
                            GameRoomAddMachineResultRow(
                                game: game,
                                metaLine: resultMetaLine(game),
                                isVariantPickerPresented: pendingVariantPickerGameID == game.catalogGameID && !pendingVariantPickerOptions.isEmpty,
                                pendingVariantPickerTitle: pendingVariantPickerTitle,
                                pendingVariantPickerOptions: pendingVariantPickerOptions,
                                onBeginAddMachineSelection: { onBeginAddMachineSelection(game) },
                                onDismissVariantPicker: onDismissVariantPicker,
                                onSelectPendingVariant: onSelectPendingVariant
                            )
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        if isCatalogLoading {
            AppInlineTaskStatus(text: "Loading catalog data…", showsProgress: true)
        } else if hasSearchFilters {
            AppInlineTaskStatus(text: "\(filteredGameCount) matches")
        } else {
            AppPanelEmptyCard(text: "Search by name or abbreviation. Open Advanced Filters for manufacturer, year, and game type.")
        }
    }
}
