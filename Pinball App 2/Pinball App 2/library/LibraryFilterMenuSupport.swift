import SwiftUI

struct LibraryFilterMenuSections: View {
    let sources: [PinballLibrarySource]
    let visibleSources: [PinballLibrarySource]
    let selectedSourceID: String?
    let sortOptions: [PinballLibrarySortOption]
    let selectedSortOption: PinballLibrarySortOption
    let menuLabel: (PinballLibrarySortOption) -> String
    let supportsBankFilter: Bool
    let bankOptions: [Int]
    let selectedBank: Int?
    let onSelectSource: (String) -> Void
    let onSelectSort: (PinballLibrarySortOption) -> Void
    let onSelectBank: (Int?) -> Void

    var body: some View {
        Group {
            LibrarySourceMenuSection(
                sources: sources,
                visibleSources: visibleSources,
                selectedSourceID: selectedSourceID,
                onSelectSource: onSelectSource
            )
            LibrarySortMenuSection(
                sortOptions: sortOptions,
                selectedSortOption: selectedSortOption,
                menuLabel: menuLabel,
                onSelectSort: onSelectSort
            )
            LibraryBankMenuSection(
                supportsBankFilter: supportsBankFilter,
                bankOptions: bankOptions,
                selectedBank: selectedBank,
                onSelectBank: onSelectBank
            )
        }
    }
}

struct LibrarySourceMenuSection: View {
    let sources: [PinballLibrarySource]
    let visibleSources: [PinballLibrarySource]
    let selectedSourceID: String?
    let onSelectSource: (String) -> Void

    var body: some View {
        Group {
            if !sources.isEmpty {
                Section("Library") {
                    ForEach(visibleSources) { source in
                        Button {
                            onSelectSource(source.id)
                        } label: {
                            AppSelectableMenuRow(text: source.name, isSelected: selectedSourceID == source.id)
                        }
                    }
                }
            }
        }
    }
}

struct LibrarySortMenuSection: View {
    let sortOptions: [PinballLibrarySortOption]
    let selectedSortOption: PinballLibrarySortOption
    let menuLabel: (PinballLibrarySortOption) -> String
    let onSelectSort: (PinballLibrarySortOption) -> Void

    var body: some View {
        Section("Sort") {
            ForEach(sortOptions) { option in
                Button {
                    onSelectSort(option)
                } label: {
                    AppSelectableMenuRow(text: menuLabel(option), isSelected: selectedSortOption == option)
                }
            }
        }
    }
}

struct LibraryBankMenuSection: View {
    let supportsBankFilter: Bool
    let bankOptions: [Int]
    let selectedBank: Int?
    let onSelectBank: (Int?) -> Void

    var body: some View {
        Group {
            if supportsBankFilter {
                Section("Bank") {
                    Button {
                        onSelectBank(nil)
                    } label: {
                        AppSelectableMenuRow(text: "All banks", isSelected: selectedBank == nil)
                    }

                    ForEach(bankOptions, id: \.self) { bank in
                        Button {
                            onSelectBank(bank)
                        } label: {
                            AppSelectableMenuRow(text: "Bank \(bank)", isSelected: selectedBank == bank)
                        }
                    }
                }
            }
        }
    }
}
