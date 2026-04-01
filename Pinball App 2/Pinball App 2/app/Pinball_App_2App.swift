//
//  Pinball_App_2App.swift
//  Pinball App 2
//
//  Created by Peter Liu on 2/5/26.
//

import SwiftUI

@main
struct Pinball_App_2App: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppDisplayMode.defaultsKey) private var displayModeRawValue = AppDisplayMode.system.rawValue

    private var displayMode: AppDisplayMode {
        AppDisplayMode(rawValue: displayModeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(displayMode.preferredColorScheme)
                .task {
                    await migrateLegacyPinnedVenueImportsIfNeeded()
                    await refreshRedactedPlayersFromCSV()
                    await warmHostedCAFData()
                    await refreshHostedPinballDataIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await migrateLegacyPinnedVenueImportsIfNeeded()
                await refreshHostedPinballDataIfNeeded()
            }
        }
    }
}
