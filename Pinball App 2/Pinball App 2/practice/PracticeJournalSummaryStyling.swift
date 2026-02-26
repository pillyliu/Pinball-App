import SwiftUI

private enum PracticeJournalSummaryTokenColor {
    case primary
    case game
    case screen
    case score
    case note
}

private struct PracticeJournalSummaryToken {
    let text: String
    let color: PracticeJournalSummaryTokenColor
}

func styledPracticeJournalSummary(_ summary: String) -> Text {
    let tokens = practiceJournalSummaryTokens(summary)
    return tokens.reduce(Text("")) { partial, token in
        let segment = Text(token.text)
            .foregroundStyle(colorForPracticeJournalToken(token.color))
        switch token.color {
        case .primary:
            return partial + segment
        case .game, .screen, .score:
            return partial + segment.bold()
        case .note:
            return partial + segment
        }
    }
}

private func colorForPracticeJournalToken(_ token: PracticeJournalSummaryTokenColor) -> Color {
    let game = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.48, green: 0.93, blue: 0.96, alpha: 1) : UIColor(red: 0.04, green: 0.43, blue: 0.38, alpha: 1)
    })
    let screen = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.69, green: 0.82, blue: 0.99, alpha: 1) : UIColor(red: 0.10, green: 0.26, blue: 0.78, alpha: 1)
    })
    let score = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.99, green: 0.82, blue: 0.24, alpha: 1) : UIColor(red: 0.61, green: 0.29, blue: 0.03, alpha: 1)
    })
    let note = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1) : UIColor(red: 0.23, green: 0.28, blue: 0.37, alpha: 1)
    })
    switch token {
    case .primary: return .primary
    case .game: return game
    case .screen: return screen
    case .score: return score
    case .note: return note
    }
}

private func practiceJournalSummaryTokens(_ summary: String) -> [PracticeJournalSummaryToken] {
    if let score = parseScoreSummary(summary) {
        return [
            .init(text: "Score: ", color: .primary),
            .init(text: score.value, color: .score),
            .init(text: " • ", color: .primary),
            .init(text: score.game, color: .game),
            .init(text: " (\(score.context))", color: .screen),
        ]
    }

    if let practice = parseStructuredPracticeSummary(summary) {
        return practice
    }

    if let study = parseStructuredStudySummary(summary) {
        return study
    }

    if let gameNote = parseStructuredGameNoteSummary(summary) {
        return gameNote
    }

    if let bullet = parseBulletGameSummary(summary) {
        return [
            .init(text: bullet.prefix, color: .primary),
            .init(text: "\n• ", color: .screen),
            .init(text: bullet.game, color: .game),
        ]
    }

    if let lib = parseLibrarySummary(summary) {
        return lib
    }

    if let practicePlayfield = parsePracticePlayfieldSummary(summary) {
        return practicePlayfield
    }
    if let rulesheet = parsePracticeRulesheetSummary(summary) {
        return rulesheet
    }
    if let video = parsePracticeVideoSummary(summary) {
        return video
    }
    if let progress = parsePracticeProgressSummary(summary) {
        return progress
    }
    if let browsed = parsePracticeBrowsedSummary(summary) {
        return browsed
    }

    return [.init(text: summary, color: .primary)]
}

private func parseScoreSummary(_ summary: String) -> (value: String, game: String, context: String)? {
    guard summary.hasPrefix("Score: ") else { return nil }
    let rest = String(summary.dropFirst("Score: ".count))
    guard let bulletRange = rest.range(of: " • "),
          let contextStart = rest.lastIndex(of: "("),
          rest.hasSuffix(")"),
          contextStart > bulletRange.upperBound else { return nil }
    let value = String(rest[..<bulletRange.lowerBound])
    let gamePart = String(rest[bulletRange.upperBound..<contextStart]).trimmingCharacters(in: .whitespaces)
    let context = String(rest[rest.index(after: contextStart)..<rest.index(before: rest.endIndex)])
    guard !value.isEmpty, !gamePart.isEmpty, !context.isEmpty else { return nil }
    return (value, gamePart, context)
}

private func parseBulletGameSummary(_ summary: String) -> (prefix: String, game: String)? {
    guard let range = summary.range(of: "\n• ") else { return nil }
    let prefix = String(summary[..<range.lowerBound])
    let game = String(summary[range.upperBound...])
    guard !game.isEmpty else { return nil }
    return (prefix, game)
}

private func parseStructuredPracticeSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    guard summary.hasPrefix("Practice:\n"), let range = summary.range(of: "\n• ") else { return nil }
    let body = String(summary[summary.index(summary.startIndex, offsetBy: "Practice:\n".count)..<range.lowerBound])
    let game = String(summary[range.upperBound...])
    guard !game.isEmpty else { return nil }

    var lines = body.components(separatedBy: "\n")
    while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { lines.removeLast() }
    let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let valueLine = firstLine.isEmpty ? "Practice session" : firstLine
    let noteText = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

    var tokens: [PracticeJournalSummaryToken] = [
        .init(text: "Practice", color: .screen),
        .init(text: ":\n", color: .primary),
        .init(text: valueLine, color: .screen),
    ]
    if !noteText.isEmpty {
        tokens.append(.init(text: "\n", color: .primary))
        tokens.append(.init(text: noteText, color: .note))
    }
    tokens.append(.init(text: "\n• ", color: .screen))
    tokens.append(.init(text: game, color: .game))
    return tokens
}

