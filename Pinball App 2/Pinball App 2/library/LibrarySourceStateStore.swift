import Foundation

struct PinballLibrarySourceState: Codable, Equatable {
    var enabledSourceIDs: [String]
    var pinnedSourceIDs: [String]
    var selectedSourceID: String?
    var selectedSortBySource: [String: String]
    var selectedBankBySource: [String: Int]

    static let empty = PinballLibrarySourceState(
        enabledSourceIDs: [],
        pinnedSourceIDs: [],
        selectedSourceID: nil,
        selectedSortBySource: [:],
        selectedBankBySource: [:]
    )
}

enum PinballLibrarySourceStateStore {
    static let defaultsKey = "pinball-library-source-state-v1"
    static let maxPinnedSources = 10

    static func filteredKnownIDs(_ ids: [String], validIDs: Set<String>) -> [String] {
        var seen = Set<String>()
        return ids.compactMap(canonicalLibrarySourceID).filter { id in
            validIDs.contains(id) && seen.insert(id).inserted
        }
    }

    static func normalized(_ state: PinballLibrarySourceState) -> PinballLibrarySourceState {
        PinballLibrarySourceState(
            enabledSourceIDs: Array(NSOrderedSet(array: state.enabledSourceIDs.compactMap(canonicalLibrarySourceID))) as? [String] ?? [],
            pinnedSourceIDs: Array(NSOrderedSet(array: state.pinnedSourceIDs.compactMap(canonicalLibrarySourceID))) as? [String] ?? [],
            selectedSourceID: canonicalLibrarySourceID(state.selectedSourceID),
            selectedSortBySource: dictionaryPreservingLastValue(
                state.selectedSortBySource.compactMap { key, value in
                    canonicalLibrarySourceID(key).map { ($0, value) }
                }
            ),
            selectedBankBySource: dictionaryPreservingLastValue(
                state.selectedBankBySource.compactMap { key, value in
                    canonicalLibrarySourceID(key).map { ($0, value) }
                }
            )
        )
    }
}

extension Notification.Name {
    static let pinballLibrarySourcesDidChange = Notification.Name("pinballLibrarySourcesDidChange")
}
