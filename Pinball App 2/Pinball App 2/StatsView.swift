//
//  StatsView.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let rowHeight: CGFloat = 32
    private let headerHeight: CGFloat = 34
    private let maxBodyHeight: CGFloat = 380
    
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var seasonColWidth: CGFloat { isRegularWidth ? 74 : 56 }
    private var playerColWidth: CGFloat { isRegularWidth ? 170 : 118 }
    private var bankNumColWidth: CGFloat { isRegularWidth ? 56 : 44 }
    private var machineColWidth: CGFloat { isRegularWidth ? 230 : 145 }
    private var scoreColWidth: CGFloat { isRegularWidth ? 150 : 102 }
    private var pointsColWidth: CGFloat { isRegularWidth ? 72 : 54 }
    private var tableContentWidth: CGFloat {
        seasonColWidth + playerColWidth + bankNumColWidth + machineColWidth + scoreColWidth + pointsColWidth + 72
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: 14) {
                        filterSection

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if horizontalSizeClass == .regular {
                            HStack(alignment: .top, spacing: 14) {
                                tableCard
                                    .frame(maxWidth: .infinity)
                                statsCard
                                    .frame(width: 320)
                            }
                        } else {
                            tableCard
                            statsCard
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var filterSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                filterMenu(
                    title: "Season",
                    value: viewModel.season,
                    allLabel: "All",
                    options: viewModel.seasons,
                    setValue: { viewModel.season = $0 }
                )
                filterMenu(
                    title: "Player",
                    value: viewModel.player,
                    allLabel: "All",
                    options: viewModel.players,
                    setValue: { viewModel.player = $0 }
                )
            }

            HStack(spacing: 10) {
                filterMenu(
                    title: "Bank",
                    value: viewModel.bankNumber.map(String.init) ?? "",
                    allLabel: "All",
                    options: viewModel.bankNumbers.map(String.init),
                    setValue: { viewModel.bankNumber = Int($0) }
                )
                filterMenu(
                    title: "Machine",
                    value: viewModel.machine,
                    allLabel: "All",
                    options: viewModel.machines,
                    setValue: { viewModel.machine = $0 }
                )
            }
        }
        .padding(12)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    tableHeader
                    Divider().overlay(Color(white: 0.2))

                    if viewModel.filteredRows.isEmpty {
                        Text("No rows - check filters or data source.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.filteredRows.enumerated()), id: \.element.id) { idx, row in
                                    TableRowView(
                                        row: row,
                                        seasonColWidth: seasonColWidth,
                                        playerColWidth: playerColWidth,
                                        bankNumColWidth: bankNumColWidth,
                                        machineColWidth: machineColWidth,
                                        scoreColWidth: scoreColWidth,
                                        pointsColWidth: pointsColWidth
                                    )
                                        .background(idx.isMultiple(of: 2) ? Color.clear : Color(white: 0.11))
                                    Divider().overlay(Color(white: 0.15))
                                }
                            }
                        }
                        .frame(height: tableBodyHeight)
                    }
                }
                .frame(minWidth: tableContentWidth, alignment: .leading)
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

    private var tableBodyHeight: CGFloat {
        let contentHeight = CGFloat(viewModel.filteredRows.count) * rowHeight
        return min(maxBodyHeight, max(rowHeight, contentHeight))
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            HeaderCell(title: "Season", width: seasonColWidth)
            HeaderCell(title: "Player", width: playerColWidth)
            HeaderCell(title: "Bank", width: bankNumColWidth)
            HeaderCell(title: "Machine", width: machineColWidth)
            HeaderCell(title: "Score", width: scoreColWidth)
            HeaderCell(title: "Points", width: pointsColWidth)
        }
        .frame(height: headerHeight)
        .background(Color(white: 0.1))
    }

    private var statsCard: some View {
        MachineStatsPanel(
            machine: viewModel.machine,
            season: viewModel.season,
            bankNumber: viewModel.bankNumber,
            bankStats: viewModel.bankStats,
            historicalStats: viewModel.historicalStats
        )
        .frame(maxWidth: .infinity)
    }

    private func filterMenu(
        title: String,
        value: String,
        allLabel: String,
        options: [String],
        setValue: @escaping (String) -> Void
    ) -> some View {
        Menu {
            Button(allLabel) { setValue("") }
            ForEach(options, id: \.self) { option in
                Button(option) { setValue(option) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(value.isEmpty ? allLabel : value)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color(white: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
        }
        .tint(.white)
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
            .padding(.horizontal, 4)
    }
}

private struct TableRowView: View {
    let row: ScoreRow
    let seasonColWidth: CGFloat
    let playerColWidth: CGFloat
    let bankNumColWidth: CGFloat
    let machineColWidth: CGFloat
    let scoreColWidth: CGFloat
    let pointsColWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            rowCell(row.season, width: seasonColWidth)
            rowCell(row.player, width: playerColWidth)
            rowCell(String(row.bankNumber), width: bankNumColWidth)
            rowCell(row.machine, width: machineColWidth)
            rowCell(formatScore(row.rawScore), width: scoreColWidth, monospaced: true)
            rowCell(formatPoints(row.points), width: pointsColWidth, monospaced: true)
        }
        .frame(height: 32)
    }

    private func rowCell(_ text: String, width: CGFloat, alignment: Alignment = .leading, monospaced: Bool = false) -> some View {
        Text(text)
            .font(monospaced ? .footnote.monospacedDigit() : .footnote)
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 4)
    }
}

