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

    private let gameColumnWidth: CGFloat = 160
    private let bankColumnWidth: CGFloat = 30
    private let scoreColumnWidth: CGFloat = 106

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 8) {
                        headerSection

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 2)
                        }

                        targetsTable
                        footerSection
                    }
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

    private var headerSection: some View {
        let greatColor = Color(red: 0.73, green: 0.96, blue: 0.82)
        let targetColor = Color(red: 0.75, green: 0.86, blue: 0.99)
        let floorColor = Color(red: 0.9, green: 0.91, blue: 0.92)

        return VStack(alignment: .leading, spacing: 8) {
            Text("LPL Score Targets")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                Text("2nd highest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(greatColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("4th highest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(targetColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("8th highest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(floorColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Text("\"great game\"")
                    .font(.caption)
                    .foregroundStyle(greatColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("main target")
                    .font(.caption)
                    .foregroundStyle(targetColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("solid floor")
                    .font(.caption)
                    .foregroundStyle(floorColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Menu {
                    ForEach(LPLTargetsSortMode.allCases) { mode in
                        Button("Sort: \(mode.title)") { viewModel.sortMode = mode }
                    }
                } label: {
                    ZStack {
                        HStack(spacing: 6) {
                            Text("Sort: \(LPLTargetsSortMode.widestTitle)")
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .opacity(0)

                        HStack(spacing: 6) {
                            Text("Sort: \(viewModel.sortMode.title)")
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(white: 0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .tint(.white)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var targetsTable: some View {
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    tableHeader
                    Divider().overlay(Color(white: 0.2))

                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                            LPLTargetsRowView(
                                row: row,
                                gameColumnWidth: gameColumnWidth,
                                bankColumnWidth: bankColumnWidth,
                                scoreColumnWidth: scoreColumnWidth
                            )
                            .background(index.isMultiple(of: 2) ? Color.clear : Color(white: 0.11))

                            Divider().overlay(Color(white: 0.15))
                        }
                    }
                }
                .frame(minWidth: gameColumnWidth + bankColumnWidth + (scoreColumnWidth * 3), alignment: .leading)
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
            LPLTargetsHeaderCell(title: "Game", width: gameColumnWidth)
            LPLTargetsHeaderCell(title: "B", width: bankColumnWidth, alignment: .leading)
            LPLTargetsHeaderCell(title: "2nd", width: scoreColumnWidth, alignment: .leading)
            LPLTargetsHeaderCell(title: "4th", width: scoreColumnWidth, alignment: .leading)
            LPLTargetsHeaderCell(title: "8th", width: scoreColumnWidth, alignment: .leading)
        }
        .frame(height: 34)
        .background(Color(white: 0.1))
    }

    private var footerSection: some View {
        Text("Benchmarks are based on historical LPL league results across all seasons where each game appeared. For each game, scores are derived from per-bank results using 2nd / 4th / 8th highest averages with sample-size adjustments. Method: For each game, scores are grouped by season and bank. When a full field played, the 2nd / 4th / 8th highest scores are taken. When about half the league played, we use mean(1st & 2nd), 3rd, and 4th. These values are then averaged across all appearances for that game.")
            .font(.caption)
            .foregroundStyle(Color(white: 0.66))
            .padding(.horizontal, 4)
    }
}

private struct LPLTargetsRowView: View {
    let row: LPLTargetRow
    let gameColumnWidth: CGFloat
    let bankColumnWidth: CGFloat
    let scoreColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            rowCell(row.target.game, width: gameColumnWidth)
            rowCell(row.bank.map(String.init) ?? "-", width: bankColumnWidth, alignment: .leading)
            rowCell(row.target.great.formattedWithCommas, width: scoreColumnWidth, alignment: .leading, color: Color(red: 0.73, green: 0.96, blue: 0.82), monospaced: true, weight: .medium)
            rowCell(row.target.main.formattedWithCommas, width: scoreColumnWidth, alignment: .leading, color: Color(red: 0.75, green: 0.86, blue: 0.99), monospaced: true)
            rowCell(row.target.floor.formattedWithCommas, width: scoreColumnWidth, alignment: .leading, color: Color(red: 0.9, green: 0.91, blue: 0.92), monospaced: true)
        }
        .frame(height: 32)
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
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 4)
    }
}

private struct LPLTargetsHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(white: 0.75))
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 4)
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
        didSet { applySort() }
    }
    @Published var errorMessage: String?

    private var didLoad = false
    private var allRows: [LPLTargetRow] = LPLTarget.rows.enumerated().map { index, target in
        LPLTargetRow(target: target, bank: nil, group: nil, pos: nil, libraryOrder: Int.max, fallbackOrder: index)
    }

    private static let libraryPath = "/pinball/data/pinball_library.json"

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
            applySort()

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

    private func applySort() {
        switch sortMode {
        case .location:
            rows = allRows.sorted {
                byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        case .bank:
            rows = allRows.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.target.game.lowercased(), $1.target.game.lowercased())
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        case .alphabetical:
            rows = allRows.sorted {
                byAscending($0.target.game.lowercased(), $1.target.game.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
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
