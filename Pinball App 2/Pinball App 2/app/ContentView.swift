//
//  ContentView.swift
//  Pinball App 2
//
//  Created by Peter Liu on 2/5/26.
//

import SwiftUI
import Combine

enum RootTab: Hashable, CaseIterable {
    case league
    case library
    case practice
    case gameroom
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

    @ViewBuilder
    func rootView() -> some View {
        switch self {
        case .league:
            LeagueScreen()
        case .library:
            LibraryScreen()
        case .gameroom:
            GameRoomScreen()
        case .practice:
            PracticeScreen()
        case .settings:
            SettingsScreen()
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
            ForEach(RootTab.allCases, id: \.self) { tab in
                tab.rootView()
                    .tag(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
            }
        }
        .tint(AppTheme.brandGold)
        .environmentObject(appNavigation)
    }
}

#Preview {
    ContentView()
}
