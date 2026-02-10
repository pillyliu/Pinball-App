//
//  StandingsView.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct StandingsView: View {
    @StateObject private var viewModel = StandingsViewModel()
    @State private var tableAvailableWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
        verticalSizeClass == .compact ? 2 : 14
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 12) {
                    seasonSelector

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    standingsTable
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 8)
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
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var seasonSelector: some View {
        Menu {
            ForEach(viewModel.seasons, id: \.self) { season in
                Button("Season \(season)") {
                    viewModel.selectedSeason = season
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(viewModel.selectedSeasonLabel)
                    .font(isLargeTablet ? .callout : .footnote)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(isLargeTablet ? .footnote : .caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isLargeTablet ? 14 : 12)
            .padding(.vertical, isLargeTablet ? 10 : 8)
            .appControlStyle()
        }
        .disabled(viewModel.seasons.isEmpty)
        .tint(.white)
    }

    private var standingsTable: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    tableHeader
                    Divider().overlay(Color(white: 0.2))

                    if viewModel.standings.isEmpty {
                        Text("No rows. Check data source or season selection.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 68)
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
                                        largeText: isLargeTablet
                                    )
                                    .background(index.isMultiple(of: 2) ? AppTheme.rowEven : AppTheme.rowOdd)
                                    Divider().overlay(Color(white: 0.15))
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
        .background(Color(white: 0.1))
    }
}

private struct StandingsRowView: View {
    let standing: Standing
    let rank: Int
    let rankWidth: CGFloat
    let playerWidth: CGFloat
    let pointsWidth: CGFloat
    let eligibleWidth: CGFloat
    let nightsWidth: CGFloat
    let bankWidth: CGFloat
    let largeText: Bool

    var body: some View {
        HStack(spacing: 0) {
            rowCell(rank.formatted(), width: rankWidth, color: rankColor, monospaced: true)
            rowCell(standing.player, width: playerWidth, weight: rank <= 8 ? .semibold : .regular)
            rowCell(formatRounded(standing.seasonTotal), width: pointsWidth, monospaced: true)
            rowCell(standing.eligible, width: eligibleWidth)
            rowCell(standing.nights, width: nightsWidth, monospaced: true)

            ForEach(standing.banks.indices, id: \.self) { index in
                rowCell(formatRounded(standing.banks[index]), width: bankWidth, monospaced: true)
            }
        }
        .frame(height: largeText ? 40 : 36)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.86)
        case 3: return .orange
        default: return .white
        }
    }

    private func rowCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .leading,
        color: Color = .white,
        monospaced: Bool = false,
        weight: Font.Weight = .regular
    ) -> some View {
        let horizontalPadding: CGFloat = 3
        let adjustedWidth = max(0, width - (horizontalPadding * 2))
        return Text(text)
            .font(monospaced
                ? (largeText ? Font.callout.monospacedDigit().weight(weight) : Font.footnote.monospacedDigit().weight(weight))
                : (largeText ? Font.callout.weight(weight) : Font.footnote.weight(weight)))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}

@MainActor
private final class StandingsViewModel: ObservableObject {
    @Published private(set) var rows: [StandingsCSVRow] = []
    @Published var selectedSeason: Int?
    @Published var errorMessage: String?

    private var didLoad = false

    var seasons: [Int] {
        Array(Set(rows.map(\.season))).sorted()
    }

    var selectedSeasonLabel: String {
        if let selectedSeason {
            return "Season \(selectedSeason)"
        }
        return "Select"
    }

    var standings: [Standing] {
        guard let selectedSeason else { return [] }

        let seasonRows = rows.filter { $0.season == selectedSeason }
        guard !seasonRows.isEmpty else { return [] }

        let mapped = seasonRows.map {
            Standing(
                id: $0.player,
                player: $0.player,
                seasonTotal: $0.total,
                eligible: $0.eligible,
                nights: $0.nights,
                banks: $0.banks
            )
        }

        let hasRankForAll = seasonRows.allSatisfy { $0.rank != nil }
        if hasRankForAll {
            var rankByPlayer: [String: Int] = [:]
            for row in seasonRows {
                rankByPlayer[row.player] = row.rank ?? Int.max
            }
            return mapped.sorted { (rankByPlayer[$0.player] ?? Int.max) < (rankByPlayer[$1.player] ?? Int.max) }
        }

        return mapped.sorted { $0.seasonTotal > $1.seasonTotal }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadCSV()
    }

    private func loadCSV() async {
        do {
            let cached = try await PinballDataCache.shared.loadText(path: StandingsCSVLoader.defaultPath)
            guard let text = cached.text else {
                throw StandingsCSVError.network("Standings data is missing from cache and server.")
            }
            rows = try StandingsCSVLoader.parse(text: text)
            errorMessage = nil

            if let selectedSeason, seasons.contains(selectedSeason) {
                self.selectedSeason = selectedSeason
            } else {
                self.selectedSeason = seasons.last
            }
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct Standing: Identifiable {
    let id: String
    let player: String
    let seasonTotal: Double
    let eligible: String
    let nights: String
    let banks: [Double]
}

private struct StandingsCSVRow {
    let season: Int
    let player: String
    let total: Double
    let rank: Int?
    let eligible: String
    let nights: String
    let banks: [Double]
}

private enum StandingsCSVLoader {
    static let defaultPath = "/pinball/data/LPL_Standings.csv"

    static func parse(text: String) throws -> [StandingsCSVRow] {
        let table = parseCSVRows(text)
        guard !table.isEmpty else { return [] }

        let headers = table[0].map { normalizeCSVHeader($0) }
        let required = [
            "season", "player", "total", "bank_1", "bank_2", "bank_3", "bank_4",
            "bank_5", "bank_6", "bank_7", "bank_8"
        ]

        for name in required where !headers.contains(name) {
            throw StandingsCSVError.missingColumn(name)
        }

        return table.dropFirst().compactMap { row in
            guard row.count == headers.count else { return nil }

            let dict = Dictionary(uniqueKeysWithValues: zip(headers, row))

            let season = coerceSeasonNumber(dict["season"] ?? "")
            let player = (dict["player"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let total = Double(dict["total"] ?? "") ?? 0
            let rank = Int((dict["rank"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            let eligible = (dict["eligible"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let nights = (dict["nights"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let banks = (1...8).map { index in
                Double(dict["bank_\(index)"] ?? "") ?? 0
            }

            guard season > 0, !player.isEmpty else { return nil }

            return StandingsCSVRow(
                season: season,
                player: player,
                total: total,
                rank: rank,
                eligible: eligible,
                nights: nights,
                banks: banks
            )
        }
    }
}

private enum StandingsCSVError: LocalizedError {
    case missingColumn(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingColumn(let column):
            return "Standings CSV missing column: \(column)"
        case .network(let message):
            return message
        }
    }
}

private func formatRounded(_ value: Double) -> String {
    Int(value.rounded()).formatted()
}

#Preview {
    StandingsView()
}
