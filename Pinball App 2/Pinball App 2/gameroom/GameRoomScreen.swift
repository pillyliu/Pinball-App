import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import UIKit

enum GameRoomRoute: Hashable {
    case settings
    case machineView(UUID)
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

    var body: some View {
        NavigationStack(path: $path) {
            GameRoomHomeView(
                store: store,
                catalogLoader: catalogLoader,
                onOpenSettings: { path.append(.settings) },
                onOpenMachineView: { machineID in path.append(.machineView(machineID)) }
            )
            .navigationDestination(for: GameRoomRoute.self) { route in
                switch route {
                case .settings:
                    GameRoomSettingsView(
                        store: store,
                        catalogLoader: catalogLoader,
                        onOpenMachineView: { machineID in
                            path.append(.machineView(machineID))
                        }
                    )
                case let .machineView(machineID):
                    GameRoomMachineView(store: store, catalogLoader: catalogLoader, machineID: machineID)
                }
            }
        }
        .task {
            store.loadIfNeeded()
            await catalogLoader.loadIfNeeded()
        }
    }
}

#Preview {
    GameRoomScreen()
}
