//
//  StandingsView.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct StandingsScreen: View {
    let embeddedInNavigation: Bool
    @State private var preferredLeaguePlayerName = PracticeStore.loadPreferredLeaguePlayerNameFromDefaults() ?? ""

    init(embeddedInNavigation: Bool = false) {
        self.embeddedInNavigation = embeddedInNavigation
    }

    @StateObject private var viewModel = StandingsViewModel()
    @State private var tableAvailableWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var widthScale: CGFloat {
        guard tableAvailableWidth > 0 else { return 1 }
        return max(1, min(AppLayout.maxTableWidthScale(isLargeTablet: isLargeTablet), tableAvailableWidth / 646))
    }
    private var scaledRankWidth: CGFloat { 34 * widthScale }
    private var scaledPlayerWidth: CGFloat { 136 * widthScale }
    private var scaledPointsWidth: CGFloat { 68 * widthScale }
    private var scaledEligibleWidth: CGFloat { 38 * widthScale }
    private var scaledNightsWidth: CGFloat { 34 * widthScale }
    private var scaledBankWidth: CGFloat { 42 * widthScale }
    private var scaledFixedTableWidth: CGFloat {
        scaledRankWidth + scaledPlayerWidth + scaledPointsWidth + scaledEligibleWidth + scaledNightsWidth + scaledBankWidth * 8
    }
    private var tableFlexibleExtraWidth: CGFloat { max(0, tableAvailableWidth - scaledFixedTableWidth) }
    private var extraPerColumn: CGFloat { tableFlexibleExtraWidth / 13.0 }
    private var rankWidth: CGFloat { scaledRankWidth + extraPerColumn }
    private var playerWidth: CGFloat { scaledPlayerWidth + extraPerColumn }
    private var pointsWidth: CGFloat { scaledPointsWidth + extraPerColumn }
    private var eligibleWidth: CGFloat { scaledEligibleWidth + extraPerColumn }
    private var nightsWidth: CGFloat { scaledNightsWidth + extraPerColumn }
    private var bankWidth: CGFloat { scaledBankWidth + extraPerColumn }
    private var tableContentWidth: CGFloat { scaledFixedTableWidth + tableFlexibleExtraWidth }
    private var tableMinWidth: CGFloat { tableContentWidth }
    private var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(isLargeTablet: isLargeTablet)
    }

    var body: some View {
        Group {
            if embeddedInNavigation {
                AppScreen {
                    content
                }
            } else {
                NavigationStack {
                    AppScreen {
                        content
                    }
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .toolbar {
            if embeddedInNavigation {
                ToolbarItem(placement: .principal) {
                    navSummaryLabel
                }
                ToolbarItem(placement: .topBarTrailing) {
                    topRightFilterMenu
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            if !embeddedInNavigation {
                seasonSelector
            }

            if let errorMessage = viewModel.errorMessage {
                AppInlineStatusMessage(text: errorMessage, isError: true)
            }
            updatedStatusRow

            standingsTable
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.top, embeddedInNavigation ? 0 : 4)
        .padding(.bottom, 8)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewportWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in
                        viewportWidth = newValue
                    }
            }
        )
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var navSummaryLabel: some View {
        AppToolbarSummaryText(text: "Standings - \(viewModel.selectedSeasonLabel)")
    }

    @ViewBuilder
    private var updatedStatusRow: some View {
        if let updatedAtLabel = viewModel.updatedAtLabel {
            AppRefreshStatusRow(
                updatedAtLabel: updatedAtLabel,
                isRefreshing: viewModel.isRefreshing,
                hasNewerData: viewModel.hasNewerData,
                onRefresh: { Task { await viewModel.refreshNow() } }
            )
        }
    }

    private var topRightFilterMenu: some View {
        Menu {
            ForEach(viewModel.seasons, id: \.self) { season in
                Button("Season \(season)") {
                    viewModel.selectedSeason = season
                }
            }
        } label: {
            AppToolbarFilterTriggerLabel()
        }
        .buttonStyle(.plain)
    }

    private var seasonSelector: some View {
        Menu {
            ForEach(viewModel.seasons, id: \.self) { season in
                Button("Season \(season)") {
                    viewModel.selectedSeason = season
                }
            }
        } label: {
            AppDropdownMenuLabel(
                text: viewModel.selectedSeasonLabel,
                isLargeTablet: isLargeTablet,
                fillsWidth: true,
                embeddedInNavigation: false
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.seasons.isEmpty)
    }

    private var standingsTable: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    tableHeader
                    AppTableHeaderDivider()

                    if viewModel.isRefreshing && viewModel.rows.isEmpty {
                        AppTablePlaceholder(text: "Loading data…", minHeight: 68)
                    } else if viewModel.standings.isEmpty {
                        AppTablePlaceholder(text: "No rows. Check data source or season selection.", minHeight: 68)
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.standings.enumerated()), id: \.element.id) { index, standing in
                                    StandingsRowView(
                                        standing: standing,
                                        rank: index + 1,
                                        rankWidth: rankWidth,
                                        playerWidth: playerWidth,
                                        pointsWidth: pointsWidth,
                                        eligibleWidth: eligibleWidth,
                                        nightsWidth: nightsWidth,
                                        bankWidth: bankWidth,
                                        largeText: isLargeTablet,
                                        isHighlighted: isPreferredLeaguePlayer(standing.rawPlayer)
                                    )
                                    .background(index.isMultiple(of: 2) ? AppTheme.rowEven : AppTheme.rowOdd)
                                    AppTableRowDivider()
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(minWidth: tableMinWidth, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { tableAvailableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in
                        tableAvailableWidth = newValue
                    }
            }
        )
        .appPanelStyle()
        .onReceive(NotificationCenter.default.publisher(for: .pinballLeaguePreviewNeedsRefresh)) { _ in
            preferredLeaguePlayerName = PracticeStore.loadPreferredLeaguePlayerNameFromDefaults() ?? ""
            Task { await viewModel.reloadFromCache() }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            AppHeaderCell(title: "#", width: rankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "Player", width: playerWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "Pts", width: pointsWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "Elg", width: eligibleWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "N", width: nightsWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B1", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B2", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B3", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B4", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B5", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B6", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B7", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
            AppHeaderCell(title: "B8", width: bankWidth, horizontalPadding: 3, largeText: isLargeTablet)
        }
        .frame(height: isLargeTablet ? 46 : 42)
        .background(.thinMaterial)
    }

    private func isPreferredLeaguePlayer(_ rawPlayer: String) -> Bool {
        leaguePlayerNamesMatch(rawPlayer, preferredLeaguePlayerName)
    }
}

#Preview {
    StandingsScreen()
}
