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

    var title: String {
        switch self {
        case .league: return "League"
        case .library: return "Library"
        case .gameroom: return "GameRoom"
        case .practice: return "Practice"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .league: return "chart.bar.xaxis"
        case .library: return "books.vertical"
        case .gameroom: return "arcade.stick.console"
        case .practice: return "figure.play"
        case .settings: return "slider.horizontal.3"
        }
    }
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
                    Label(RootTab.league.title, systemImage: RootTab.league.systemImage)
                }

            LibraryScreen()
                .tag(RootTab.library)
                .tabItem {
                    Label(RootTab.library.title, systemImage: RootTab.library.systemImage)
                }

            PracticeScreen()
                .tag(RootTab.practice)
                .tabItem {
                    Label(RootTab.practice.title, systemImage: RootTab.practice.systemImage)
                }

            GameRoomScreen()
                .tag(RootTab.gameroom)
                .tabItem {
                    Label(RootTab.gameroom.title, systemImage: RootTab.gameroom.systemImage)
                }

            SettingsScreen()
                .tag(RootTab.settings)
                .tabItem {
                    Label(RootTab.settings.title, systemImage: RootTab.settings.systemImage)
                }
        }
        .environmentObject(appNavigation)
    }
}

#Preview {
    ContentView()
}
