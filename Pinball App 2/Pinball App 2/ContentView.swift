//
//  ContentView.swift
//  Pinball App 2
//
//  Created by Peter Liu on 2/5/26.
//

import SwiftUI

private enum LPLLinks {
    static let website = URL(string: "https://www.lansingpinleague.com/")!
    static let facebook = URL(string: "https://www.facebook.com/groups/LansingPinLeague/")!
}

struct ContentView: View {
    var body: some View {
        TabView {
            LPLInfoView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }

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

private struct LPLInfoView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Image("LaunchLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 120, maxHeight: 220)

                                                        Text("Pinball in the Capital City")
                                .font(.headline)
                                .foregroundStyle(Color.white.opacity(0.92))

                            Text("The Lansing Pinball League is the Capital City's IFPA-endorsed pinball league, open to players of all skill levels. New players are always welcome. We're a friendly, casual group with everyone from first-timers to seasoned competitors.")
                                .font(.callout)
                                .foregroundStyle(Color.white.opacity(0.92))

                            (
                                Text("We meet the 2nd and 4th Tuesdays at ") +
                                Text("The Avenue Cafe").bold() +
                                Text(" (2021 E. Michigan Ave, Lansing), about halfway between MSU and the Capitol. We're currently in ") +
                                Text("Season 24").bold() +
                                Text(", which started in January. New members can join during the first 5 meetings, and players must attend at least 4 of the 8 meetings to qualify for finals. Guests are welcome at any session. ") +
                                Text("Season dues are $10").bold() +
                                Text(", paid in cash.")
                            )
                            .font(.callout)
                            .foregroundStyle(Color.white.opacity(0.92))

                            (
                                Text("We also run a side tournament, ") +
                                Text("Tuesday Night Smackdown").bold() +
                                Text(", played on a single game. Qualifying starts around ") +
                                Text("6 pm").bold() +
                                Text(", with finals (top 8 players) after league play finishes, usually around ") +
                                Text("9:30 pm").bold() +
                                Text(".")
                            )
                            .font(.callout)
                            .foregroundStyle(Color.white.opacity(0.92))

                            HStack(spacing: 10) {
                                Link(destination: LPLLinks.website) {
                                    Text("lansingpinleague.com")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(AppTheme.controlBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(AppTheme.controlBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                Link(destination: LPLLinks.facebook) {
                                    Text("Facebook Group")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(AppTheme.controlBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(AppTheme.controlBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    }

                    Text("Source: lansingpinleague.com")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
}
