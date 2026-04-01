import Foundation
import Combine

@MainActor
final class StandingsViewModel: ObservableObject {
    @Published private(set) var rows: [StandingsCSVRow] = []
    @Published var selectedSeason: Int?
    @Published var errorMessage: String?
    @Published var dataUpdatedAt: Date?
    @Published var isRefreshing: Bool = false
    @Published var hasNewerData: Bool = false

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

    var updatedAtLabel: String? {
        guard let dataUpdatedAt else { return nil }
        return Self.updatedAtFormatter.string(from: dataUpdatedAt)
    }

    var standings: [Standing] {
        guard let selectedSeason else { return [] }

        let seasonRows = rows.filter { $0.season == selectedSeason }
        guard !seasonRows.isEmpty else { return [] }

        let mapped = seasonRows.map {
            Standing(
                id: $0.player,
                rawPlayer: $0.player,
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
            return mapped.sorted { (rankByPlayer[$0.rawPlayer] ?? Int.max) < (rankByPlayer[$1.rawPlayer] ?? Int.max) }
        }

        return mapped.sorted { $0.seasonTotal > $1.seasonTotal }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        isRefreshing = true
        defer { isRefreshing = false }
        await loadCSV(forceRefresh: false)
    }

    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadCSV(forceRefresh: true)
    }

    func reloadFromCache() async {
        if !didLoad {
            await loadIfNeeded()
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadCSV(forceRefresh: false)
    }

    private func loadCSV(forceRefresh: Bool) async {
        do {
            let cached: CachedTextResult
            if forceRefresh {
                cached = try await PinballDataCache.shared.forceRefreshText(path: StandingsCSVLoader.defaultPath)
            } else {
                cached = try await PinballDataCache.shared.loadText(path: StandingsCSVLoader.defaultPath)
            }
            guard let text = cached.text else {
                throw StandingsCSVError.network("Standings data is missing from cache and server.")
            }
            rows = try StandingsCSVLoader.parse(text: text)
            dataUpdatedAt = cached.updatedAt
            errorMessage = nil
            if forceRefresh {
                hasNewerData = false
                notifyLeaguePreviewNeedsRefresh()
            }
            Task { await refreshUpdateIndicator() }

            if let selectedSeason, seasons.contains(selectedSeason) {
                self.selectedSeason = selectedSeason
            } else {
                self.selectedSeason = seasons.last
            }
        } catch {
            rows = []
            dataUpdatedAt = nil
            hasNewerData = false
            errorMessage = error.localizedDescription
        }
    }

    private func refreshUpdateIndicator() async {
        guard dataUpdatedAt != nil else {
            hasNewerData = false
            return
        }

        let remoteHasNewer: Bool
        do {
            remoteHasNewer = try await PinballDataCache.shared.hasRemoteUpdate(path: StandingsCSVLoader.defaultPath)
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
}
