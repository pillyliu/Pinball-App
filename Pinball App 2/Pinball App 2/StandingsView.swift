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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    seasonSelector

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    standingsTable
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
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
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(white: 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(white: 0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(viewModel.seasons.isEmpty)
        .tint(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var standingsTable: some View {
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    tableHeader
                    Divider().overlay(Color(white: 0.2))

                    if viewModel.standings.isEmpty {
                        Text("No rows. Check data source or season selection.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 68)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.standings.enumerated()), id: \.element.id) { index, standing in
                                StandingsRowView(standing: standing, rank: index + 1)
                                    .background(index.isMultiple(of: 2) ? Color.clear : Color(white: 0.11))
                                Divider().overlay(Color(white: 0.15))
                            }
                        }
                    }
                }
                .frame(minWidth: 760, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(white: 0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            HeaderCell(title: "#", width: 34)
            HeaderCell(title: "Player", width: 136)
            HeaderCell(title: "Pts", width: 68)
            HeaderCell(title: "Elg", width: 38)
            HeaderCell(title: "N", width: 34)
            HeaderCell(title: "B1", width: 42)
            HeaderCell(title: "B2", width: 42)
            HeaderCell(title: "B3", width: 42)
            HeaderCell(title: "B4", width: 42)
            HeaderCell(title: "B5", width: 42)
            HeaderCell(title: "B6", width: 42)
            HeaderCell(title: "B7", width: 42)
            HeaderCell(title: "B8", width: 42)
        }
        .frame(height: 42)
        .background(Color(white: 0.1))
    }
}

private struct StandingsRowView: View {
    let standing: Standing
    let rank: Int

    var body: some View {
        HStack(spacing: 0) {
            rowCell(rank.formatted(), width: 34, color: rankColor, monospaced: true)
            rowCell(standing.player, width: 136, weight: rank <= 8 ? .semibold : .regular)
            rowCell(formatRounded(standing.seasonTotal), width: 68, monospaced: true)
            rowCell(standing.eligible, width: 38)
            rowCell(standing.nights, width: 34, monospaced: true)

            ForEach(standing.banks.indices, id: \.self) { index in
                rowCell(formatRounded(standing.banks[index]), width: 42, monospaced: true)
            }
        }
        .frame(height: 36)
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
        Text(text)
            .font(monospaced ? .footnote.monospacedDigit().weight(weight) : .footnote.weight(weight))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 3)
    }
}

private struct HeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(white: 0.75))
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 3)
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
        let table = parseCSV(text)
        guard !table.isEmpty else { return [] }

        let headers = table[0].map { normalize($0) }
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

            let season = coerceSeason(dict["season"] ?? "")
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

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var index = 0

        while index < chars.count {
            let char = chars[index]
            if inQuotes {
                if char == "\"" {
                    if index + 1 < chars.count, chars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    break
                default:
                    field.append(char)
                }
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private static func normalize(_ header: String) -> String {
        header
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func coerceSeason(_ value: String) -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        if let number = Int(digits), number > 0 {
            return number
        }
        return Int(trimmed) ?? 0
    }
}

private enum StandingsCSVError: LocalizedError {
    case missingColumn(String)
    case network(String)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .missingColumn(let column):
            return "Standings CSV missing column: \(column)"
        case .network(let message):
            return message
        case .invalidEncoding:
            return "Standings CSV encoding is not supported."
        }
    }
}

private func formatRounded(_ value: Double) -> String {
    Int(value.rounded()).formatted()
}

#Preview {
    StandingsView()
}
