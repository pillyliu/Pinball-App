import Foundation

nonisolated enum ScoreParsingService {
    nonisolated static func rankedCandidates(from observations: [ScoreOCRObservation]) -> [ScoreScannerCandidate] {
        var seen = Set<Int>()

        return observations
            .compactMap(candidate(from:))
            .sorted(by: candidateSort)
            .filter { candidate in
                seen.insert(candidate.normalizedScore).inserted
            }
    }

    nonisolated static func normalizedScore(fromManualInput raw: String) -> Int? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty, let score = Int(digits), score > 0 else { return nil }
        return score
    }

    nonisolated static func formattedScore(score: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: score)) ?? String(score)
    }

    nonisolated static func formattedScoreInput(from raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard let value = Int(digits), value > 0 else { return digits.isEmpty ? "" : digits }
        return formattedScore(score: value)
    }
}
