//
//  StatsView.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct StatsView: View {
    private struct FilterOption: Hashable {
        let value: String
        let label: String
    }

    @StateObject private var viewModel = StatsViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var tableAvailableWidth: CGFloat = 0
    @State private var statsCardHeight: CGFloat = 0
    private let headerHeight: CGFloat = 34
    
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var useLandscapeSplitLayout: Bool { verticalSizeClass == .compact }
    private var useWideFilterLayout: Bool { isRegularWidth || verticalSizeClass == .compact }
    private var contentHorizontalPadding: CGFloat { verticalSizeClass == .compact ? 2 : 14 }
    private var baseSeasonColWidth: CGFloat { isRegularWidth ? 74 : 56 }
    private var basePlayerColWidth: CGFloat { isRegularWidth ? 170 : 118 }
    private var baseBankNumColWidth: CGFloat { isRegularWidth ? 56 : 44 }
    private var baseMachineColWidth: CGFloat { isRegularWidth ? 230 : 145 }
    private var baseScoreColWidth: CGFloat { isRegularWidth ? 150 : 102 }
    private var basePointsColWidth: CGFloat { isRegularWidth ? 72 : 54 }
    private var baseTableContentWidth: CGFloat {
        baseSeasonColWidth + basePlayerColWidth + baseBankNumColWidth + baseMachineColWidth + baseScoreColWidth + basePointsColWidth + 72
    }
    private var widthScale: CGFloat {
        guard tableAvailableWidth > 0 else { return 1 }
        return max(1, min(1.7, tableAvailableWidth / baseTableContentWidth))
    }
    private var seasonColWidth: CGFloat { baseSeasonColWidth * widthScale }
    private var playerColWidth: CGFloat { basePlayerColWidth * widthScale }
    private var bankNumColWidth: CGFloat { baseBankNumColWidth * widthScale }
    private var machineColWidth: CGFloat { baseMachineColWidth * widthScale }
    private var scoreColWidth: CGFloat { baseScoreColWidth * widthScale }
    private var pointsColWidth: CGFloat { basePointsColWidth * widthScale }
    private var tableContentWidth: CGFloat {
        seasonColWidth + playerColWidth + bankNumColWidth + machineColWidth + scoreColWidth + pointsColWidth + 72
    }
    private var tableMinWidth: CGFloat { max(tableContentWidth, tableAvailableWidth) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if useLandscapeSplitLayout {
                    VStack(spacing: 14) {
                        filterSection

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GeometryReader { geo in
                            let spacing: CGFloat = 14
                            let available = max(0, geo.size.width - spacing)
                            let mainWidth = available * 0.6
                            let machineWidth = available - mainWidth

                            HStack(alignment: .top, spacing: spacing) {
                                tableCard
                                    .frame(width: mainWidth)
                                    .frame(maxHeight: .infinity)
                                statsCard
                                    .frame(width: machineWidth)
                                    .frame(maxHeight: .infinity, alignment: .top)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                } else {
                    VStack(spacing: 14) {
                        filterSection

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GeometryReader { geo in
                            let spacing: CGFloat = 14
                            let defaultStatsHeight: CGFloat = 214
                            let measuredStatsHeight = statsCardHeight > 0 ? statsCardHeight : defaultStatsHeight
                            let bottomBuffer: CGFloat = 14
                            let tableHeight = max(120, geo.size.height - measuredStatsHeight - spacing - bottomBuffer)

                            VStack(alignment: .leading, spacing: spacing) {
                                tableCard
                                    .frame(height: tableHeight)

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
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var filterSection: some View {
        let seasonOptions = [FilterOption(value: "", label: "S: All")] + viewModel.seasons.map {
            FilterOption(value: $0, label: seasonToken($0))
        }
        let playerOptions = [FilterOption(value: "", label: "Player: All")] + viewModel.players.map {
            FilterOption(value: $0, label: $0)
        }
        let bankOptions = [FilterOption(value: "", label: "B: All")] + viewModel.bankNumbers.map {
            FilterOption(value: String($0), label: "B\($0)")
        }
        let machineOptions = [FilterOption(value: "", label: "Machine: All")] + viewModel.machines.map {
            FilterOption(value: $0, label: $0)
        }

        return VStack(spacing: 8) {
            if useWideFilterLayout {
                HStack(spacing: 12) {
                    filterMenu(selectedText: seasonDisplayText, options: seasonOptions, setValue: { viewModel.season = $0 })
                    filterMenu(selectedText: playerDisplayText, options: playerOptions, setValue: { viewModel.player = $0 })
                    filterMenu(selectedText: bankDisplayText, options: bankOptions, setValue: { viewModel.bankNumber = Int($0) })
                    filterMenu(selectedText: machineDisplayText, options: machineOptions, setValue: { viewModel.machine = $0 })
                }
            } else {
                GeometryReader { geo in
                    let gap: CGFloat = 12
                    let leftWidth = max(0, ((geo.size.width - gap) * 0.3).rounded(.down))
                    let rightWidth = max(0, geo.size.width - gap - leftWidth)
                    VStack(spacing: 8) {
                        HStack(spacing: gap) {
                            filterMenu(selectedText: seasonDisplayText, options: seasonOptions, setValue: { viewModel.season = $0 })
                                .frame(width: leftWidth)
                            filterMenu(selectedText: playerDisplayText, options: playerOptions, setValue: { viewModel.player = $0 })
                                .frame(width: rightWidth)
                        }
                        HStack(spacing: gap) {
                            filterMenu(selectedText: bankDisplayText, options: bankOptions, setValue: { viewModel.bankNumber = Int($0) })
                                .frame(width: leftWidth)
                            filterMenu(selectedText: machineDisplayText, options: machineOptions, setValue: { viewModel.machine = $0 })
                                .frame(width: rightWidth)
                        }
                    }
                }
                .frame(height: 88)
            }
        }
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
                                        pointsColWidth: pointsColWidth
                                    )
                                        .background(idx.isMultiple(of: 2) ? AppTheme.rowEven : AppTheme.rowOdd)
                                    Divider().overlay(Color(white: 0.15))
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
        .background(Color(white: 0.11))
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
            HStack(spacing: 8) {
                Text(selectedText)
                    .lineLimit(1)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(white: 0.78))
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .appControlStyle()
            .contentShape(Rectangle())
            .foregroundStyle(.white)
        }
        .tint(.white)
        .frame(maxWidth: .infinity)
    }

    private var seasonDisplayText: String { viewModel.season.isEmpty ? "S: All" : seasonToken(viewModel.season) }
    private var bankDisplayText: String { viewModel.bankNumber.map { "B\($0)" } ?? "B: All" }
    private var playerDisplayText: String { viewModel.player.isEmpty ? "Player: All" : viewModel.player }
    private var machineDisplayText: String { viewModel.machine.isEmpty ? "Machine: All" : viewModel.machine }

    private func seasonToken(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        return digits.isEmpty ? raw : "S\(digits)"
    }
}

private extension View {
    func readHeight(onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onChange(geo.size.height) }
                    .onChange(of: geo.size.height) { _, newValue in
                        onChange(newValue)
                    }
            }
        )
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if machine.isEmpty {
                Text("Select a machine to view detailed stats.")
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.82))
            } else {
                MachineStatsTable(
                    selectedLabel: selectedBankLabel,
                    selectedStats: bankStats,
                    allSeasonsStats: historicalStats
                )
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

    private var selectedBankLabel: String {
        "\(abbreviatedSeason(season)) \(bankNumber.map { "B\($0)" } ?? "B?")"
    }

    private func abbreviatedSeason(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        return digits.isEmpty ? "S?" : "S\(digits)"
    }
}

private struct MachineStatsTable: View {
    let selectedLabel: String
    let selectedStats: StatResult
    let allSeasonsStats: StatResult

    private let labels = ["High", "Low", "Avg", "Med", "Std", "Count"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                headerCell("", align: .leading)
                    .frame(width: 44, alignment: .leading)
                headerCell(selectedLabel, align: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                headerCell("All Seasons", align: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.bottom, 4)

            ForEach(labels, id: \.self) { label in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(white: 0.84))
                        .frame(width: 44, alignment: .leading)
                        .padding(.vertical, 3)
                    statCell(label: label, stats: selectedStats, allSeasons: false)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    statCell(label: label, stats: allSeasonsStats, allSeasons: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func headerCell(_ text: String, align: Alignment) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color(white: 0.74))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: align)
    }

    private func statCell(label: String, stats: StatResult, allSeasons: Bool) -> some View {
        let value: String = switch label {
        case "High": formatScore(stats.high)
        case "Low": formatScore(stats.low)
        case "Avg": formatScore(stats.mean)
        case "Med": formatScore(stats.median)
        case "Std": formatScore(stats.std)
        case "Count": stats.count > 0 ? String(stats.count) : "-"
        default: "-"
        }
        let color: Color = switch label {
        case "High": Color(red: 110 / 255, green: 231 / 255, blue: 183 / 255)
        case "Low": Color(red: 252 / 255, green: 165 / 255, blue: 165 / 255)
        case "Avg", "Med": Color(red: 125 / 255, green: 211 / 255, blue: 252 / 255)
        default: Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255)
        }
        let player: String? = switch label {
        case "High": stats.highPlayer
        case "Low": stats.lowPlayer
        default: nil
        }

        return VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            if label == "High" || label == "Low" {
                Text(playerName(player, allSeasons: allSeasons))
                    .font(.caption2)
                    .foregroundStyle(Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 3)
    }

    private func playerName(_ raw: String?, allSeasons: Bool) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
        return allSeasons ? raw : raw.components(separatedBy: " (S").first ?? raw
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
            errorMessage = nil
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
    }

    static let defaultPath = "/pinball/data/LPL_Stats.csv"

    func loadRows() async throws -> LoadResult {
        let cached = try await PinballDataCache.shared.loadText(path: Self.defaultPath)
        guard let text = cached.text else {
            throw CSVLoaderError.network("Stats CSV is missing from cache and server.")
        }
        return LoadResult(rows: parse(text: text))
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
