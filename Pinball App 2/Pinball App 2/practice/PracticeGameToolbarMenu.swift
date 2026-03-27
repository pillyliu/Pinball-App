import SwiftUI

struct PracticeGameToolbarMenu: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String

    private var availableLibrarySources: [PinballLibrarySource] {
        if store.librarySources.isEmpty {
            let sourceGames = store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames
            return libraryInferSources(from: sourceGames)
        }
        return store.librarySources
    }

    private var orderedGameOptions: [PinballGame] {
        orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true)
    }

    var body: some View {
        Menu {
            if availableLibrarySources.count > 1 {
                Button {
                    applyLibrarySelection(nil)
                } label: {
                    AppSelectableMenuRow(text: "All games", isSelected: store.defaultPracticeSourceID == nil)
                }
                ForEach(availableLibrarySources) { source in
                    Button {
                        applyLibrarySelection(source.id)
                    } label: {
                        AppSelectableMenuRow(text: source.name, isSelected: source.id == store.defaultPracticeSourceID)
                    }
                }
                Divider()
            }

            Picker("Game", selection: $selectedGameID) {
                if orderedGameOptions.isEmpty {
                    Text("No game data").tag("")
                } else {
                    ForEach(orderedGameOptions) { game in
                        Text(practiceDisplayTitle(for: game.canonicalPracticeKey, in: store.games) ?? game.name).tag(game.canonicalPracticeKey)
                    }
                }
            }
        } label: {
            AppToolbarFilterTriggerLabel()
        }
        .buttonStyle(.plain)
    }

    private func applyLibrarySelection(_ sourceID: String?) {
        store.selectPracticeLibrarySource(id: sourceID)
        let canonical = store.canonicalPracticeGameID(selectedGameID)
        if !canonical.isEmpty,
           store.games.contains(where: { $0.canonicalPracticeKey == canonical }) {
            selectedGameID = canonical
        } else {
            selectedGameID = orderedGameOptions.first?.canonicalPracticeKey ?? ""
        }
    }
}
