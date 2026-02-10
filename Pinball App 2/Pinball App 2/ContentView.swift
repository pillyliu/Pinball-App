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

            LibraryListScreen()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
        }
    }
}

private struct LPLInfoView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var viewportWidth: CGFloat = 0
    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(verticalSizeClass: verticalSizeClass, isLargeTablet: isLargeTablet)
    }
    private var readableContentWidth: CGFloat? {
        AppLayout.maxReadableContentWidth(isLargeTablet: isLargeTablet)
    }
    private var aboutTitleFont: Font {
        isLargeTablet ? .title2 : .headline
    }
    private var aboutBodyFont: Font {
        isLargeTablet ? .title3 : .callout
    }
    private var aboutLinkFont: Font {
        isLargeTablet ? .title3.weight(.semibold) : .subheadline.weight(.semibold)
    }

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
                                .font(aboutTitleFont)
                                .foregroundStyle(Color.white.opacity(0.92))

                            Text("The Lansing Pinball League is the Capital City's IFPA-endorsed pinball league, open to players of all skill levels. New players are always welcome. We're a friendly, casual group with everyone from first-timers to seasoned competitors.")
                                .font(aboutBodyFont)
                                .foregroundStyle(Color.white.opacity(0.92))

                            Text(
                                "We meet the 2nd and 4th Tuesdays at \(Text("The Avenue Cafe").bold()) (2021 E. Michigan Ave, Lansing), about halfway between MSU and the Capitol. We're currently in \(Text("Season 24").bold()), which started in January. New members can join during the first 5 meetings, and players must attend at least 4 of the 8 meetings to qualify for finals. Guests are welcome at any session. \(Text("Season dues are $10").bold()), paid in cash."
                            )
                            .font(aboutBodyFont)
                            .foregroundStyle(Color.white.opacity(0.92))

                            Text(
                                "We also run a side tournament, \(Text("Tuesday Night Smackdown").bold()), played on a single game. Qualifying starts around \(Text("6 pm").bold()), with finals (top 8 players) after league play finishes, usually around \(Text("9:30 pm").bold())."
                            )
                            .font(aboutBodyFont)
                            .foregroundStyle(Color.white.opacity(0.92))

                            HStack(spacing: 10) {
                                Link(destination: LPLLinks.website) {
                                    Text("lansingpinleague.com")
                                        .font(aboutLinkFont)
                                        .foregroundStyle(Color.white.opacity(0.9))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.controlBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(AppTheme.controlBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                Link(destination: LPLLinks.facebook) {
                                    Text("Facebook Group")
                                        .font(aboutLinkFont)
                                        .foregroundStyle(Color.white.opacity(0.9))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.controlBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(AppTheme.controlBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                        .appReadableWidth(maxWidth: readableContentWidth)
                        .padding(.horizontal, contentHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    }

                    Text("Source: lansingpinleague.com")
                        .font(isLargeTablet ? .footnote : .caption2)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newValue in
                            viewportWidth = newValue
                        }
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
}
