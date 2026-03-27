import SwiftUI

enum GameRoomRoute: Hashable {
    case settings
    case machineView(UUID, String?, String)
}

enum GameRoomSettingsSection: String, CaseIterable, Identifiable {
    case importFromPinside
    case editMachines
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importFromPinside:
            return "Import"
        case .editMachines:
            return "Edit"
        case .archive:
            return "Archive"
        }
    }
}

struct GameRoomScreen: View {
    @StateObject private var store = GameRoomStore()
    @StateObject private var catalogLoader = GameRoomCatalogLoader()
    @State private var path: [GameRoomRoute] = []
    @Namespace private var machineTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack(path: $path) {
            AppScreen(dismissesKeyboardOnTap: false) {
                GameRoomHomeView(
                    store: store,
                    catalogLoader: catalogLoader,
                    gameTransition: machineTransition,
                    onOpenSettings: { path.append(.settings) },
                    onOpenMachineView: openMachineView
                )
                .navigationDestination(for: GameRoomRoute.self, destination: destination(for:))
            }
        }
        .task {
            await loadDataIfNeeded()
        }
    }

    private func openMachineView(_ machineID: UUID, _ sourceID: String?, _ navigationTitle: String) {
        path.append(.machineView(machineID, sourceID, navigationTitle))
    }

    @ViewBuilder
    private func destination(for route: GameRoomRoute) -> some View {
        switch route {
        case .settings:
            GameRoomSettingsView(
                store: store,
                catalogLoader: catalogLoader,
                gameTransition: machineTransition,
                onOpenMachineView: openMachineView
            )
        case let .machineView(machineID, transitionSourceID, navigationTitle):
            GameRoomMachineView(
                store: store,
                catalogLoader: catalogLoader,
                machineID: machineID,
                navigationTitle: navigationTitle
            )
            .appCardZoomTransition(sourceID: transitionSourceID, in: machineTransition, reduceMotion: reduceMotion)
        }
    }

    private func loadDataIfNeeded() async {
        store.loadIfNeeded()
        await catalogLoader.loadIfNeeded()
        store.migrateOwnedMachineOPDBIDs(using: catalogLoader)
    }
}

#Preview {
    GameRoomScreen()
}

func gameRoomMachineTransitionSourceID(machineID: UUID, surface: String) -> String {
    "gameroom-machine-\(machineID.uuidString)-\(surface)"
}
