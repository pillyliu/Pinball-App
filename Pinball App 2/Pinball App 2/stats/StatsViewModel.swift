import Combine
import Foundation

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var rows: [ScoreRow] = []
    @Published var errorMessage: String?
    @Published var dataUpdatedAt: Date?
    @Published var isRefreshing: Bool = false
    @Published var hasNewerData: Bool = false
    private var didLoad = false

    @Published var season: String = ""
    @Published var player: String = ""
    @Published var bankNumber: Int?
    @Published var machine: String = ""

    func selectSeason(_ newSeason: String) {
        season = newSeason
        reconcileSeasonScopedSelections()
    }

    func selectPlayer(_ newPlayer: String) {
        player = newPlayer
        reconcilePlayerScopedSelections()
    }

    func selectBankNumber(_ newBankNumber: Int?) {
        bankNumber = newBankNumber
        reconcileBankScopedSelections()
    }

    func selectMachine(_ newMachine: String) {
        machine = newMachine
    }

    func clearAllFilters() {
        season = ""
        player = ""
        bankNumber = nil
        machine = ""
    }

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

    var updatedAtLabel: String? {
        guard let dataUpdatedAt else { return nil }
        return Self.updatedAtFormatter.string(from: dataUpdatedAt)
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        isRefreshing = true
        defer { isRefreshing = false }
        await loadCSV(resetSelection: true)
    }

    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let loaded = try await StatsCSVLoader().forceRefreshRows()
            applyLoadedRows(loaded, resetSelection: false)
            errorMessage = nil
            hasNewerData = false
            notifyLeaguePreviewNeedsRefresh()
            Task { await refreshUpdateIndicator() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadFromCache() async {
        if !didLoad {
            await loadIfNeeded()
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadCSV(resetSelection: false)
    }

    private func loadCSV(resetSelection: Bool) async {
        do {
            let loaded = try await StatsCSVLoader().loadRows()
            applyLoadedRows(loaded, resetSelection: resetSelection)
            errorMessage = nil
            Task { await refreshUpdateIndicator() }
        } catch {
            rows = []
            dataUpdatedAt = nil
            hasNewerData = false
            errorMessage = error.localizedDescription
        }
    }

    private func applyLoadedRows(_ loaded: StatsCSVLoader.LoadResult, resetSelection: Bool) {
        rows = loaded.rows
        dataUpdatedAt = loaded.updatedAt
        if resetSelection {
            season = latestSeason(in: loaded.rows) ?? ""
            player = ""
            bankNumber = nil
            machine = ""
            return
        }

        if !season.isEmpty, !seasons.contains(season) {
            season = latestSeason(in: loaded.rows) ?? ""
        }
        reconcileSeasonScopedSelections()
    }

    private func reconcileSeasonScopedSelections() {
        if !player.isEmpty, !hasRows(season: season, player: player) {
            player = ""
        }
        if let bankNumber, !hasRows(season: season, player: player, bankNumber: bankNumber) {
            self.bankNumber = nil
        }
        reconcileBankScopedSelections()
    }

    private func reconcilePlayerScopedSelections() {
        if let bankNumber, !hasRows(season: season, player: player, bankNumber: bankNumber) {
            self.bankNumber = nil
        }
        reconcileBankScopedSelections()
    }

    private func reconcileBankScopedSelections() {
        if let bankNumber, !player.isEmpty, !hasRows(season: season, player: player, bankNumber: bankNumber) {
            player = ""
        }
        if !machine.isEmpty, !hasRows(season: season, player: player, bankNumber: bankNumber, machine: machine) {
            machine = ""
        }
    }

    private func hasRows(
        season: String,
        player: String = "",
        bankNumber: Int? = nil,
        machine: String = ""
    ) -> Bool {
        rows.contains { row in
            (season.isEmpty || row.season == season) &&
            (player.isEmpty || row.player == player) &&
            (bankNumber == nil || row.bankNumber == bankNumber) &&
            (machine.isEmpty || row.machine == machine)
        }
    }

    private func refreshUpdateIndicator() async {
        guard dataUpdatedAt != nil else {
            hasNewerData = false
            return
        }

        let remoteHasNewer: Bool
        do {
            remoteHasNewer = try await PinballDataCache.shared.hasRemoteUpdate(path: StatsCSVLoader.defaultPath)
        } catch {
            remoteHasNewer = false
        }

        hasNewerData = remoteHasNewer
    }

    private static let updatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter
    }()

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

    private func playerLabel(for row: ScoreRow, isBankScope: Bool) -> StatPlayerLabel {
        StatPlayerLabel(
            rawPlayer: row.player,
            season: isBankScope ? nil : abbreviatedStatsSeason(row.season)
        )
    }
}
