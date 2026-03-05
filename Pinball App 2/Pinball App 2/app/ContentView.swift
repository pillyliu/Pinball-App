//
//  ContentView.swift
//  Pinball App 2
//
//  Created by Peter Liu on 2/5/26.
//

import SwiftUI
import Combine

enum RootTab: Hashable {
    case league
    case library
    case gameroom
    case practice
    case settings
}

final class AppNavigationModel: ObservableObject {
    @Published var selectedTab: RootTab = .league
    @Published var libraryGameIDToOpen: String?
    @Published var lastViewedLibraryGameID: String?

    func openLibraryGame(gameID: String) {
        guard !gameID.isEmpty else { return }
        libraryGameIDToOpen = gameID
        selectedTab = .library
    }
}

struct ContentView: View {
    @StateObject private var appNavigation = AppNavigationModel()

    var body: some View {
        TabView(selection: $appNavigation.selectedTab) {
            LeagueScreen()
                .tag(RootTab.league)
                .tabItem {
                    Label("League", systemImage: "chart.bar.xaxis")
                }

            LibraryScreen()
                .tag(RootTab.library)
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            PracticeScreen()
                .tag(RootTab.practice)
                .tabItem {
                    Label("Practice", systemImage: "figure.play")
                }

            GameRoomScreen()
                .tag(RootTab.gameroom)
                .tabItem {
                    Label("GameRoom", systemImage: "arcade.stick.console")
                }

            SettingsScreen()
                .tag(RootTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .environmentObject(appNavigation)
    }
}

#Preview {
    ContentView()
}
