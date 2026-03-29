import Foundation

enum RemoteRulesheetLoader {
    private static let cache = RemoteRulesheetCache()

    static func load(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        switch source.provider {
        case .tiltForums:
            return try await loadTiltForums(from: source)
        case .pinballPrimer:
            return try await loadPrimer(from: source)
        case .papa, .bob:
            return try await loadLegacyHTML(from: source)
        }
    }

    static func clearCache() async throws {
        try await cache.clear()
    }

    private static func loadTiltForums(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        let apiURL = tiltForumsAPIURL(from: source.url)
        let fetched = try await fetchCached(url: apiURL)
        let payloadData = Data(fetched.text.utf8)
        let parsed = try parseTiltForumsPayload(payloadData, fallbackURL: source.url)
        let canonicalURL = parsed.canonicalURL
        let attribution = attributionHTML(
            source: source,
            displayURL: canonicalURL,
            updatedAt: parsed.updatedAt
        )
        let body = """
        \(attribution)
        <div class="pinball-rulesheet remote-rulesheet tiltforums-rulesheet">
        \(parsed.cooked)
        </div>
        """
        return RulesheetRenderContent(kind: .html, body: body, baseURL: canonicalURL)
    }

    private static func loadPrimer(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        let fetched = try await fetchCached(url: source.url)
        let fragment = cleanupPrimerHTML(fetched.text)
        let attribution = attributionHTML(source: source, displayURL: fetched.finalURL, updatedAt: nil)
        let body = """
        \(attribution)
        <div class="pinball-rulesheet remote-rulesheet primer-rulesheet">
        \(fragment)
        </div>
        """
        return RulesheetRenderContent(kind: .html, body: body, baseURL: fetched.finalURL)
    }

    private static func loadLegacyHTML(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        let fetchURL = legacyFetchURL(for: source)
        let fetched = try await fetchCached(url: fetchURL)
        let fragment = cleanupLegacyHTML(fetched.text, mimeType: fetched.mimeType, source: source)
        let attribution = attributionHTML(source: source, displayURL: fetched.finalURL, updatedAt: nil)
        let body = """
        \(attribution)
        <div class="pinball-rulesheet remote-rulesheet legacy-rulesheet">
        \(fragment)
        </div>
        """
        return RulesheetRenderContent(kind: .html, body: body, baseURL: fetched.finalURL)
    }

    private static func fetch(url: URL) async throws -> RemoteFetchedDocument {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 PinballApp/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw URLError(.cannotDecodeRawData)
        }
        return RemoteFetchedDocument(
            text: text,
            mimeType: response.mimeType,
            finalURL: response.url ?? url
        )
    }

    private static func fetchCached(url: URL) async throws -> RemoteFetchedDocument {
        if let cached = try? await cache.loadFresh(url: url) {
            return cached
        }

        do {
            let fetched = try await fetch(url: url)
            try? await cache.save(fetched, for: url)
            return fetched
        } catch {
            if let stale = try? await cache.loadAny(url: url) {
                return stale
            }
            throw error
        }
    }

    private static func legacyFetchURL(for source: RulesheetRemoteSource) -> URL {
        guard source.provider == .bob else { return source.url }
        guard source.url.host?.lowercased().contains("silverballmania.com") == true else { return source.url }
        guard let slug = source.url.pathComponents.last, !slug.isEmpty else { return source.url }
        return URL(string: "https://rules.silverballmania.com/print/\(slug)") ?? source.url
    }

    private static func attributionHTML(
        source: RulesheetRemoteSource,
        displayURL: URL,
        updatedAt: String?
    ) -> String {
        let updatedText: String
        if let updatedAt, !updatedAt.isEmpty {
            updatedText = " | Updated: \(updatedAt.htmlEscaped)"
        } else {
            updatedText = ""
        }

        return """
        <small class="rulesheet-attribution">Source: \(source.provider.sourceName.htmlEscaped) | \(source.provider.originalLinkLabel.htmlEscaped): <a href="\(displayURL.absoluteString.htmlEscaped)">link</a>\(updatedText) | \(source.provider.detailsText.htmlEscaped) | Reformatted for readability and mobile use.</small>
        """
    }
}
