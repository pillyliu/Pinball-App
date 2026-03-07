import SwiftUI

private func inferPracticeLibrarySourcesForWorkspace(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    var out: [PinballLibrarySource] = []
    for game in games {
        if seen.insert(game.sourceId).inserted {
            out.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
        }
    }
    return out
}

struct PracticeGameToolbarMenu: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String

    private var availableLibrarySources: [PinballLibrarySource] {
        if store.librarySources.isEmpty {
            let sourceGames = store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames
            return inferPracticeLibrarySourcesForWorkspace(from: sourceGames)
        }
        return store.librarySources
    }

    private var orderedGameOptions: [PinballGame] {
        orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true)
    }

    var body: some View {
        Menu {
            if availableLibrarySources.count > 1 {
                Button((store.defaultPracticeSourceID == nil ? "✓ " : "") + "All games") {
                    applyLibrarySelection(nil)
                }
                ForEach(availableLibrarySources) { source in
                    Button((source.id == store.defaultPracticeSourceID ? "✓ " : "") + source.name) {
                        applyLibrarySelection(source.id)
                    }
                }
                Divider()
            }

            Picker("Game", selection: $selectedGameID) {
                if orderedGameOptions.isEmpty {
                    Text("No game data").tag("")
                } else {
                    ForEach(orderedGameOptions) { game in
                        Text(game.name).tag(game.canonicalPracticeKey)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
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