private func parseStructuredGameNoteSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    guard summary.hasPrefix("Game Note:\n"), let range = summary.range(of: "\n• ") else { return nil }
    let note = String(summary[summary.index(summary.startIndex, offsetBy: "Game Note:\n".count)..<range.lowerBound])
    let game = String(summary[range.upperBound...])
    guard !game.isEmpty else { return nil }
    return [
        .init(text: "Game Note", color: .screen),
        .init(text: ":\n", color: .primary),
        .init(text: note, color: .note),
        .init(text: "\n• ", color: .screen),
        .init(text: game, color: .game),
    ]
}

private func parseStructuredStudySummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    let headers: [(label: String, titleToken: String)] = [
        ("Rulesheet", "Rulesheet"),
        ("Tutorial Video", "Tutorial Video"),
        ("Gameplay Video", "Gameplay Video"),
        ("Playfield", "Playfield")
    ]
    guard let header = headers.first(where: { summary.hasPrefix($0.label + ":\n") }),
          let range = summary.range(of: "\n• ")
    else { return nil }

    let body = String(summary[summary.index(summary.startIndex, offsetBy: header.label.count + 2)..<range.lowerBound])
    let game = String(summary[range.upperBound...])
    guard !game.isEmpty else { return nil }
    var lines = body.components(separatedBy: "\n")
    while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { lines.removeLast() }
    let valueLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let noteText = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !valueLine.isEmpty else { return nil }

    var tokens: [PracticeJournalSummaryToken] = [
        .init(text: header.titleToken, color: .screen),
        .init(text: ":\n", color: .primary)
    ]
    if let progress = valueLine.stripProgressPrefix() {
        tokens.append(.init(text: "Progress", color: .screen))
        tokens.append(.init(text: ": ", color: .primary))
        tokens.append(.init(text: progress, color: .screen))
    } else if valueLine.caseInsensitiveCompare("Viewed playfield") == .orderedSame {
        tokens.append(.init(text: "Viewed ", color: .primary))
        tokens.append(.init(text: "playfield", color: .screen))
    } else {
        tokens.append(.init(text: valueLine, color: .screen))
    }
    if !noteText.isEmpty {
        tokens.append(.init(text: "\n", color: .primary))
        tokens.append(.init(text: noteText, color: .note))
    }
    tokens.append(.init(text: "\n• ", color: .screen))
    tokens.append(.init(text: game, color: .game))
    return tokens
}

private func parseLibrarySummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    if summary.hasPrefix("Browsed "), summary.hasSuffix(" in Library") {
        let game = String(summary.dropFirst("Browsed ".count).dropLast(" in Library".count))
        return [
            .init(text: "Browsed ", color: .primary),
            .init(text: game, color: .game),
            .init(text: " in ", color: .primary),
            .init(text: "Library", color: .screen),
        ]
    }
    if summary.hasPrefix("Opened "), summary.hasSuffix(" rulesheet from Library") {
        let game = String(summary.dropFirst("Opened ".count).dropLast(" rulesheet from Library".count))
        return [
            .init(text: "Opened ", color: .primary),
            .init(text: game, color: .game),
            .init(text: " ", color: .primary),
            .init(text: "rulesheet", color: .screen),
            .init(text: " from ", color: .primary),
            .init(text: "Library", color: .screen),
        ]
    }
    if summary.hasPrefix("Opened "), summary.hasSuffix(" playfield image from Library") {
        let game = String(summary.dropFirst("Opened ".count).dropLast(" playfield image from Library".count))
        return [
            .init(text: "Opened ", color: .primary),
            .init(text: game, color: .game),
            .init(text: " ", color: .primary),
            .init(text: "playfield image", color: .screen),
            .init(text: " from ", color: .primary),
            .init(text: "Library", color: .screen),
        ]
    }
    if summary.hasPrefix("Opened "), summary.hasSuffix(" in Library"), let videoRange = summary.range(of: " video for ") {
        let detail = String(summary[summary.index(summary.startIndex, offsetBy: "Opened ".count)..<videoRange.lowerBound])
        let game = String(summary[videoRange.upperBound..<summary.index(summary.endIndex, offsetBy: -" in Library".count)])
        return [
            .init(text: "Opened ", color: .primary),
            .init(text: detail, color: .screen),
            .init(text: " ", color: .primary),
            .init(text: "video", color: .screen),
            .init(text: " for ", color: .primary),
            .init(text: game, color: .game),
            .init(text: " in ", color: .primary),
            .init(text: "Library", color: .screen),
        ]
    }
    return nil
}

