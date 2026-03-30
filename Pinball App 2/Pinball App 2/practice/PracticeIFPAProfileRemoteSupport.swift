import Foundation

enum IFPAPublicProfileService {
    static func fetchProfile(playerID: String) async throws -> IFPAPlayerProfile {
        guard var components = URLComponents(string: "https://www.ifpapinball.com/players/view.php") else {
            throw IFPAProfileError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "p", value: playerID)]
        guard let url = components.url else {
            throw IFPAProfileError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw IFPAProfileError.networkFailure
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw IFPAProfileError.unreadableResponse
        }

        return try parseProfile(html: html, playerID: playerID)
    }

    private static func parseProfile(html: String, playerID: String) throws -> IFPAPlayerProfile {
        let displayName = firstMatch(in: html, pattern: #"<h1>\s*(.*?)\s*</h1>"#)?
            .cleanedHTMLText() ?? "IFPA Player"
        let profilePhotoURL = firstMatch(
            in: html,
            pattern: #"<div id="playerpic" class="widget widget_text">\s*<img [^>]*src="([^"]+)""#
        ).flatMap(URL.init(string:))
        let location: String? = {
            let cityState = firstMatch(
                in: html,
                pattern: #"<td class="right">Location:</td>\s*<td>([^<]+)</td>"#
            )?.cleanedHTMLText()
            let country = firstMatch(
                in: html,
                pattern: #"<td class="right">Country:</td>\s*<td>([^<]+)</td>"#
            )?.cleanedHTMLText()
            switch (cityState, country) {
            case let (.some(cityState), .some(country)) where !cityState.isEmpty && !country.isEmpty:
                return "\(cityState), \(country)"
            case let (.some(cityState), _):
                return cityState
            case let (_, .some(country)):
                return country
            default:
                return nil
            }
        }()

        let currentRank = firstMatch(
            in: html,
            pattern: #"<td class="right"><a href="/rankings/overall\.php">Open Ranking</a>:</td>\s*<td class="right">([^<]+)</td>\s*<td>([^<]+)</td>"#,
            group: 1
        )?.cleanedHTMLText()
        let currentWPPRPoints = firstMatch(
            in: html,
            pattern: #"<td class="right"><a href="/rankings/overall\.php">Open Ranking</a>:</td>\s*<td class="right">([^<]+)</td>\s*<td>([^<]+)</td>"#,
            group: 2
        )?.cleanedHTMLText()
        let rating = firstMatch(
            in: html,
            pattern: #"<td class="right">Rating:</td>\s*<td class="right">([^<]+)</td>\s*<td>([^<]+)</td>"#,
            group: 2
        )?.cleanedHTMLText()

        guard let currentRank, let currentWPPRPoints, let rating else {
            throw IFPAProfileError.parseFailure
        }

        let seriesHeadline = firstMatch(
            in: html,
            pattern: #"<h4 class="widgettitle">([^<]+)</h4>\s*<table class="width100 infoTable">\s*<tr>\s*<td class="right width50"><a [^>]+>([^<]+)</a></td>\s*<td class="center">([^<]+)</td>"#
        )
        let seriesRegion = firstMatch(
            in: html,
            pattern: #"<h4 class="widgettitle">([^<]+)</h4>\s*<table class="width100 infoTable">\s*<tr>\s*<td class="right width50"><a [^>]+>([^<]+)</a></td>\s*<td class="center">([^<]+)</td>"#,
            group: 2
        )
        let seriesRank = firstMatch(
            in: html,
            pattern: #"<h4 class="widgettitle">([^<]+)</h4>\s*<table class="width100 infoTable">\s*<tr>\s*<td class="right width50"><a [^>]+>([^<]+)</a></td>\s*<td class="center">([^<]+)</td>"#,
            group: 3
        )

        let activeSection = html.slice(
            from: #"<div style="display: none;" id="divactive">"#,
            to: #"<!-- Past Results -->"#
        ) ?? ""

        let rowPattern = #"<tr>\s*<td>.*?<a href="[^"]+">([^<]+)</a>\s*</td>\s*<td>([^<]+)</td>\s*<td class="center">([^<]+)</td>\s*<td align="center">([^<]+)</td>\s*<td align="center">([^<]+)</td>\s*</tr>"#

        let tournaments = matches(in: activeSection, pattern: rowPattern).compactMap { groups -> IFPARecentTournament? in
            guard groups.count >= 5 else { return nil }
            let dateLabel = groups[3].cleanedHTMLText()
            guard let date = Self.resultDateFormatter.date(from: dateLabel) else { return nil }
            return IFPARecentTournament(
                name: groups[0].cleanedHTMLText(),
                date: date,
                dateLabel: dateLabel,
                finish: groups[2].cleanedHTMLText(),
                pointsGained: groups[4].cleanedHTMLText()
            )
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.name < rhs.name
            }
            return lhs.date > rhs.date
        }

        let resolvedSeriesRank: String?
        if let seriesRegion, let seriesRank {
            resolvedSeriesRank = "\(seriesRegion.cleanedHTMLText()) \(seriesRank.cleanedHTMLText())"
        } else {
            resolvedSeriesRank = nil
        }

        return IFPAPlayerProfile(
            playerID: playerID,
            displayName: displayName,
            location: location,
            profilePhotoURL: profilePhotoURL,
            currentRank: currentRank,
            currentWPPRPoints: currentWPPRPoints,
            rating: rating,
            lastEventDate: tournaments.first?.dateLabel,
            seriesLabel: seriesHeadline?.cleanedHTMLText(),
            seriesRank: resolvedSeriesRank,
            recentTournaments: Array(tournaments.prefix(3))
        )
    }

    private static let resultDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }()

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

enum IFPAProfileError: LocalizedError {
    case invalidURL
    case networkFailure
    case unreadableResponse
    case parseFailure

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The IFPA profile URL could not be created."
        case .networkFailure:
            return "The IFPA profile could not be loaded right now."
        case .unreadableResponse:
            return "The IFPA profile response could not be read."
        case .parseFailure:
            return "The public IFPA profile layout did not match the expected format."
        }
    }
}

private extension String {
    func cleanedHTMLText() -> String {
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

    func slice(from startMarker: String, to endMarker: String) -> String? {
        guard let startRange = range(of: startMarker) else { return nil }
        guard let endRange = range(of: endMarker, range: startRange.upperBound..<endIndex) else { return nil }
        return String(self[startRange.upperBound..<endRange.lowerBound])
    }
}
