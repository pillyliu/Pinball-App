import Foundation
import Combine

@MainActor
final class LeaguePreviewRotationState: ObservableObject {
    @Published private(set) var targetMetricIndex: Int = 0
    @Published private(set) var standingsModeIndex: Int = 0
    @Published private(set) var statsValueIndex: Int = 0

    private var cancellables: Set<AnyCancellable> = []

    init() {
        Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                targetMetricIndex = (targetMetricIndex + 1) % LeagueTargetMetric.allCases.count
            }
            .store(in: &cancellables)

        Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                standingsModeIndex = (standingsModeIndex + 1) % LeagueStandingsPreviewMode.allCases.count
            }
            .store(in: &cancellables)

        Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                statsValueIndex = (statsValueIndex + 1) % 2
            }
            .store(in: &cancellables)
    }

    var targetMetric: LeagueTargetMetric {
        LeagueTargetMetric.allCases[targetMetricIndex]
    }

    func standingsMode(hasAroundYouStandings: Bool) -> LeagueStandingsPreviewMode {
        guard hasAroundYouStandings else { return .topFive }
        return LeagueStandingsPreviewMode.allCases[standingsModeIndex]
    }

    var showStatsScore: Bool {
        statsValueIndex == 0
    }
}
