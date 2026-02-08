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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await PinballDataCache.shared.refreshMetadataFromForeground()
            }
        }
    }
}
