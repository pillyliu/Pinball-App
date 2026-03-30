import Foundation
import CoreGraphics

private struct NormalizedScore {
    let score: Int
    let digitCount: Int
    let formatQuality: Int
    let rawRun: String
}

private struct RescueVariant {
    let run: String
    let qualityAdjustment: Int
}

extension ScoreParsingService {
    nonisolated static func candidate(from observation: ScoreOCRObservation) -> ScoreScannerCandidate? {
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
            centerBias: centerBias,
            formatQuality: normalized.formatQuality
        )
    }

    nonisolated static func candidateSort(lhs: ScoreScannerCandidate, rhs: ScoreScannerCandidate) -> Bool {
        if lhs.normalizedScore == rhs.normalizedScore,
           lhs.formatQuality != rhs.formatQuality {
            return lhs.formatQuality > rhs.formatQuality
        }
        if abs(lhs.digitCount - rhs.digitCount) >= 3 {
            return lhs.digitCount > rhs.digitCount
        }
        if lhs.formatQuality != rhs.formatQuality {
            return lhs.formatQuality > rhs.formatQuality
        }
        if lhs.digitCount != rhs.digitCount {
            return lhs.digitCount > rhs.digitCount
        }
        if abs(lhs.centerBias - rhs.centerBias) > 0.001 {
            return lhs.centerBias > rhs.centerBias
        }
        return lhs.confidence > rhs.confidence
    }

    nonisolated private static func normalizeOCRText(_ raw: String) -> NormalizedScore? {
        let strippedWhitespace = raw.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !strippedWhitespace.isEmpty else { return nil }

        let mapped = normalizedDigitLikeText(from: strippedWhitespace)
        let normalizedRuns = digitLikeRuns(in: mapped).flatMap(normalizedRunCandidates(from:))
        return normalizedRuns.sorted(by: normalizedRunSort).first
    }

    nonisolated private static func normalizedDigitLikeText(from raw: String) -> String {
        let characters = Array(raw)
        var mapped = ""
        mapped.reserveCapacity(characters.count)

        for index in characters.indices {
            let previous = index == characters.startIndex ? nil : characters[characters.index(before: index)]
            let next = index == characters.index(before: characters.endIndex) ? nil : characters[characters.index(after: index)]
            mapped.append(mappedDigit(for: characters[index], previous: previous, next: next) ?? characters[index])
        }

        return mapped
    }

    nonisolated private static func mappedDigit(
        for character: Character,
        previous: Character?,
        next: Character?
    ) -> Character? {
        switch character {
        case "O", "o":
            return "0"
        case "I", "l", "L", "|", "!":
            return "1"
        case "S", "s":
            return "5"
        case "b", "G", "Z", "z", "q", "Q":
            guard hasNumericContext(previous: previous, next: next) else { return nil }
            switch character {
            case "b", "G":
                return "6"
            case "Z", "z":
                return "2"
            case "q", "Q":
                return "9"
            default:
                return nil
            }
        default:
            return nil
        }
    }

    nonisolated private static func hasNumericContext(previous: Character?, next: Character?) -> Bool {
        isDigitLikeContext(previous) || isDigitLikeContext(next)
    }

    nonisolated private static func isDigitLikeContext(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isNumber || character == "," || character == "." || character == "'" || mappedDigit(for: character, previous: nil, next: nil) != nil
    }

    nonisolated private static func digitLikeRuns(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""

        for character in text {
            if character.isNumber || character == "," || character == "." || character == "'" {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }

        if !current.isEmpty {
            runs.append(current)
        }

        return runs
    }

    nonisolated private static func normalizedRunCandidates(from run: String) -> [NormalizedScore] {
        var candidates: [NormalizedScore] = []
        if let normalized = normalizedRun(from: run) {
            candidates.append(normalized)
        }
        let groupedVariants = zeroConfusionGroupedRescueVariants(for: run)

        appendRescuedCandidates(into: &candidates, from: groupedVariants)
        appendRescuedCandidates(into: &candidates, from: missingLeadingDigitRescueVariants(for: run))
        appendRescuedCandidates(into: &candidates, from: leadingDigitRescueVariants(for: run))

        for groupedVariant in groupedVariants {
            appendRescuedCandidates(
                into: &candidates,
                from: missingLeadingDigitRescueVariants(for: groupedVariant.run),
                additionalQualityAdjustment: groupedVariant.qualityAdjustment
            )
            appendRescuedCandidates(
                into: &candidates,
                from: leadingDigitRescueVariants(for: groupedVariant.run),
                additionalQualityAdjustment: groupedVariant.qualityAdjustment
            )
        }

        return candidates
    }

    nonisolated private static func appendRescuedCandidates(
        into candidates: inout [NormalizedScore],
        from variants: [RescueVariant],
        additionalQualityAdjustment: Int = 0
    ) {
        for variant in variants {
            guard let normalized = normalizedRun(from: variant.run) else { continue }
            candidates.append(
                NormalizedScore(
                    score: normalized.score,
                    digitCount: normalized.digitCount,
                    formatQuality: normalized.formatQuality + variant.qualityAdjustment + additionalQualityAdjustment,
                    rawRun: normalized.rawRun
                )
            )
        }
    }

    nonisolated private static func normalizedRun(from run: String) -> NormalizedScore? {
        let digits = run.filter(\.isNumber)
        let leadingZeroCount = digits.prefix(while: { $0 == "0" }).count
        guard !digits.isEmpty,
              digits.count <= 15,
              let score = Int(digits),
              score > 0 else {
            return nil
        }

        return NormalizedScore(
            score: score,
            digitCount: digits.count,
            formatQuality: formatQuality(for: run, leadingZeroCount: leadingZeroCount),
            rawRun: run
        )
    }

    nonisolated private static func missingLeadingDigitRescueVariants(for run: String) -> [RescueVariant] {
        guard run.first.map(isSeparator) == true else { return [] }
        let digits = run.filter(\.isNumber)
        guard digits.count >= 6 else { return [] }

        let groups = run.split(separator: ",", omittingEmptySubsequences: false)
            .flatMap { segment in segment.split(separator: ".", omittingEmptySubsequences: false) }
            .flatMap { segment in segment.split(separator: "'", omittingEmptySubsequences: false) }
            .map(String.init)
        guard groups.count > 2,
              groups.first?.isEmpty == true,
              groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return [] }

        func prependingLeadingDigit(_ replacement: Character, adjustment: Int) -> RescueVariant {
            RescueVariant(run: String(replacement) + run, qualityAdjustment: adjustment)
        }

        let preferEight = digits.filter { $0 == "0" }.count >= 3
        if preferEight {
            return [
                prependingLeadingDigit("8", adjustment: -1),
                prependingLeadingDigit("6", adjustment: -2),
                prependingLeadingDigit("7", adjustment: -3)
            ]
        }
        return [
            prependingLeadingDigit("6", adjustment: -1),
            prependingLeadingDigit("8", adjustment: -2),
            prependingLeadingDigit("7", adjustment: -3)
        ]
    }

    nonisolated private static func zeroConfusionGroupedRescueVariants(for run: String) -> [RescueVariant] {
        let separatorKinds = Set(run.filter(isSeparator))
        guard separatorKinds.count == 1, let separator = separatorKinds.first else { return [] }

        let groups = run.split(
            omittingEmptySubsequences: false,
            whereSeparator: isSeparator
        ).map(String.init)
        guard groups.count > 1 else { return [] }

        let leadingGroupLength = groups.first?.count ?? 0
        guard (0...3).contains(leadingGroupLength) else { return [] }
        guard groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return [] }

        let digits = run.filter(\.isNumber)
        let zeroCount = digits.filter { $0 == "0" }.count
        guard digits.count >= 7, zeroCount >= 3 else { return [] }
        let prefersAggressiveZeroRescue = zeroCount >= 5

        struct GroupOption {
            let group: String
            let qualityAdjustment: Int
            let changed: Bool
        }

        func replacementAdjustment(
            groupIndex: Int,
            position: Int,
            replacement: Character,
            groupLength: Int
        ) -> Int {
            let isLastThreeDigitGroup = groupLength == 3 && groupIndex == groups.index(before: groups.endIndex)

            switch (groupLength, prefersAggressiveZeroRescue, position, isLastThreeDigitGroup, replacement) {
            case (1, true, _, _, _):
                return -1
            case (1, false, _, _, _):
                return -2
            case (_, true, 1, true, "6"):
                return -1
            case (_, true, 1, true, _):
                return -2
            case (_, true, 1, _, "8"):
                return -1
            case (_, true, 1, _, _):
                return -2
            case (_, true, _, _, _):
                return -2
            case (_, false, 1, true, "6"):
                return -4
            case (_, false, 1, _, "8"):
                return -4
            case (_, false, 1, _, _):
                return -5
            default:
                return -5
            }
        }

        let perGroupOptions: [[GroupOption]] = groups.enumerated().map { groupIndex, group in
            var options = [
                GroupOption(group: group, qualityAdjustment: 0, changed: false)
            ]
            guard !group.isEmpty else { return options }

            let characters = Array(group)
            for index in characters.indices where characters[index] == "0" {
                let isLeadingSingleDigitGroup = groupIndex == 0 && group.count == 1
                let isThreeDigitGroup = group.count == 3
                guard isLeadingSingleDigitGroup || isThreeDigitGroup else { continue }

                for replacement: Character in ["8", "6"] {
                    var mutatedCharacters = characters
                    mutatedCharacters[index] = replacement
                    options.append(
                        GroupOption(
                            group: String(mutatedCharacters),
                            qualityAdjustment: replacementAdjustment(
                                groupIndex: groupIndex,
                                position: index,
                                replacement: replacement,
                                groupLength: group.count
                            ),
                            changed: true
                        )
                    )
                }
            }

            return options
        }

        var variants: [String: Int] = [:]
        let maximumVariantCount = 96

        func buildVariants(
            groupIndex: Int,
            builtGroups: inout [String],
            totalAdjustment: Int,
            changedGroups: Int
        ) {
            if variants.count >= maximumVariantCount {
                return
            }

            if groupIndex == perGroupOptions.count {
                guard changedGroups > 0 else { return }
                let variantRun = builtGroups.joined(separator: String(separator))
                if let existing = variants[variantRun], totalAdjustment <= existing {
                    return
                } else {
                    variants[variantRun] = totalAdjustment
                }
                return
            }

            for option in perGroupOptions[groupIndex] {
                let nextChangedGroups = changedGroups + (option.changed ? 1 : 0)
                guard nextChangedGroups <= 3 else { continue }

                builtGroups.append(option.group)
                buildVariants(
                    groupIndex: groupIndex + 1,
                    builtGroups: &builtGroups,
                    totalAdjustment: totalAdjustment + option.qualityAdjustment,
                    changedGroups: nextChangedGroups
                )
                builtGroups.removeLast()
            }
        }

        var builtGroups: [String] = []
        buildVariants(groupIndex: 0, builtGroups: &builtGroups, totalAdjustment: 0, changedGroups: 0)

        return variants.map { entry in
            let (run, qualityAdjustment) = entry
            return RescueVariant(run: run, qualityAdjustment: qualityAdjustment)
        }
    }

    nonisolated private static func leadingDigitRescueVariants(for run: String) -> [RescueVariant] {
        let digits = run.filter(\.isNumber)
        guard digits.count >= 7 else { return [] }
        let groups = run.split(whereSeparator: isSeparator)
        guard groups.count > 1,
              (1...3).contains(groups.first?.count ?? 0),
              groups.dropFirst().allSatisfy({ $0.count == 3 }),
              let leadingCharacter = run.first else { return [] }

        func replacingLeadingDigit(with replacement: Character, adjustment: Int) -> RescueVariant {
            var characters = Array(run)
            characters[0] = replacement
            return RescueVariant(run: String(characters), qualityAdjustment: adjustment)
        }

        switch leadingCharacter {
        case "0":
            let preferEight = digits.filter { $0 == "0" }.count >= 4
            if preferEight {
                return [
                    replacingLeadingDigit(with: "8", adjustment: -1),
                    replacingLeadingDigit(with: "6", adjustment: -2)
                ]
            }
            return [
                replacingLeadingDigit(with: "6", adjustment: -1),
                replacingLeadingDigit(with: "8", adjustment: -2)
            ]
        case "1":
            guard run.contains("."), digits.filter({ $0 == "0" }).count >= 2 else { return [] }
            return [replacingLeadingDigit(with: "7", adjustment: -1)]
        default:
            return []
        }
    }

    nonisolated private static func normalizedRunSort(lhs: NormalizedScore, rhs: NormalizedScore) -> Bool {
        if lhs.digitCount != rhs.digitCount {
            return lhs.digitCount > rhs.digitCount
        }
        if lhs.formatQuality != rhs.formatQuality {
            return lhs.formatQuality > rhs.formatQuality
        }
        if lhs.rawRun.count != rhs.rawRun.count {
            return lhs.rawRun.count > rhs.rawRun.count
        }
        return lhs.rawRun > rhs.rawRun
    }

    nonisolated private static func formatQuality(for run: String, leadingZeroCount: Int) -> Int {
        let separators = run.filter(isSeparator)
        let separatorKinds = Set(separators)
        let groups = run.split(whereSeparator: isSeparator).map(String.init)
        let digits = run.filter(\.isNumber)
        let zeroCount = digits.filter { $0 == "0" }.count
        let hasMixedSeparators = separatorKinds.count > 1
        let hasRepeatedSeparators = containsAdjacentSeparators(in: run)
        let hasEdgeSeparator = run.first.map(isSeparator) == true || run.last.map(isSeparator) == true
        let usesValidThousandsGrouping =
            !separators.isEmpty &&
            separatorKinds.count == 1 &&
            groups.count > 1 &&
            (1...3).contains(groups.first?.count ?? 0) &&
            groups.dropFirst().allSatisfy { $0.count == 3 }

        var quality = 0
        if separators.isEmpty {
            quality += 2
        }
        if usesValidThousandsGrouping {
            quality += 6
        } else if !separators.isEmpty {
            quality -= 2
        }
        if hasMixedSeparators {
            quality -= 5
        } else if !separators.isEmpty {
            quality += 1
        }
        if leadingZeroCount > 0 {
            quality -= min(6, leadingZeroCount * 2)
        } else {
            quality += 2
        }
        if hasRepeatedSeparators {
            quality -= 3
        }
        if hasEdgeSeparator {
            quality -= 2
        }
        if usesValidThousandsGrouping,
           let leadingGroup = groups.first,
           leadingGroup.count == 1 {
            if leadingGroup == "0" {
                quality -= 6
            } else if leadingGroup == "1" && run.contains(".") && zeroCount >= 2 {
                quality -= 1
            }
        }
        if digits.count >= 7 && zeroCount >= 5 {
            quality -= 4
        } else if digits.count >= 7 && zeroCount == 4 {
            quality -= 2
        }
        return quality
    }

    nonisolated private static func isSeparator(_ character: Character) -> Bool {
        character == "," || character == "." || character == "'"
    }

    nonisolated private static func containsAdjacentSeparators(in run: String) -> Bool {
        var previousWasSeparator = false
        for character in run {
            if isSeparator(character) {
                if previousWasSeparator {
                    return true
                }
                previousWasSeparator = true
            } else {
                previousWasSeparator = false
            }
        }
        return false
    }
}
