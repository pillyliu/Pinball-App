import Foundation

struct VideoLogDraft {
    let kind: VideoProgressInputKind
    let progressPercent: Int
    let value: String
}

func practiceVideoSourceOptions(game: PinballGame?, task: StudyTaskKind) -> [String] {
    let prefix: String
    switch task {
    case .tutorialVideo:
        prefix = "Tutorial"
    case .gameplayVideo:
        prefix = "Gameplay"
    default:
        return []
    }

    let normalizedPrefix = prefix.lowercased()
    let matches = game?.videos.filter { video in
        video.kind?.lowercased().contains(normalizedPrefix) == true ||
            video.label?.localizedCaseInsensitiveContains(prefix) == true
    } ?? []

    if matches.isEmpty {
        return ["\(prefix) -"]
    }

    return matches.indices.map { "\(prefix) \($0 + 1)" }
}

func buildVideoLogDraft(
    inputKind: VideoProgressInputKind,
    sourceLabel: String,
    watchedTime: String,
    totalTime: String,
    percentValue: Double
) -> VideoLogDraft? {
    let source = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    if source.isEmpty {
        return nil
    }

    switch inputKind {
    case .clock:
        let watched = parseHhMmSs(watchedTime)
        let total = parseHhMmSs(totalTime)
        if watched == nil && total == nil {
            return VideoLogDraft(kind: .clock, progressPercent: 100, value: "\(source) • 100%")
        }
        guard let watched, let total, total > 0, watched <= total else {
            return nil
        }
        let percent = Int((Double(watched) / Double(total) * 100.0).rounded()).clamped(to: 0...100)
        let value = "\(source) • \(formatHhMmSs(seconds: watched))/\(formatHhMmSs(seconds: total)) (\(percent)%)"
        return VideoLogDraft(kind: .clock, progressPercent: percent, value: value)
    case .percent:
        let percent = Int(percentValue.rounded()).clamped(to: 0...100)
        return VideoLogDraft(kind: .percent, progressPercent: percent, value: "\(source) • \(percent)%")
    }
}

private func parseHhMmSs(_ raw: String) -> Int? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let match = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2}):(\d{2})$"#)
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
    guard
        let result = match?.firstMatch(in: trimmed, options: [], range: range),
        result.numberOfRanges == 4,
        let hourRange = Range(result.range(at: 1), in: trimmed),
        let minuteRange = Range(result.range(at: 2), in: trimmed),
        let secondRange = Range(result.range(at: 3), in: trimmed),
        let hours = Int(trimmed[hourRange]),
        let minutes = Int(trimmed[minuteRange]),
        let seconds = Int(trimmed[secondRange]),
        (0...59).contains(minutes),
        (0...59).contains(seconds)
    else {
        return nil
    }

    return (hours * 3600) + (minutes * 60) + seconds
}

private func formatHhMmSs(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainder = seconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
