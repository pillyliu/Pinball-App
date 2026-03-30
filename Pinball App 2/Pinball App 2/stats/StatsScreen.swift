//
//  StatsView.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct StatsScreen: View {
    let embeddedInNavigation: Bool
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false
    @State private var preferredLeaguePlayerName = PracticeStore.loadPreferredLeaguePlayerNameFromDefaults() ?? ""

    init(embeddedInNavigation: Bool = false) {
        self.embeddedInNavigation = embeddedInNavigation
    }

    private struct FilterOption: Hashable {
        let value: String
        let label: String
    }

    @StateObject private var viewModel = StatsViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var viewportSize: CGSize = .zero
    @State private var tableAvailableWidth: CGFloat = 0
    @State private var statsCardHeight: CGFloat = 0
    private let tableDividerHeight: CGFloat = 1
    private var headerHeight: CGFloat { isLargeTablet ? 40 : 34 }
    private var tableRowHeight: CGFloat { isLargeTablet ? 38 : 32 }
    
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportSize.width)
    }
    private var useLandscapeSplitLayout: Bool { viewportSize.width > viewportSize.height }
    private var useWideFilterLayout: Bool { isRegularWidth || verticalSizeClass == .compact }
    private var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(isLargeTablet: isLargeTablet)
    }
    private var baseSeasonColWidth: CGFloat { isRegularWidth ? 74 : 56 }
    private var basePlayerColWidth: CGFloat { isRegularWidth ? 170 : 118 }
    private var baseBankNumColWidth: CGFloat { isRegularWidth ? 56 : 44 }
    private var baseMachineColWidth: CGFloat { isRegularWidth ? 230 : 145 }
    private var baseScoreColWidth: CGFloat { isRegularWidth ? 150 : 102 }
    private var basePointsColWidth: CGFloat { isRegularWidth ? 72 : 54 }
    private var baseTableContentWidth: CGFloat {
        baseSeasonColWidth + basePlayerColWidth + baseBankNumColWidth + baseMachineColWidth + baseScoreColWidth + basePointsColWidth
    }
    private var widthScale: CGFloat {
        guard tableAvailableWidth > 0 else { return 1 }
        return max(1, min(AppLayout.maxTableWidthScale(isLargeTablet: isLargeTablet), tableAvailableWidth / baseTableContentWidth))
    }
    private var seasonColWidth: CGFloat { baseSeasonColWidth * widthScale }
    private var scaledPlayerColWidth: CGFloat { basePlayerColWidth * widthScale }
    private var bankNumColWidth: CGFloat { baseBankNumColWidth * widthScale }
    private var scaledMachineColWidth: CGFloat { baseMachineColWidth * widthScale }
    private var scoreColWidth: CGFloat { baseScoreColWidth * widthScale }
    private var pointsColWidth: CGFloat { basePointsColWidth * widthScale }
    private var scaledFixedTableWidth: CGFloat {
        seasonColWidth + scaledPlayerColWidth + bankNumColWidth + scaledMachineColWidth + scoreColWidth + pointsColWidth
    }
    private var tableFlexibleExtraWidth: CGFloat { max(0, tableAvailableWidth - scaledFixedTableWidth) }
    private var playerColWidth: CGFloat { scaledPlayerColWidth + (tableFlexibleExtraWidth * 0.4) }
    private var machineColWidth: CGFloat { scaledMachineColWidth + (tableFlexibleExtraWidth * 0.6) }
    private var tableContentWidth: CGFloat { scaledFixedTableWidth + tableFlexibleExtraWidth }
    private var tableMinWidth: CGFloat { tableContentWidth }
    private var compactTableContentHeight: CGFloat {
        let bodyHeight: CGFloat
        if viewModel.filteredRows.isEmpty {
            bodyHeight = 64
        } else {
            bodyHeight = CGFloat(viewModel.filteredRows.count) * (tableRowHeight + tableDividerHeight)
        }
        return headerHeight + tableDividerHeight + bodyHeight
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
                    navSummaryLabels
                }
                ToolbarItem(placement: .topBarTrailing) {
                    topRightFilterMenu
                }
            }
        }
    }

    private var content: some View {
        Group {
            if useLandscapeSplitLayout {
                VStack(spacing: 14) {
                    if !embeddedInNavigation {
                        filterBar
                    }

                    if let errorMessage = viewModel.errorMessage {
                        AppInlineStatusMessage(text: errorMessage, isError: true)
                    }
                    updatedStatusRow

                    GeometryReader { geo in
                        let spacing: CGFloat = 14
                        let available = max(0, geo.size.width - spacing)
                        let mainWidth = available * 0.6
                        let machineWidth = available - mainWidth
                        let effectiveTableHeight = resolvedTableHeight(maxHeight: geo.size.height)

                        HStack(alignment: .top, spacing: spacing) {
                            tableCard
                                .frame(width: mainWidth)
                                .frame(height: effectiveTableHeight, alignment: .top)
                                .frame(maxHeight: .infinity, alignment: .top)
                            statsCard
                                .frame(width: machineWidth)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, embeddedInNavigation ? 0 : 4)
                .padding(.bottom, 14)
            } else {
                VStack(spacing: 14) {
                    if !embeddedInNavigation {
                        filterBar
                    }

                    if let errorMessage = viewModel.errorMessage {
                        AppInlineStatusMessage(text: errorMessage, isError: true)
                    }
                    updatedStatusRow

                    GeometryReader { geo in
                        let spacing: CGFloat = 14
                        let defaultStatsHeight: CGFloat = 214
                        let measuredStatsHeight = statsCardHeight > 0 ? statsCardHeight : defaultStatsHeight
                        let bottomBuffer: CGFloat = 14
                        let defaultTableHeight = max(120, geo.size.height - measuredStatsHeight - spacing - bottomBuffer)
                        let effectiveTableHeight = resolvedTableHeight(maxHeight: defaultTableHeight)

                        VStack(alignment: .leading, spacing: spacing) {
                            tableCard
                                .frame(height: effectiveTableHeight)

                            statsCard
                                .readHeight { height in
                                    if abs(height - statsCardHeight) > 0.5 {
                                        statsCardHeight = height
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, embeddedInNavigation ? 0 : 4)
                .padding(.bottom, 14)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewportSize = geo.size }
                    .onChange(of: geo.size) { _, newValue in
                        viewportSize = newValue
                    }
            }
        )
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        filterSection
    }

    private var navSummaryLabels: some View {
        AppToolbarSummaryText(text: navSummaryText)
    }
    private var navSummaryText: String {
        let seasonDigits = viewModel.season.filter(\.isNumber)
        let seasonToken = viewModel.season.isEmpty ? "S*" : (seasonDigits.isEmpty ? viewModel.season : "S\(seasonDigits)")
        let bankToken = viewModel.bankNumber.map { "B\($0)" } ?? "B*"
        let playerToken = viewModel.player.isEmpty ? "Player: All" : displayLPLPlayerName(viewModel.player)
        let machineToken = viewModel.machine.isEmpty ? "Machine: All" : viewModel.machine
        return "\(seasonToken)\(bankToken)  \(playerToken)  \(machineToken)"
    }

    private var filterSection: some View {
        let seasonOptions = [FilterOption(value: "", label: "S: All")] + viewModel.seasons.map {
            FilterOption(value: $0, label: seasonToken($0))
        }
        let playerOptions = [FilterOption(value: "", label: "Player: All")] + viewModel.players.map {
            FilterOption(value: $0, label: displayLPLPlayerName($0))
        }
        let bankOptions = [FilterOption(value: "", label: "B: All")] + viewModel.bankNumbers.map {
            FilterOption(value: String($0), label: "B\($0)")
        }
        let machineOptions = [FilterOption(value: "", label: "Machine: All")] + viewModel.machines.map {
            FilterOption(value: $0, label: $0)
        }

        return VStack(spacing: 8) {
            if useWideFilterLayout {
                GeometryReader { geo in
                    let gap: CGFloat = 12
                    let pairWidth = max(0, (geo.size.width - gap) / 2)
                    let narrowWidth = max(0, ((pairWidth - gap) * 0.32).rounded(.down))
                    let wideWidth = max(0, pairWidth - gap - narrowWidth)

                    HStack(spacing: gap) {
                        HStack(spacing: gap) {
                            filterMenu(selectedText: seasonDisplayText, options: seasonOptions, setValue: { viewModel.selectSeason($0) })
                                .frame(width: narrowWidth)
                            filterMenu(selectedText: bankDisplayText, options: bankOptions, setValue: { viewModel.selectBankNumber(Int($0)) })
                                .frame(width: wideWidth)
                        }

                        HStack(spacing: gap) {
                            filterMenu(selectedText: playerDisplayText, options: playerOptions, setValue: { viewModel.selectPlayer($0) })
                                .frame(width: narrowWidth)
                            filterMenu(selectedText: machineDisplayText, options: machineOptions, setValue: { viewModel.selectMachine($0) })
                                .frame(width: wideWidth)
                        }
                    }
                }
                .frame(height: isLargeTablet ? 52 : 44)
            } else {
                GeometryReader { geo in
                    let gap: CGFloat = 12
                    let leftWidth = max(0, ((geo.size.width - gap) * 0.32).rounded(.down))
                    let rightWidth = max(0, geo.size.width - gap - leftWidth)
                    VStack(spacing: 8) {
                        HStack(spacing: gap) {
                            filterMenu(selectedText: seasonDisplayText, options: seasonOptions, setValue: { viewModel.selectSeason($0) })
                                .frame(width: leftWidth)
                            filterMenu(selectedText: bankDisplayText, options: bankOptions, setValue: { viewModel.selectBankNumber(Int($0)) })
                                .frame(width: rightWidth)
                        }
                        HStack(spacing: gap) {
                            filterMenu(selectedText: playerDisplayText, options: playerOptions, setValue: { viewModel.selectPlayer($0) })
                                .frame(width: leftWidth)
                            filterMenu(selectedText: machineDisplayText, options: machineOptions, setValue: { viewModel.selectMachine($0) })
                                .frame(width: rightWidth)
                        }
                    }
                }
                .frame(height: isLargeTablet ? 96 : 88)
            }
        }
    }

    private var topRightFilterMenu: some View {
        Menu {
            Button("Clear all filters") {
                viewModel.clearAllFilters()
            }

            Menu("Season") {
                Button("All seasons") { viewModel.selectSeason("") }
                ForEach(viewModel.seasons, id: \.self) { season in
                    Button(seasonToken(season)) { viewModel.selectSeason(season) }
                }
            }

            Menu("Bank") {
                Button("All banks") { viewModel.selectBankNumber(nil) }
                ForEach(viewModel.bankNumbers, id: \.self) { bank in
                    Button("B\(bank)") { viewModel.selectBankNumber(bank) }
                }
            }

            Menu("Player") {
                Button("All players") { viewModel.selectPlayer("") }
                ForEach(viewModel.players, id: \.self) { player in
                    Button(displayLPLPlayerName(player)) { viewModel.selectPlayer(player) }
                }
            }

            Menu("Machine") {
                Button("All machines") { viewModel.selectMachine("") }
                ForEach(viewModel.machines, id: \.self) { machine in
                    Button(machine) { viewModel.selectMachine(machine) }
                }
            }
        } label: {
            AppToolbarFilterTriggerLabel()
        }
        .buttonStyle(.plain)
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    tableHeader
                    AppTableHeaderDivider()

                    if viewModel.isRefreshing && viewModel.rows.isEmpty {
                        AppTablePlaceholder(text: "Loading data…")
                    } else if viewModel.filteredRows.isEmpty {
                        AppTablePlaceholder(text: "No rows - check filters or data source.")
                    } else {
                        let bodyRows = ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.filteredRows.enumerated()), id: \.element.id) { idx, row in
                                    TableRowView(
                                        row: row,
                                        seasonColWidth: seasonColWidth,
                                        playerColWidth: playerColWidth,
                                        bankNumColWidth: bankNumColWidth,
                                        machineColWidth: machineColWidth,
                                        scoreColWidth: scoreColWidth,
                                        pointsColWidth: pointsColWidth,
                                        rowHeight: tableRowHeight,
                                        largeText: isLargeTablet,
                                        isHighlighted: isPreferredLeaguePlayer(row.player)
                                    )
                                        .background(idx.isMultiple(of: 2) ? AppTheme.rowEven : AppTheme.rowOdd)
                                    AppTableRowDivider()
                                }
                            }
                        }
                        bodyRows
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
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            AppHeaderCell(title: "Season", width: seasonColWidth, largeText: isLargeTablet)
            AppHeaderCell(title: "Bank", width: bankNumColWidth, largeText: isLargeTablet)
            AppHeaderCell(title: "Player", width: playerColWidth, largeText: isLargeTablet)
            AppHeaderCell(title: "Machine", width: machineColWidth, largeText: isLargeTablet)
            AppHeaderCell(title: "Score", width: scoreColWidth, largeText: isLargeTablet)
            AppHeaderCell(title: "Points", width: pointsColWidth, largeText: isLargeTablet)
        }
        .frame(height: headerHeight)
        .background(.thinMaterial)
    }

    private var statsCard: some View {
        MachineStatsPanel(
            machine: viewModel.machine,
            season: viewModel.season,
            bankNumber: viewModel.bankNumber,
            bankStats: viewModel.bankStats,
            historicalStats: viewModel.historicalStats,
            largeText: isLargeTablet
        )
        .frame(maxWidth: .infinity)
    }

    private func filterMenu(selectedText: String, options: [FilterOption], setValue: @escaping (String) -> Void) -> some View {
        Menu {
            Button {
                setValue(options.first?.value ?? "")
            } label: {
                Text(options.first?.label ?? "")
                    .font(.footnote)
            }
            ForEach(options, id: \.self) { option in
                if option != options.first {
                    Button {
                        setValue(option.value)
                    } label: {
                        Text(option.label)
                            .font(.footnote)
                    }
                }
            }
        } label: {
            AppDropdownMenuLabel(
                text: selectedText,
                isLargeTablet: isLargeTablet,
                fillsWidth: true,
                embeddedInNavigation: false
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var seasonDisplayText: String { viewModel.season.isEmpty ? "S: All" : seasonToken(viewModel.season) }
    private var bankDisplayText: String { viewModel.bankNumber.map { "B\($0)" } ?? "B: All" }
    private var playerDisplayText: String { viewModel.player.isEmpty ? "Player: All" : displayLPLPlayerName(viewModel.player) }
    private var machineDisplayText: String { viewModel.machine.isEmpty ? "Machine: All" : viewModel.machine }

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

    private func seasonToken(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        return digits.isEmpty ? raw : "S\(digits)"
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }

    private func resolvedTableHeight(maxHeight: CGFloat) -> CGFloat {
        return min(maxHeight, compactTableContentHeight)
    }

    private func isPreferredLeaguePlayer(_ rawPlayer: String) -> Bool {
        leaguePlayerNamesMatch(rawPlayer, preferredLeaguePlayerName)
    }
}

#Preview {
    StatsScreen()
}
