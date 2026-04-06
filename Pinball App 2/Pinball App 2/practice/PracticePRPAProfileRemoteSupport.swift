import Foundation

enum PRPAPublicProfileService {
    static func fetchProfile(playerID: String) async throws -> PRPAPlayerProfile {
        guard var components = URLComponents(string: "https://punkrockpinball.com/player/") else {
            throw PRPAProfileError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "prp_id", value: playerID)]
        guard let url = components.url else {
            throw PRPAProfileError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw PRPAProfileError.networkFailure
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw PRPAProfileError.unreadableResponse
        }

        return try parseProfile(html: html, playerID: playerID)
    }

    private static func parseProfile(html: String, playerID: String) throws -> PRPAPlayerProfile {
        guard html.localizedCaseInsensitiveContains("prpp-player-results") else {
            throw PRPAProfileError.parseFailure
        }

        let displayName = firstMatch(in: html, pattern: #"<h1[^>]*>\s*(.*?)\s*</h1>"#)?
            .prpaCleanedHTMLText() ?? "PRPA Player"

        let scenesSection = html.prpaSlice(from: #"<div class="prpp-summary-scenes">"#, to: #"</div>"#) ?? ""
        let scenes = matches(
            in: scenesSection,
            pattern: #"<a [^>]*>([^<]+)</a>\s*<strong[^>]*>([^<]+)</strong>"#
        )
        .compactMap { groups -> PRPASceneStanding? in
            guard groups.count >= 2 else { return nil }
            return PRPASceneStanding(
                name: groups[0].prpaCleanedHTMLText(),
                rank: groups[1].prpaCleanedHTMLText()
            )
        }

        let tableSection = html.prpaSlice(from: #"<table class="prpp-table widefat striped">"#, to: #"</table>"#) ?? ""
        let tournaments = matches(
            in: tableSection,
            pattern: #"<tr>\s*<td>(.*?)</td>\s*<td>([^<]+)</td>\s*<td>([^<]+)</td>\s*<td>([^<]+)</td>\s*</tr>"#
        )
        .compactMap { groups -> PRPARecentTournament? in
            guard groups.count >= 4 else { return nil }
            let tournamentCell = groups[0]
            let dateLabel = groups[1].prpaCleanedHTMLText()
            guard let date = resultDateFormatter.date(from: dateLabel) else { return nil }
            let name = firstMatch(in: tournamentCell, pattern: #"<a [^>]*>([^<]+)</a>"#)?
                .prpaCleanedHTMLText() ?? tournamentCell.prpaCleanedHTMLText()
            let eventType = firstMatch(in: tournamentCell, pattern: #"<span class="prpp-badge[^"]*">([^<]+)</span>"#)?
                .prpaCleanedHTMLText()
            return PRPARecentTournament(
                name: name,
                eventType: eventType,
                date: date,
                dateLabel: dateLabel,
                placement: groups[2].prpaCleanedHTMLText(),
                pointsGained: groups[3].prpaCleanedHTMLText()
            )
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.name < rhs.name
            }
            return lhs.date > rhs.date
        }

        return PRPAPlayerProfile(
            playerID: playerID,
            displayName: displayName,
            openPoints: summaryValue(in: html, label: "Open PRPA Points:") ?? "-",
            eventsPlayed: summaryValue(in: html, label: "Events Played:") ?? "-",
            openRanking: summaryValue(in: html, label: "Open Ranking:") ?? "-",
            averagePointsPerEvent: summaryValue(in: html, label: "Average Points/Event:") ?? "-",
            bestFinish: summaryValue(in: html, label: "Best Finish (by points):") ?? "-",
            worstFinish: summaryValue(in: html, label: "Worst Finish (by points):") ?? "-",
            ifpaPlayerID: summaryValue(in: html, label: "IFPA ID:"),
            lastEventDate: tournaments.first?.dateLabel,
            scenes: scenes,
            recentTournaments: Array(tournaments.prefix(3))
        )
    }

    private static let resultDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yyyy - h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()

    private static func summaryValue(in html: String, label: String) -> String? {
        let escapedLabel = NSRegularExpression.escapedPattern(for: label)
        let pattern = "<li[^>]*>\\s*<strong>\\s*\(escapedLabel)\\s*</strong>\\s*(?:<span[^>]*>)?\\s*([^<]+)"
        return firstMatch(in: html, pattern: pattern)?.prpaCleanedHTMLText()
    }

    private static func firstMatch(in text: String, pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range(at: group), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func matches(in text: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: nsRange).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
        }
    }
}

enum PRPAProfileError: LocalizedError {
    case invalidURL
    case networkFailure
    case unreadableResponse
    case parseFailure

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The PRPA profile URL could not be created."
        case .networkFailure:
            return "The PRPA profile could not be loaded right now."
        case .unreadableResponse:
            return "The PRPA profile response could not be read."
        case .parseFailure:
            return "The public PRPA profile layout did not match the expected format."
        }
    }
}

private extension String {
    func prpaCleanedHTMLText() -> String {
        self
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8211;", with: "-")
            .replacingOccurrences(of: "&ndash;", with: "-")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#8220;", with: "\"")
            .replacingOccurrences(of: "&#8221;", with: "\"")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func prpaSlice(from startMarker: String, to endMarker: String) -> String? {
        guard let startRange = range(of: startMarker) else { return nil }
        guard let endRange = range(of: endMarker, range: startRange.upperBound..<endIndex) else { return nil }
        return String(self[startRange.upperBound..<endRange.lowerBound])
    }
}
