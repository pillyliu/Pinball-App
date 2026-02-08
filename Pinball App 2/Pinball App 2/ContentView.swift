//
//  ContentView.swift
//  Pinball App 2
//
//  Created by Peter Liu on 2/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            StandingsView()
                .tabItem {
                    Label("Standings", systemImage: "list.number")
                }

            LPLTargetsView()
                .tabItem {
                    Label("Targets", systemImage: "scope")
                }

            PinballLibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
        }
    }
}

#Preview {
    ContentView()
}
