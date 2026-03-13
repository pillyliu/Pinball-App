import Foundation

nonisolated final class ScoreStabilityService {
    struct Configuration {
        var maxRecentReadings = 6
        var requiredMatches = 3
        var minimumAverageConfidence: Float = 0.38
        var failedAfterMisses = 5
    }

    struct Reading: Equatable {
        let score: Int
        let formattedScore: String
        let rawText: String
        let digitCount: Int
        let confidence: Float
        let timestamp: Date
    }

    struct Snapshot: Equatable {
        let state: ScoreScannerStatus
        let dominantReading: Reading?
        let occurrences: Int
        let averageConfidence: Float
    }

    private let configuration: Configuration
    private var recentReadings: [Reading] = []
    private var consecutiveMisses = 0

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func reset() {
        recentReadings.removeAll()
        consecutiveMisses = 0
    }

    func ingest(candidate: ScoreScannerCandidate?) -> Snapshot {
        if let candidate {
            consecutiveMisses = 0
            recentReadings.append(
                Reading(
                    score: candidate.normalizedScore,
                    formattedScore: candidate.formattedScore,
                    rawText: candidate.rawText,
                    digitCount: candidate.digitCount,
                    confidence: candidate.confidence,
                    timestamp: Date()
                )
            )
            if recentReadings.count > configuration.maxRecentReadings {
                recentReadings.removeFirst(recentReadings.count - configuration.maxRecentReadings)
            }
        } else {
            consecutiveMisses += 1
            if consecutiveMisses >= configuration.failedAfterMisses {
                recentReadings.removeAll()
                return Snapshot(state: .failedNoReading, dominantReading: nil, occurrences: 0, averageConfidence: 0)
            }
        }

        guard let dominant = dominantConsensus() else {
            return Snapshot(
                state: consecutiveMisses > 0 ? .failedNoReading : .searching,
                dominantReading: nil,
                occurrences: 0,
                averageConfidence: 0
            )
        }

        if dominant.occurrences >= configuration.requiredMatches,
           dominant.averageConfidence >= configuration.minimumAverageConfidence {
            return Snapshot(
                state: .locked,
                dominantReading: dominant.reading,
                occurrences: dominant.occurrences,
                averageConfidence: dominant.averageConfidence
            )
        }

        if dominant.occurrences >= max(2, configuration.requiredMatches - 1) {
            return Snapshot(
                state: .stableCandidate,
                dominantReading: dominant.reading,
                occurrences: dominant.occurrences,
                averageConfidence: dominant.averageConfidence
            )
        }

        return Snapshot(
            state: .reading,
            dominantReading: dominant.reading,
            occurrences: dominant.occurrences,
            averageConfidence: dominant.averageConfidence
        )
    }

    private func dominantConsensus() -> (reading: Reading, occurrences: Int, averageConfidence: Float)? {
        let grouped = Dictionary(grouping: recentReadings, by: \.score)
        let ranked = grouped.values.compactMap { bucket -> (Reading, Int, Float)? in
            guard let best = bucket.sorted(by: { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return lhs.confidence > rhs.confidence
                }
                return lhs.timestamp > rhs.timestamp
            }).first else {
                return nil
            }
            let average = bucket.map(\.confidence).reduce(0, +) / Float(bucket.count)
            return (best, bucket.count, average)
        }

        return ranked.sorted { lhs, rhs in
            if abs(lhs.1 - rhs.1) >= 2 { return lhs.1 > rhs.1 }
            if lhs.0.digitCount != rhs.0.digitCount { return lhs.0.digitCount > rhs.0.digitCount }
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            return lhs.0.timestamp > rhs.0.timestamp
        }.first
    }
}
