import SwiftUI

struct GameRoomAddMachineAdvancedFilters: View {
    @Binding var manufacturerQuery: String
    @Binding var yearQuery: String
    @Binding var selectedType: GameRoomAddMachineTypeFilter?
    @Binding var isExpanded: Bool
    let filteredManufacturerSuggestions: [String]
    let showManufacturerSuggestions: Bool
    let hasSearchFilters: Bool
    let onSelectManufacturer: (String) -> Void
    let onSelectType: (GameRoomAddMachineTypeFilter?) -> Void
    let onClearFilters: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                AppNativeClearTextField(
                    placeholder: "Manufacturer",
                    text: $manufacturerQuery,
                    style: .roundedBorder
                )

                if showManufacturerSuggestions {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredManufacturerSuggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    onSelectManufacturer(suggestion)
                                }
                                .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                AppNativeClearTextField(
                    placeholder: "Year",
                    text: $yearQuery,
                    style: .roundedBorder,
                    keyboardType: .numberPad
                )

                Menu {
                    Button("Any type") {
                        onSelectType(nil)
                    }

                    ForEach(GameRoomAddMachineTypeFilter.allCases) { option in
                        Button(option.label) {
                            onSelectType(option)
                        }
                    }
                } label: {
                    AppCompactFilterLabel(text: selectedType?.label ?? "Any type")
                }
                .buttonStyle(.plain)

                if hasSearchFilters {
                    Button("Clear filters", action: onClearFilters)
                        .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Advanced Filters")
                .font(.subheadline.weight(.semibold))
        }
    }
}
