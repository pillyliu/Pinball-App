import SwiftUI
import UniformTypeIdentifiers

struct GroupGameSelectionScreen: View {
    private static let preferredGroupPickerLibrarySourceDefaultsKey = "practice-group-picker-library-source-id"

    @ObservedObject var store: PracticeStore
    @Binding var selectedGameIDs: [String]

    @State private var searchText: String = ""
    @State private var selectedLibraryFilterID: String = ""

    private var allLibraryGamesForPicker: [PinballGame] {
        store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames
    }

    private var availableLibrarySources: [PinballLibrarySource] {
        store.librarySources.isEmpty ? libraryInferSources(from: allLibraryGamesForPicker) : store.librarySources
    }

    private var baseGamesForSelection: [PinballGame] {
        let selected = selectedLibraryFilterID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = allLibraryGamesForPicker
        if selected.isEmpty || selected == quickEntryAllGamesLibraryID {
            return pool
        }
        return pool.filter { $0.sourceId == selected }
    }

    private var filteredGames: [PinballGame] {
        orderedGamesForDropdown(baseGamesForSelection, collapseByPracticeIdentity: true)
            .filter { game in
                matchesSearchQuery(
                    searchText,
                    fields: [
                        game.name,
                        game.normalizedVariant,
                        game.manufacturer,
                        game.year.map(String.init)
                    ]
                )
            }
    }

    private var grouped: [(letter: String, games: [PinballGame])] {
        let buckets = Dictionary(grouping: filteredGames) { game in
            String(game.name.prefix(1)).uppercased()
        }
        return buckets.keys.sorted().map { letter in
            (letter, buckets[letter] ?? [])
        }
    }

    var body: some View {
        List {
            if availableLibrarySources.count > 1 {
                Section {
                    Picker("Library", selection: $selectedLibraryFilterID) {
                        Text("All games").tag(quickEntryAllGamesLibraryID)
                        ForEach(availableLibrarySources) { source in
                            Text(source.name).tag(source.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            ForEach(grouped, id: \.letter) { section in
                Section(section.letter) {
                    ForEach(section.games) { game in
                        Button {
                            toggle(selectionID(for: game))
                        } label: {
                            HStack {
                                Text(game.name)
                                Spacer()
                                Image(systemName: isSelected(selectionID(for: game)) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isSelected(selectionID(for: game)) ? .orange : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search titles")
        .navigationTitle("Select Titles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedLibraryFilterID.isEmpty {
                let savedPreferredLibraryID = UserDefaults.standard.string(forKey: Self.preferredGroupPickerLibrarySourceDefaultsKey)
                selectedLibraryFilterID =
                    (savedPreferredLibraryID.flatMap { id in availableLibrarySources.contains(where: { $0.id == id }) ? id : nil })
                    ?? store.defaultPracticeSourceID
                    ?? availableLibrarySources.first?.id
                    ?? quickEntryAllGamesLibraryID
            }
        }
        .onChange(of: selectedLibraryFilterID) { _, newValue in
            guard !newValue.isEmpty else { return }
            UserDefaults.standard.set(newValue, forKey: Self.preferredGroupPickerLibrarySourceDefaultsKey)
        }
    }

    private func toggle(_ gameID: String) {
        if isSelected(gameID) {
            selectedGameIDs.removeAll { $0 == gameID }
        } else {
            selectedGameIDs.append(gameID)
        }
    }

    private func isSelected(_ gameID: String) -> Bool {
        selectedGameIDs.contains(gameID)
    }

    private func selectionID(for game: PinballGame) -> String {
        let selectedSourceID = canonicalLibrarySourceID(selectedLibraryFilterID)
        if let selectedSourceID,
           selectedSourceID != quickEntryAllGamesLibraryID,
           game.sourceType == .venue,
           canonicalLibrarySourceID(game.sourceId) == selectedSourceID {
            return sourceScopedPracticeGameID(sourceID: selectedSourceID, gameID: game.canonicalPracticeKey)
        }
        return game.canonicalPracticeKey
    }
}

struct SelectedGameReorderDropDelegate: DropDelegate {
    let targetGameID: String
    @Binding var selectedGameIDs: [String]
    @Binding var draggingGameID: String?

    func dropEntered(info: DropInfo) {
        guard let draggingGameID else { return }
        guard draggingGameID != targetGameID else { return }
        guard let fromIndex = selectedGameIDs.firstIndex(of: draggingGameID),
              let toIndex = selectedGameIDs.firstIndex(of: targetGameID) else {
            return
        }
        if fromIndex == toIndex { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedGameIDs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingGameID = nil
        return true
    }
}

struct SelectedGameReorderContainerDropDelegate: DropDelegate {
    @Binding var draggingGameID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingGameID = nil
        return true
    }
}
