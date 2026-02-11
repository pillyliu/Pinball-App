//
//  LPLTargetsView.swift
//  Pinball App 2
//
//  Created by Codex on 2/5/26.
//

import SwiftUI
import Combine

struct LPLTargetsView: View {
    @StateObject private var viewModel = LPLTargetsViewModel()
    @State private var tableAvailableWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    private let tableDividerHeight: CGFloat = 1
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLargeTablet: Bool {
        AppLayout.isLargeTablet(horizontalSizeClass: horizontalSizeClass, width: viewportWidth)
    }
    private var contentHorizontalPadding: CGFloat {
        verticalSizeClass == .compact ? 2 : 14
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: 8) {
                    headerSection
                        .padding(.horizontal, 4)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
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

    private var headerSection: some View {
        let greatColor = AppTheme.targetGreat
        let targetColor = AppTheme.targetMain
        let floorColor = AppTheme.targetFloor
        let isLandscapePhone = verticalSizeClass == .compact

        return VStack(alignment: .center, spacing: 8) {
            if isLandscapePhone {
                HStack(spacing: 10) {
                    Text("2nd highest \"great game\"")
                        .font((isLargeTablet ? Font.footnote : Font.caption).weight(.semibold))
                        .foregroundStyle(greatColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("4th highest main target")
                        .font((isLargeTablet ? Font.footnote : Font.caption).weight(.semibold))
                        .foregroundStyle(targetColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("8th highest solid floor")
                        .font((isLargeTablet ? Font.footnote : Font.caption).weight(.semibold))
                        .foregroundStyle(floorColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
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

            HStack(spacing: 8) {
                Menu {
                    ForEach(LPLTargetsSortMode.allCases) { mode in
                        Button("Sort: \(mode.title)") { viewModel.sortMode = mode }
                    }
                } label: {
                    ZStack {
                        HStack(spacing: AppLayout.dropdownContentSpacing) {
                            Text("Sort: \(LPLTargetsSortMode.widestTitle)")
                                .font(AppLayout.dropdownTextFont(isLargeTablet: isLargeTablet))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(AppLayout.dropdownChevronFont(isLargeTablet: isLargeTablet))
                                .foregroundStyle(.secondary)
                        }
                        .opacity(0)

                        HStack(spacing: AppLayout.dropdownContentSpacing) {
                            Text("Sort: \(viewModel.sortMode.title)")
                                .font(AppLayout.dropdownTextFont(isLargeTablet: isLargeTablet))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(AppLayout.dropdownChevronFont(isLargeTablet: isLargeTablet))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, AppLayout.dropdownHorizontalPadding(isLargeTablet: isLargeTablet))
                    .padding(.vertical, AppLayout.dropdownVerticalPadding(isLargeTablet: isLargeTablet))
                }
                .buttonStyle(.glass)

                Menu {
                    Button("All banks") { viewModel.selectedBank = nil }
                    ForEach(viewModel.bankOptions, id: \.self) { bank in
                        Button("Bank \(bank)") { viewModel.selectedBank = bank }
                    }
                } label: {
                    HStack(spacing: AppLayout.dropdownContentSpacing) {
                        Text(viewModel.selectedBankLabel)
                            .font(AppLayout.dropdownTextFont(isLargeTablet: isLargeTablet))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(AppLayout.dropdownChevronFont(isLargeTablet: isLargeTablet))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppLayout.dropdownHorizontalPadding(isLargeTablet: isLargeTablet))
                    .padding(.vertical, AppLayout.dropdownVerticalPadding(isLargeTablet: isLargeTablet))
                }
                .buttonStyle(.glass)
            }
            .padding(.top, 4)
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
                                LPLTargetsRowView(
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
            LPLTargetsHeaderCell(title: "Game", width: gameColumnWidth, largeText: isLargeTablet)
            LPLTargetsHeaderCell(title: "B", width: adjustedBankColumnWidth, alignment: .leading, largeText: isLargeTablet)
            LPLTargetsHeaderCell(title: "2nd", width: adjustedScoreColumnWidth, alignment: .leading, largeText: isLargeTablet)
            LPLTargetsHeaderCell(title: "4th", width: adjustedScoreColumnWidth, alignment: .leading, largeText: isLargeTablet)
            LPLTargetsHeaderCell(title: "8th", width: adjustedScoreColumnWidth, alignment: .leading, largeText: isLargeTablet)
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

private struct LPLTargetsRowView: View {
    let row: LPLTargetRow
    let gameColumnWidth: CGFloat
    let bankColumnWidth: CGFloat
    let scoreColumnWidth: CGFloat
    let largeText: Bool

    var body: some View {
        HStack(spacing: 0) {
            rowCell(row.target.game, width: gameColumnWidth)
            rowCell(row.bank.map(String.init) ?? "-", width: bankColumnWidth, alignment: .leading)
            rowCell(row.target.great.formattedWithCommas, width: scoreColumnWidth, alignment: .leading, color: AppTheme.targetGreat, monospaced: true, weight: .medium)
            rowCell(row.target.main.formattedWithCommas, width: scoreColumnWidth, alignment: .leading, color: AppTheme.targetMain, monospaced: true)
            rowCell(row.target.floor.formattedWithCommas, width: scoreColumnWidth, alignment: .leading, color: AppTheme.targetFloor, monospaced: true)
        }
        .frame(height: largeText ? 38 : 32)
    }

    private func rowCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .leading,
        color: Color = .primary,
        monospaced: Bool = false,
        weight: Font.Weight = .regular
    ) -> some View {
        let horizontalPadding: CGFloat = 4
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        return Text(text)
            .font(monospaced
                ? (largeText ? Font.callout.monospacedDigit().weight(weight) : Font.footnote.monospacedDigit().weight(weight))
                : (largeText ? Font.callout.weight(weight) : Font.footnote.weight(weight)))
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}

private struct LPLTargetsHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var largeText: Bool = false

    var body: some View {
        let horizontalPadding: CGFloat = 4
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        return Text(title)
            .font((largeText ? Font.footnote : Font.caption2).weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}

private struct LPLTargetRow: Identifiable {
    let target: LPLTarget
    let bank: Int?
    let group: Int?
    let pos: Int?
    let libraryOrder: Int
    let fallbackOrder: Int

    var id: String { target.id }
}

private enum LPLTargetsSortMode: String, CaseIterable, Identifiable {
    case location
    case bank
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return "Location"
        case .bank:
            return "Bank"
        case .alphabetical:
            return "Alphabetical"
        }
    }

    static var widestTitle: String {
        allCases.map(\.title).max(by: { $0.count < $1.count }) ?? "Alphabetical"
    }
}

@MainActor
private final class LPLTargetsViewModel: ObservableObject {
    @Published private(set) var rows: [LPLTargetRow] = LPLTarget.rows.enumerated().map { index, target in
        LPLTargetRow(target: target, bank: nil, group: nil, pos: nil, libraryOrder: Int.max, fallbackOrder: index)
    }
    @Published var sortMode: LPLTargetsSortMode = .location {
        didSet { applySortAndFilter() }
    }
    @Published var selectedBank: Int? {
        didSet { applySortAndFilter() }
    }
    @Published var errorMessage: String?

    private var didLoad = false
    private var allRows: [LPLTargetRow] = LPLTarget.rows.enumerated().map { index, target in
        LPLTargetRow(target: target, bank: nil, group: nil, pos: nil, libraryOrder: Int.max, fallbackOrder: index)
    }

    private static let libraryPath = "/pinball/data/pinball_library.json"

    var bankOptions: [Int] {
        Array(Set(allRows.compactMap(\.bank))).sorted()
    }

    var selectedBankLabel: String {
        selectedBank.map { "Bank \($0)" } ?? "All banks"
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadLibraryOrdering()
    }

    private func loadLibraryOrdering() async {
        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.libraryPath)
            guard let text = cached.text,
                  let data = text.data(using: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }

            let libraryGames = try JSONDecoder().decode([LibraryGame].self, from: data)
            let rowsWithLibrary = mergeTargetsWithLibrary(libraryGames: libraryGames)

            allRows = rowsWithLibrary
            applySortAndFilter()

            errorMessage = nil
        } catch {
            errorMessage = "Using default order (library unavailable)."
        }
    }

    private func mergeTargetsWithLibrary(libraryGames: [LibraryGame]) -> [LPLTargetRow] {
        let normalizedLibrary: [(index: Int, normalized: String, bank: Int?, group: Int?, pos: Int?)] = libraryGames.enumerated().map { index, game in
            (index, normalize(game.name), game.bank, game.group, game.pos)
        }

        return LPLTarget.rows.enumerated().map { fallbackIndex, target in
            let normalizedTarget = normalize(target.game)
            let aliasKeys = aliases[normalizedTarget] ?? []
            let candidateKeys = [normalizedTarget] + aliasKeys

            if let exact = normalizedLibrary.first(where: { candidateKeys.contains($0.normalized) }) {
                return LPLTargetRow(
                    target: target,
                    bank: exact.bank,
                    group: exact.group,
                    pos: exact.pos,
                    libraryOrder: exact.index,
                    fallbackOrder: fallbackIndex
                )
            }

            if let loose = normalizedLibrary.first(where: { entry in
                candidateKeys.contains { key in
                    entry.normalized.contains(key) || key.contains(entry.normalized)
                }
            }) {
                return LPLTargetRow(
                    target: target,
                    bank: loose.bank,
                    group: loose.group,
                    pos: loose.pos,
                    libraryOrder: loose.index,
                    fallbackOrder: fallbackIndex
                )
            }

            return LPLTargetRow(target: target, bank: nil, group: nil, pos: nil, libraryOrder: Int.max, fallbackOrder: fallbackIndex)
        }
    }

    private func applySortAndFilter() {
        let sortedRows: [LPLTargetRow] = switch sortMode {
        case .location:
            allRows.sorted {
                byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        case .bank:
            allRows.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.target.game.lowercased(), $1.target.game.lowercased())
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        case .alphabetical:
            allRows.sorted {
                byAscending($0.target.game.lowercased(), $1.target.game.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        }

        rows = if let selectedBank {
            sortedRows.filter { $0.bank == selectedBank }
        } else {
            sortedRows
        }
    }

    private func byOptionalAscending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return byAscending(l, r)
        case (nil, nil):
            return nil
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func byAscending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        if lhs == rhs { return nil }
        return lhs < rhs
    }

    private func normalize(_ name: String) -> String {
        let lowered = name.lowercased()
            .replacingOccurrences(of: "&", with: " and ")

        return lowered.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private var aliases: [String: [String]] {
        [
            "tmnt": ["teenagemutantninjaturtles"],
            "thegetaway": ["thegetawayhighspeedii"],
            "starwars2017": ["starwars"],
            "jurassicparkstern2019": ["jurassicpark", "jurassicpark2019"],
            "attackfrommars": ["attackfrommarsremake"],
            "dungeonsanddragons": ["dungeonsdragons"]
        ]
    }
}

private struct LibraryGame: Decodable {
    let name: String
    let group: Int?
    let pos: Int?
    let bank: Int?
}

private struct LPLTarget: Identifiable {
    let game: String
    let great: Int64
    let main: Int64
    let floor: Int64

    var id: String { game }

    static let rows: [LPLTarget] = [
        .init(game: "Avengers: Infinity Quest", great: 173_438_323, main: 88_524_766, floor: 39_851_803),
        .init(game: "Kiss", great: 198_506_351, main: 97_959_214, floor: 36_089_540),
        .init(game: "Cactus Canyon", great: 47_757_329, main: 27_567_623, floor: 14_452_827),
        .init(game: "Uncanny X-Men", great: 225_283_763, main: 108_327_713, floor: 63_821_317),
        .init(game: "Jurassic Park (Stern 2019)", great: 319_640_285, main: 126_326_601, floor: 58_637_502),
        .init(game: "Tales of the Arabian Nights", great: 15_762_751, main: 9_345_267, floor: 5_556_107),
        .init(game: "The Munsters", great: 82_533_584, main: 34_629_771, floor: 17_369_006),
        .init(game: "Medieval Madness", great: 46_553_686, main: 29_361_166, floor: 14_409_182),
        .init(game: "AC/DC", great: 78_885_896, main: 46_469_006, floor: 19_681_744),
        .init(game: "Star Wars (2017)", great: 1_096_631_040, main: 647_340_570, floor: 319_976_625),
        .init(game: "James Bond", great: 358_874_928, main: 200_180_907, floor: 82_457_332),
        .init(game: "Indiana Jones", great: 291_687_662, main: 177_986_136, floor: 81_470_450),
        .init(game: "Metallica", great: 77_377_060, main: 43_847_284, floor: 17_158_523),
        .init(game: "Godzilla", great: 646_887_088, main: 286_268_525, floor: 123_536_572),
        .init(game: "Dungeons and Dragons", great: 418_422_050, main: 182_415_065, floor: 123_730_030),
        .init(game: "Game of Thrones", great: 949_759_118, main: 326_708_555, floor: 99_242_412),
        .init(game: "The Simpsons Pinball Party", great: 21_891_586, main: 14_562_712, floor: 6_092_065),
        .init(game: "The Getaway", great: 101_330_386, main: 59_599_913, floor: 31_934_372),
        .init(game: "Monster Bash", great: 140_207_751, main: 77_290_194, floor: 33_846_092),
        .init(game: "Venom", great: 305_244_276, main: 125_417_334, floor: 53_133_636),
        .init(game: "King Kong", great: 446_519_150, main: 105_609_360, floor: 76_835_450),
        .init(game: "Rush", great: 339_038_483, main: 95_538_978, floor: 50_832_140),
        .init(game: "Deadpool", great: 358_162_103, main: 146_074_855, floor: 69_866_975),
        .init(game: "John Wick", great: 177_005_389, main: 142_548_085, floor: 60_787_832),
        .init(game: "Attack From Mars", great: 5_521_789_989, main: 3_115_115_261, floor: 1_766_530_554),
        .init(game: "Foo Fighters", great: 437_507_022, main: 118_516_715, floor: 52_503_338),
        .init(game: "The Mandalorian", great: 246_663_781, main: 139_131_898, floor: 54_050_835),
        .init(game: "Tron", great: 32_748_236, main: 20_993_568, floor: 12_428_468),
        .init(game: "TMNT", great: 20_008_656, main: 13_337_749, floor: 7_479_849),
        .init(game: "Ghostbusters", great: 721_735_856, main: 238_692_633, floor: 85_037_818),
        .init(game: "Stranger Things", great: 269_360_318, main: 180_571_244, floor: 110_080_667),
        .init(game: "Star Trek", great: 115_837_761, main: 68_886_970, floor: 27_550_663),
        .init(game: "Pulp Fiction", great: 2_137_055, main: 1_124_280, floor: 708_345),
        .init(game: "Elvira's House of Horrors", great: 68_770_087, main: 38_590_427, floor: 18_216_957),
        .init(game: "Black Knight: Sword of Rage", great: 160_663_925, main: 62_325_610, floor: 40_949_470),
        .init(game: "The Addams Family", great: 126_854_859, main: 77_135_279, floor: 38_020_435),
        .init(game: "Scared Stiff", great: 18_537_846, main: 13_171_488, floor: 6_029_324),
        .init(game: "Fall of the Empire", great: 548_469_290, main: 308_139_210, floor: 40_719_400),
        .init(game: "Jaws", great: 523_921_050, main: 325_577_015, floor: 155_754_968)
    ]
}

private extension Int64 {
    var formattedWithCommas: String {
        self.formatted(.number.grouping(.automatic))
    }
}

#Preview {
    LPLTargetsView()
}