private extension String {
    func stripProgressPrefix() -> String? {
        guard hasPrefix("Progress: ") else { return nil }
        let out = String(dropFirst("Progress: ".count))
        return out.isEmpty ? nil : out
    }
}

private func parsePracticePlayfieldSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    guard summary.hasPrefix("Viewed "),
          let range = summary.range(of: " playfield")
    else { return nil }

    let game = String(summary[summary.index(summary.startIndex, offsetBy: "Viewed ".count)..<range.lowerBound])
    guard !game.isEmpty else { return nil }

    let suffix = String(summary[range.upperBound...])
    let note: String?
    if suffix.hasPrefix(": ") {
        note = String(suffix.dropFirst(2))
    } else if suffix.isEmpty {
        note = nil
    } else {
        return nil
    }

    var tokens: [PracticeJournalSummaryToken] = [
        .init(text: "Viewed ", color: .primary),
        .init(text: game, color: .game),
        .init(text: " ", color: .primary),
        .init(text: "playfield", color: .screen),
    ]
    if let note, !note.isEmpty {
        tokens.append(.init(text: ": \(note)", color: .primary))
    }
    return tokens
}

private func parsePracticeRulesheetSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    guard summary.hasPrefix("Read "), summary.hasSuffix(" rulesheet") else { return nil }
    let body = String(summary.dropFirst("Read ".count).dropLast(" rulesheet".count))
    if let ofRange = body.range(of: " of ") {
        let progress = String(body[..<ofRange.lowerBound])
        let game = String(body[ofRange.upperBound...])
        guard !progress.isEmpty, !game.isEmpty else { return nil }
        return [
            .init(text: "Read ", color: .primary),
            .init(text: progress, color: .screen),
            .init(text: " of ", color: .primary),
            .init(text: game, color: .game),
            .init(text: " ", color: .primary),
            .init(text: "rulesheet", color: .screen),
        ]
    }
    guard !body.isEmpty else { return nil }
    return [
        .init(text: "Read ", color: .primary),
        .init(text: body, color: .game),
        .init(text: " ", color: .primary),
        .init(text: "rulesheet", color: .screen),
    ]
}

private func parsePracticeVideoSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    for prefix in ["Tutorial for ", "Gameplay for "] {
        guard summary.hasPrefix(prefix), let range = summary.range(of: ": ") else { continue }
        let kind = prefix.hasPrefix("Tutorial") ? "Tutorial" : "Gameplay"
        let game = String(summary[summary.index(summary.startIndex, offsetBy: prefix.count)..<range.lowerBound])
        let value = String(summary[range.upperBound...])
        guard !game.isEmpty else { return nil }
        return [
            .init(text: kind, color: .screen),
            .init(text: " for ", color: .primary),
            .init(text: game, color: .game),
            .init(text: ": ", color: .primary),
            .init(text: value, color: .primary),
        ]
    }

    if summary.hasPrefix("Updated tutorial progress for ") {
        let game = String(summary.dropFirst("Updated tutorial progress for ".count))
        return [
            .init(text: "Updated ", color: .primary),
            .init(text: "tutorial", color: .screen),
            .init(text: " progress for ", color: .primary),
            .init(text: game, color: .game),
        ]
    }
    if summary.hasPrefix("Updated gameplay progress for ") {
        let game = String(summary.dropFirst("Updated gameplay progress for ".count))
        return [
            .init(text: "Updated ", color: .primary),
            .init(text: "gameplay", color: .screen),
            .init(text: " progress for ", color: .primary),
            .init(text: game, color: .game),
        ]
    }
    return nil
}

private func parsePracticeProgressSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    if summary.hasPrefix("Practice progress "), let onRange = summary.range(of: " on ") {
        let value = String(summary[summary.index(summary.startIndex, offsetBy: "Practice progress ".count)..<onRange.lowerBound])
        let game = String(summary[onRange.upperBound...])
        guard !value.isEmpty, !game.isEmpty else { return nil }
        return [
            .init(text: "Practice", color: .screen),
            .init(text: " progress ", color: .primary),
            .init(text: value, color: .screen),
            .init(text: " on ", color: .primary),
            .init(text: game, color: .game),
        ]
    }
    if summary.hasPrefix("Logged practice for ") {
        let game = String(summary.dropFirst("Logged practice for ".count))
        guard !game.isEmpty else { return nil }
        return [
            .init(text: "Logged ", color: .primary),
            .init(text: "practice", color: .screen),
            .init(text: " for ", color: .primary),
            .init(text: game, color: .game),
        ]
    }
    return nil
}

private func parsePracticeBrowsedSummary(_ summary: String) -> [PracticeJournalSummaryToken]? {
    guard summary.hasPrefix("Browsed "), !summary.hasSuffix(" in Library") else { return nil }
    let game = String(summary.dropFirst("Browsed ".count))
    guard !game.isEmpty else { return nil }
    return [
        .init(text: "Browsed ", color: .primary),
        .init(text: game, color: .game),
    ]
}
