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
    @StateObject private var shakeCoordinator = AppShakeCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("app-intro-seen-version") private var appIntroSeenVersion = 0
    @AppStorage("app-intro-show-on-next-launch") private var appIntroShowOnNextLaunch = false
    @State private var shouldShowIntroOverlayThisLaunch: Bool
    @State private var isIntroVisible: Bool

    init() {
        let appIntroSeenVersion = UserDefaults.standard.integer(forKey: "app-intro-seen-version")
        let appIntroShowOnNextLaunch = UserDefaults.standard.bool(forKey: "app-intro-show-on-next-launch")
        let shouldShowIntro = appIntroShowOnNextLaunch || appIntroSeenVersion == 0
        _shouldShowIntroOverlayThisLaunch = State(initialValue: shouldShowIntro)
        _isIntroVisible = State(initialValue: shouldShowIntro)
    }

    private var shouldShowIntroOverlay: Bool {
        shouldShowIntroOverlayThisLaunch && isIntroVisible
    }

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
        .dismissKeyboardOnTap()
        .appShakeMotionHandler(isEnabled: scenePhase == .active) {
            shakeCoordinator.handleDetectedShake()
        }
        .overlay {
            ZStack {
                if let overlayLevel = shakeCoordinator.overlayLevel {
                    AppShakeWarningOverlay(level: overlayLevel)
                }

                if shouldShowIntroOverlay {
                    AppIntroOverlay {
                        isIntroVisible = false
                        appIntroSeenVersion = AppIntroOverlay.currentVersion
                        appIntroShowOnNextLaunch = false
                    }
                }
            }
        }
        .environmentObject(appNavigation)
    }
}

#Preview {
    ContentView()
}
