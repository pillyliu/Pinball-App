import Foundation
import CoreGraphics

enum ScoreParsingService {
    nonisolated static func rankedCandidates(from observations: [ScoreOCRObservation]) -> [ScoreScannerCandidate] {
        var seen = Set<Int>()

        return observations
            .compactMap(candidate(from:))
            .sorted(by: candidateSort)
            .filter { candidate in
                seen.insert(candidate.normalizedScore).inserted
            }
    }

    nonisolated static func bestCandidate(from observations: [ScoreOCRObservation]) -> ScoreScannerCandidate? {
        rankedCandidates(from: observations).first
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

    nonisolated private static func candidate(from observation: ScoreOCRObservation) -> ScoreScannerCandidate? {
        guard let normalized = normalizeOCRText(observation.text) else { return nil }
        let centerX = observation.boundingBox.midX
        let centerY = observation.boundingBox.midY
        let distance = hypot(centerX - 0.5, centerY - 0.5)
        let maxDistance = hypot(0.5, 0.5)
        let centerBias = max(0, 1 - (distance / maxDistance))

        return ScoreScannerCandidate(
            rawText: observation.text,
            normalizedScore: normalized.score,
            formattedScore: formattedScore(score: normalized.score),
            confidence: observation.confidence,
            boundingBox: observation.boundingBox,
            digitCount: normalized.digitCount,
            centerBias: centerBias
        )
    }

    nonisolated private static func candidateSort(lhs: ScoreScannerCandidate, rhs: ScoreScannerCandidate) -> Bool {
        if abs(lhs.centerBias - rhs.centerBias) > 0.001 {
            return lhs.centerBias > rhs.centerBias
        }
        if lhs.digitCount != rhs.digitCount {
            return lhs.digitCount > rhs.digitCount
        }
        return lhs.confidence > rhs.confidence
    }

    nonisolated private static func normalizeOCRText(_ raw: String) -> (score: Int, digitCount: Int)? {
        let strippedWhitespace = raw.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !strippedWhitespace.isEmpty else { return nil }

        var mapped = ""
        for character in strippedWhitespace {
            switch character {
            case "O", "o":
                mapped.append("0")
            case "I", "l":
                mapped.append("1")
            case "S":
                mapped.append("5")
            default:
                mapped.append(character)
            }
        }

        let unsupportedLetters = mapped.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
        }
        guard !unsupportedLetters else { return nil }

        let filtered = mapped.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "'" }
        let digits = filtered.filter(\.isNumber)

        guard !digits.isEmpty, digits.count <= 15, let score = Int(digits), score > 0 else {
            return nil
        }

        return (score, digits.count)
    }
}
