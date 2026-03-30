import Foundation
import Combine

@MainActor
final class TargetsViewModel: ObservableObject {
    @Published private(set) var rows: [LPLTargetRow] = LPLTarget.rows.enumerated().map { index, target in
        LPLTargetRow(target: target, area: nil, areaOrder: nil, bank: nil, group: nil, position: nil, libraryOrder: Int.max, fallbackOrder: index)
    }
    @Published var sortMode: TargetsSortMode = .location {
        didSet { applySortAndFilter() }
    }
    @Published var selectedBank: Int? {
        didSet { applySortAndFilter() }
    }
    @Published var errorMessage: String?

    private var didLoad = false
    private var allRows: [LPLTargetRow] = LPLTarget.rows.enumerated().map { index, target in
        LPLTargetRow(target: target, area: nil, areaOrder: nil, bank: nil, group: nil, position: nil, libraryOrder: Int.max, fallbackOrder: index)
    }

    var bankOptions: [Int] {
        Array(Set(allRows.compactMap(\.bank))).sorted()
    }

    var selectedBankLabel: String {
        selectedBank.map { "Bank: \($0)" } ?? "Bank: All"
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadResolvedTargets()
    }

    private func loadResolvedTargets() async {
        do {
            let cached = try await PinballDataCache.shared.loadText(path: PracticeStore.resolvedLeagueTargetsPath, allowMissing: true)
            guard let text = cached.text, !text.isEmpty else {
                allRows = Self.fallbackRows()
                applySortAndFilter()
                errorMessage = nil
                return
            }

            let resolvedRows = parseResolvedLeagueTargets(text: text)
            guard !resolvedRows.isEmpty else {
                allRows = Self.fallbackRows()
                applySortAndFilter()
                errorMessage = nil
                return
            }

            allRows = resolvedRows.enumerated().map { fallbackIndex, row in
                LPLTargetRow(
                    target: .init(
                        game: row.game,
                        great: row.secondHighestAvg,
                        main: row.fourthHighestAvg,
                        floor: row.eighthHighestAvg
                    ),
                    area: row.area,
                    areaOrder: row.areaOrder,
                    bank: row.bank,
                    group: row.group,
                    position: row.position,
                    libraryOrder: row.order,
                    fallbackOrder: fallbackIndex
                )
            }
            applySortAndFilter()
            errorMessage = nil
        } catch {
            allRows = Self.fallbackRows()
            applySortAndFilter()
            errorMessage = "Using bundled target order (resolved targets unavailable: \(error.localizedDescription))."
        }
    }

    private static func fallbackRows() -> [LPLTargetRow] {
        LPLTarget.rows.enumerated().map { fallbackIndex, target in
            LPLTargetRow(target: target, area: nil, areaOrder: nil, bank: nil, group: nil, position: nil, libraryOrder: Int.max, fallbackOrder: fallbackIndex)
        }
    }

    private func applySortAndFilter() {
        let sortedRows: [LPLTargetRow] = switch sortMode {
        case .location:
            allRows.sorted {
                byOptionalAscending($0.areaOrder, $1.areaOrder)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.position, $1.position)
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        case .bank:
            allRows.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.position, $1.position)
                    ?? byAscending($0.target.game.lowercased(), $1.target.game.lowercased())
                    ?? byAscending($0.libraryOrder, $1.libraryOrder)
                    ?? byAscending($0.fallbackOrder, $1.fallbackOrder)
                    ?? false
            }
        case .alphabetical:
            allRows.sorted {
                byAscending($0.target.game.lowercased(), $1.target.game.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.position, $1.position)
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
}