private struct MachineStatsPanel: View {
    let machine: String
    let season: String
    let bankNumber: Int?
    let bankStats: StatResult
    let historicalStats: StatResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Machine Stats")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if machine.isEmpty && bankNumber == nil {
                Text("Select a bank or machine to view detailed stats.")
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.82))
            } else {
                StatsSection(
                    title: "Selected Bank",
                    label: "\(season.isEmpty ? "Season" : season) - Bank \(bankNumber.map(String.init) ?? "?")",
                    stats: bankStats
                )
                StatsSection(
                    title: "Historical (All Seasons)",
                    label: "All Seasons",
                    stats: historicalStats
                )
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StatsSection: View {
    let title: String
    let label: String
    let stats: StatResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if stats.count == 0 {
                Text("No data - select filters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.78))

                statRow(label: "High", value: formatScore(stats.high), subtitle: stats.highPlayer, valueColor: .green)
                statRow(label: "Low", value: formatScore(stats.low), subtitle: stats.lowPlayer, valueColor: .red)
                statRow(label: "Mean", value: formatScore(stats.mean), subtitle: nil)
                statRow(label: "Median", value: formatScore(stats.median), subtitle: nil)
                statRow(label: "Std Dev", value: formatScore(stats.std), subtitle: nil)
                statRow(label: "Count", value: String(stats.count), subtitle: nil)
            }
        }
    }

    private func statRow(label: String, value: String, subtitle: String?, valueColor: Color = .white) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(Color(white: 0.82))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .foregroundStyle(valueColor)
                    .font(.footnote.monospacedDigit())
                if let subtitle {
                    Text("by \(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(Color(white: 0.72))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

@MainActor
private final class StatsViewModel: ObservableObject {
    @Published private(set) var rows: [ScoreRow] = []
    @Published var errorMessage: String?
    private var didLoad = false

    @Published var season: String = "" {
        didSet {
            if oldValue != season {
                player = ""
                bankNumber = nil
                machine = ""
            }
        }
    }

    @Published var player: String = "" {
        didSet {
            if oldValue != player {
                bankNumber = nil
                machine = ""
            }
        }
    }

    @Published var bankNumber: Int? {
        didSet {
            if oldValue != bankNumber {
                machine = ""
            }
        }
    }

    @Published var machine: String = ""

    var seasons: [String] {
        Array(Set(rows.map(\.season))).sorted()
    }

    var players: [String] {
        Array(Set(rows.filter { season.isEmpty || $0.season == season }.map(\.player))).sorted()
    }

    var bankNumbers: [Int] {
        Array(Set(rows
            .filter {
                (season.isEmpty || $0.season == season) &&
                (player.isEmpty || $0.player == player)
            }
            .map(\.bankNumber)))
            .sorted()
    }

    var machines: [String] {
        Array(Set(rows
            .filter {
                (season.isEmpty || $0.season == season) &&
                (player.isEmpty || $0.player == player) &&
                (bankNumber == nil || $0.bankNumber == bankNumber)
            }
            .map(\.machine)
            .filter { !$0.isEmpty }))
            .sorted()
    }

    var filteredRows: [ScoreRow] {
        rows.filter {
            (season.isEmpty || $0.season == season) &&
            (player.isEmpty || $0.player == player) &&
            (bankNumber == nil || $0.bankNumber == bankNumber) &&
            (machine.isEmpty || $0.machine == machine)
        }
    }

    var bankStats: StatResult {
        let scoped = rows.filter {
            !season.isEmpty &&
            $0.season == season &&
            bankNumber != nil &&
            $0.bankNumber == bankNumber &&
            !machine.isEmpty &&
            $0.machine == machine
        }
        return computeStats(from: scoped, isBankScope: true)
    }

    var historicalStats: StatResult {
        let scoped = rows.filter {
            !machine.isEmpty && $0.machine == machine
        }
        return computeStats(from: scoped, isBankScope: false)
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadCSV()
    }

    private func loadCSV() async {
        do {
            let loaded = try await CSVScoreLoader().loadRows()
            let loadedRows = loaded.rows
            rows = loadedRows
            errorMessage = loaded.statusMessage
            season = latestSeason(in: loadedRows) ?? ""
            player = ""
            bankNumber = nil
            machine = ""
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
    }

    private func latestSeason(in rows: [ScoreRow]) -> String? {
        rows
            .map(\.season)
            .reduce(into: [String: Int]()) { acc, season in
                let digits = season.filter(\.isNumber)
                let number = Int(digits) ?? Int.min
                if number > (acc[season] ?? Int.min) {
                    acc[season] = number
                }
            }
            .max { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }?
            .key
    }

    private func computeStats(from scope: [ScoreRow], isBankScope: Bool) -> StatResult {
        let values = scope.map(\.rawScore).filter { $0.isFinite && $0 > 0 }
        guard !values.isEmpty else { return .empty }

        let sorted = values.sorted()
        let count = values.count
        let low = sorted.first!
        let high = sorted.last!
        let mean = values.reduce(0, +) / Double(count)
        let median = count.isMultiple(of: 2)
            ? (sorted[count / 2 - 1] + sorted[count / 2]) / 2
            : sorted[(count - 1) / 2]
        let variance = values.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(count)
        let std = sqrt(variance)

        let lowRow = scope.first(where: { $0.rawScore == low })
        let highRow = scope.first(where: { $0.rawScore == high })

        return StatResult(
            count: count,
            low: low,
            lowPlayer: lowRow.map { playerLabel(for: $0, isBankScope: isBankScope) },
            high: high,
            highPlayer: highRow.map { playerLabel(for: $0, isBankScope: isBankScope) },
            mean: mean,
            median: median,
            std: std
        )
    }

    private func playerLabel(for row: ScoreRow, isBankScope: Bool) -> String {
        if isBankScope {
            return row.player
        }
        return "\(row.player) (\(abbreviateSeason(row.season)))"
    }

    private func abbreviateSeason(_ season: String) -> String {
        let digits = season.filter { $0.isNumber }
        return digits.isEmpty ? season : "S\(digits)"
    }
}

private struct ScoreRow: Identifiable {
    let id: Int
    let season: String
    let bankNumber: Int
    let bank: String
    let player: String
    let machine: String
    let rawScore: Double
    let points: Double
}

private struct StatResult {
    let count: Int
    let low: Double?
    let lowPlayer: String?
    let high: Double?
    let highPlayer: String?
    let mean: Double?
    let median: Double?
    let std: Double?

    static let empty = StatResult(count: 0, low: nil, lowPlayer: nil, high: nil, highPlayer: nil, mean: nil, median: nil, std: nil)
}

private final class CSVScoreLoader {
    struct LoadResult {
        let rows: [ScoreRow]
        let statusMessage: String?
    }

    static let defaultPath = "/pinball/data/LPL_Stats.csv"

    func loadRows() async throws -> LoadResult {
        let cached = try await PinballDataCache.shared.loadText(path: Self.defaultPath)
        guard let text = cached.text else {
            throw CSVLoaderError.network("Stats CSV is missing from cache and server.")
        }
        return LoadResult(rows: parse(text: text), statusMessage: cached.statusMessage)
    }

    private func parse(text: String) -> [ScoreRow] {
        let table = parseCSV(text)
        guard let header = table.first else { return [] }
        let headers = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        func idx(_ name: String) -> Int {
            headers.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) ?? -1
        }

        let seasonIndex = idx("Season")
        let bankNumberIndex = idx("BankNumber")
        let bankIndex = idx("Bank")
        let playerIndex = idx("Player")
        let machineIndex = idx("Machine")
        let rawScoreIndex = idx("RawScore")
        let pointsIndex = idx("Points")

        guard [seasonIndex, bankNumberIndex, bankIndex, playerIndex, machineIndex, rawScoreIndex, pointsIndex].allSatisfy({ $0 >= 0 }) else {
            return []
        }

        return table.dropFirst().enumerated().compactMap { offset, columns in
            guard columns.count == headers.count else { return nil }

            let season = normalizeSeason(columns[seasonIndex])
            let bankNumber = Int(columns[bankNumberIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let bank = columns[bankIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let player = columns[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let machine = columns[machineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawScore = Double(columns[rawScoreIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let points = Double(columns[pointsIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            return ScoreRow(
                id: offset,
                season: season,
                bankNumber: bankNumber,
                bank: bank,
                player: player,
                machine: machine,
                rawScore: rawScore,
                points: points
            )
        }
    }

    private func parseCSV(_ text: String) -> [[String]] {
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
}

private enum CSVLoaderError: LocalizedError {
    case network(String)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .invalidEncoding:
            return "LPL_Stats.csv encoding is not supported."
        }
    }
}

private func formatScore(_ value: Double?) -> String {
    guard let value, value.isFinite, value > 0 else { return "-" }
    return Int(value.rounded()).formatted(.number.grouping(.automatic))
}

private func formatPoints(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "-" }
    return Int(value.rounded()).formatted()
}

private func normalizeSeason(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.filter(\.isNumber)
    return digits.isEmpty ? trimmed : digits
}

#Preview {
    StatsView()
}
