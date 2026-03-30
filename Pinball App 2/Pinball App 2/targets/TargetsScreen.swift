//
//  TargetsScreen.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct TargetsScreen: View {
    let embeddedInNavigation: Bool

    init(embeddedInNavigation: Bool = false) {
        self.embeddedInNavigation = embeddedInNavigation
    }

    @StateObject private var viewModel = TargetsViewModel()
    @State private var tableAvailableWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    private let tableDividerHeight: CGFloat = 1
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var contentHorizontalPadding: CGFloat {
        AppLayout.contentHorizontalPadding(isLargeTablet: isLargeTablet)
    }

    private let baseGameColumnWidth: CGFloat = 160
    private let baseBankColumnWidth: CGFloat = 30
    private let baseScoreColumnWidth: CGFloat = 106
    private var widthScale: CGFloat {
        guard tableAvailableWidth > 0 else { return 1 }
        let baseTotal = baseGameColumnWidth + baseBankColumnWidth + (baseScoreColumnWidth * 3)
        return max(1, min(AppLayout.maxTableWidthScale(isLargeTablet: isLargeTablet), tableAvailableWidth / baseTotal))
    }
    private var scaledGameColumnWidth: CGFloat { baseGameColumnWidth * widthScale }
    private var bankColumnWidth: CGFloat { baseBankColumnWidth * widthScale }
    private var scoreColumnWidth: CGFloat { baseScoreColumnWidth * widthScale }
    private var scaledFixedTableWidth: CGFloat { scaledGameColumnWidth + bankColumnWidth + (scoreColumnWidth * 3) }
    private var tableFlexibleExtraWidth: CGFloat { max(0, tableAvailableWidth - scaledFixedTableWidth) }
    private var gameColumnWidth: CGFloat { scaledGameColumnWidth + (tableFlexibleExtraWidth * (scaledGameColumnWidth / max(1, scaledFixedTableWidth))) }
    private var adjustedBankColumnWidth: CGFloat { bankColumnWidth + (tableFlexibleExtraWidth * (bankColumnWidth / max(1, scaledFixedTableWidth))) }
    private var adjustedScoreColumnWidth: CGFloat { scoreColumnWidth + (tableFlexibleExtraWidth * (scoreColumnWidth / max(1, scaledFixedTableWidth))) }
    private var tableContentWidth: CGFloat { scaledFixedTableWidth + tableFlexibleExtraWidth }
    private var tableMinWidth: CGFloat { tableContentWidth }
    private var headerHeight: CGFloat { isLargeTablet ? 40 : 34 }
    private var tableRowHeight: CGFloat { isLargeTablet ? 38 : 32 }
    private var compactTableContentHeight: CGFloat {
        headerHeight + tableDividerHeight + (CGFloat(viewModel.rows.count) * (tableRowHeight + tableDividerHeight))
    }
    private var sortControlWidth: CGFloat {
        if embeddedInNavigation {
            return isLargeTablet ? 176 : 136
        }
        return isLargeTablet ? 220 : 182
    }
    private var bankControlWidth: CGFloat {
        if embeddedInNavigation {
            return isLargeTablet ? 118 : 90
        }
        return isLargeTablet ? 150 : 122
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
        VStack(alignment: .leading, spacing: 8) {
            headerSection
                .padding(.horizontal, 4)

            if let errorMessage = viewModel.errorMessage {
                AppInlineStatusMessage(text: errorMessage, isError: true)
                    .padding(.horizontal, 2)
            }

            GeometryReader { geo in
                let effectiveTableHeight = resolvedTableHeight(maxHeight: geo.size.height)
                targetsTable
                    .padding(.horizontal, 4)
                    .frame(height: effectiveTableHeight, alignment: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)
            footerSection
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var headerSection: some View {
        let greatColor = AppTheme.targetGreat
        let targetColor = AppTheme.targetMain
        let floorColor = AppTheme.targetFloor

        return VStack(alignment: .center, spacing: 8) {
            if !embeddedInNavigation {
                dropdownControls
            }

            HStack(spacing: 10) {
                Text("2nd highest")
                    .font((isLargeTablet ? Font.footnote : Font.caption).weight(.semibold))
                    .foregroundStyle(greatColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("4th highest")
                    .font((isLargeTablet ? Font.footnote : Font.caption).weight(.semibold))
                    .foregroundStyle(targetColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("8th highest")
                    .font((isLargeTablet ? Font.footnote : Font.caption).weight(.semibold))
                    .foregroundStyle(floorColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 10) {
                Text("\"great game\"")
                    .font(isLargeTablet ? .footnote : .caption)
                    .foregroundStyle(greatColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("main target")
                    .font(isLargeTablet ? .footnote : .caption)
                    .foregroundStyle(targetColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("solid floor")
                    .font(isLargeTablet ? .footnote : .caption)
                    .foregroundStyle(floorColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var dropdownControls: some View {
        HStack(spacing: embeddedInNavigation ? 6 : 8) {
            sortDropdown
            bankDropdown
        }
    }

    private var navSummaryLabels: some View {
        AppToolbarSummaryPair(
            leading: "Sort: \(viewModel.sortMode.title)",
            trailing: viewModel.selectedBankLabel
        )
    }

    private var topRightFilterMenu: some View {
        Menu {
            Section("Sort") {
                ForEach(TargetsSortMode.allCases) { mode in
                    Button("Sort: \(mode.title)") { viewModel.sortMode = mode }
                }
            }

            Section("Bank") {
                Button("Bank: All") { viewModel.selectedBank = nil }
                ForEach(viewModel.bankOptions, id: \.self) { bank in
                    Button("Bank: \(bank)") { viewModel.selectedBank = bank }
                }
            }
        } label: {
            AppToolbarFilterTriggerLabel()
        }
        .buttonStyle(.plain)
    }

    private var sortDropdown: some View {
        sortDropdownMenu
            .buttonStyle(.plain)
        .frame(width: sortControlWidth)
    }

    private var bankDropdown: some View {
        bankDropdownMenu
            .buttonStyle(.plain)
        .frame(width: bankControlWidth)
    }

    private var sortDropdownMenu: some View {
        Menu {
            ForEach(TargetsSortMode.allCases) { mode in
                Button("Sort: \(mode.title)") { viewModel.sortMode = mode }
            }
        } label: {
            AppDropdownMenuLabel(
                text: "Sort: \(viewModel.sortMode.title)",
                isLargeTablet: isLargeTablet,
                widestText: "Sort: \(TargetsSortMode.widestTitle)",
                fillsWidth: false,
                embeddedInNavigation: embeddedInNavigation
            )
        }
    }

    private var bankDropdownMenu: some View {
        Menu {
            Button("All banks") { viewModel.selectedBank = nil }
            ForEach(viewModel.bankOptions, id: \.self) { bank in
                Button("Bank \(bank)") { viewModel.selectedBank = bank }
            }
        } label: {
            AppDropdownMenuLabel(
                text: viewModel.selectedBankLabel,
                isLargeTablet: isLargeTablet,
                fillsWidth: false,
                embeddedInNavigation: embeddedInNavigation
            )
        }
    }

    private var targetsTable: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    tableHeader
                    AppTableHeaderDivider()

                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                                TargetsRowView(
                                    row: row,
                                    gameColumnWidth: gameColumnWidth,
                                    bankColumnWidth: adjustedBankColumnWidth,
                                    scoreColumnWidth: adjustedScoreColumnWidth,
                                    largeText: isLargeTablet
                                )
                                .background(index.isMultiple(of: 2) ? AppTheme.rowEven : AppTheme.rowOdd)

                                AppTableRowDivider()
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
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
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            TargetsHeaderCell(title: "Game", width: gameColumnWidth, largeText: isLargeTablet)
            TargetsHeaderCell(title: "B", width: adjustedBankColumnWidth, alignment: .leading, largeText: isLargeTablet)
            TargetsHeaderCell(title: "2nd", width: adjustedScoreColumnWidth, alignment: .leading, largeText: isLargeTablet)
            TargetsHeaderCell(title: "4th", width: adjustedScoreColumnWidth, alignment: .leading, largeText: isLargeTablet)
            TargetsHeaderCell(title: "8th", width: adjustedScoreColumnWidth, alignment: .leading, largeText: isLargeTablet)
        }
        .frame(height: isLargeTablet ? 40 : 34)
        .background(.thinMaterial)
    }

    private var footerSection: some View {
        Text("Benchmarks are based on historical LPL league results across all seasons where each game appeared. For each game, scores are derived from per-bank results using 2nd / 4th / 8th highest averages with sample-size adjustments. These values are then averaged across all bank appearances for that game.")
            .font(isLargeTablet ? .footnote : .caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }

    private func resolvedTableHeight(maxHeight: CGFloat) -> CGFloat {
        return min(maxHeight, compactTableContentHeight)
    }
}

#Preview {
    TargetsScreen()
}
