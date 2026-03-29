import Foundation
import CryptoKit

private struct RemoteFetchedDocument {
    let text: String
    let mimeType: String?
    let finalURL: URL
}

private struct RemoteCachedDocument {
    let text: String
    let mimeType: String?
    let finalURL: String
    let fetchedAt: TimeInterval
}

private struct TiltForumsTopicResponse: Decodable {
    struct PostStream: Decodable {
        let posts: [Post]
    }

    struct Post: Decodable {
        let cooked: String?
        let topicID: Int?
        let topicSlug: String?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case cooked
            case topicID = "topic_id"
            case topicSlug = "topic_slug"
            case updatedAt = "updated_at"
        }
    }

    let title: String?
    let postStream: PostStream?

    enum CodingKeys: String, CodingKey {
        case title
        case postStream = "post_stream"
    }
}

private struct TiltForumsPostResponse: Decodable {
    let cooked: String?
    let topicID: Int?
    let topicSlug: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case cooked
        case topicID = "topic_id"
        case topicSlug = "topic_slug"
        case updatedAt = "updated_at"
    }
}

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

    private static func cleanupPrimerHTML(_ html: String) -> String {
        let body = extractBodyHTML(from: html) ?? html
        var cleaned = stripHTML(body, patterns: [
            #"(?is)<iframe\b[^>]*>.*?</iframe>"#,
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<!--.*?-->"#
        ])
        if let firstHeadingRange = cleaned.range(of: #"(?is)<h1\b[^>]*>"#, options: .regularExpression) {
            cleaned = String(cleaned[firstHeadingRange.lowerBound...])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanupLegacyHTML(_ html: String, mimeType: String?, source: RulesheetRemoteSource) -> String {
        if shouldTreatAsPlainText(html: html, mimeType: mimeType) {
            return "<pre class=\"rulesheet-preformatted\">\(html.htmlEscaped)</pre>"
        }

        if source.provider == .bob, let main = extractMainHTML(from: html) {
            let cleanedMain = stripHTML(main, patterns: [
                #"(?is)<script\b[^>]*>.*?</script>"#,
                #"(?is)<!--.*?-->"#,
                #"(?is)<a\b[^>]*title="Print"[^>]*>.*?</a>"#
            ])
            return cleanedMain.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let body = extractBodyHTML(from: html) ?? html
        let cleaned = stripHTML(body, patterns: [
            #"(?is)<\?.*?\?>"#,
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<iframe\b[^>]*>.*?</iframe>"#,
            #"(?is)<!--.*?-->"#,
            #"(?is)</?(html|head|body|meta|link)\b[^>]*>"#
        ])
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldTreatAsPlainText(html: String, mimeType: String?) -> Bool {
        if mimeType?.localizedCaseInsensitiveContains("text/plain") == true {
            return true
        }
        let tagMatch = html.range(of: #"<[a-zA-Z!/][^>]*>"#, options: .regularExpression)
        return tagMatch == nil
    }

    private static func extractMainHTML(from html: String) -> String? {
        html.firstRegexCapture(#"(?is)<main\b[^>]*>(.*?)</main>"#)
    }

    private static func extractBodyHTML(from html: String) -> String? {
        html.firstRegexCapture(#"(?is)<body\b[^>]*>(.*?)</body>"#)
    }

    private static func stripHTML(_ html: String, patterns: [String]) -> String {
        patterns.reduce(html) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    private static func tiltForumsAPIURL(from url: URL) -> URL {
        if url.absoluteString.localizedCaseInsensitiveContains("/posts/"),
           url.path.lowercased().hasSuffix(".json") {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !(components?.path.lowercased().hasSuffix(".json") ?? false) {
            components?.path += ".json"
        }
        components?.query = nil
        return components?.url ?? url
    }

    private static func tiltForumsCanonicalURL(from post: TiltForumsTopicResponse.Post) -> URL? {
        guard let slug = post.topicSlug,
              let id = post.topicID else {
            return nil
        }
        return URL(string: "https://tiltforums.com/t/\(slug)/\(id)")
    }

    private static func tiltForumsCanonicalURL(from post: TiltForumsPostResponse) -> URL? {
        guard let slug = post.topicSlug,
              let id = post.topicID else {
            return nil
        }
        return URL(string: "https://tiltforums.com/t/\(slug)/\(id)")
    }

    private static func parseTiltForumsPayload(
        _ data: Data,
        fallbackURL: URL
    ) throws -> (cooked: String, canonicalURL: URL, updatedAt: String?) {
        if let topic = try? JSONDecoder().decode(TiltForumsTopicResponse.self, from: data),
           let post = topic.postStream?.posts.first,
           let cooked = post.cooked?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cooked.isEmpty {
            return (
                cooked,
                tiltForumsCanonicalURL(from: post) ?? canonicalTopicURL(from: fallbackURL),
                post.updatedAt
            )
        }

        let post = try JSONDecoder().decode(TiltForumsPostResponse.self, from: data)
        guard let cooked = post.cooked?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cooked.isEmpty else {
            throw URLError(.cannotDecodeContentData)
        }
        return (
            cooked,
            tiltForumsCanonicalURL(from: post) ?? canonicalTopicURL(from: fallbackURL),
            post.updatedAt
        )
    }

    private static func canonicalTopicURL(from url: URL) -> URL {
        if url.path.lowercased().hasSuffix(".json") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.query = nil
            let currentPath = components?.path ?? url.path
            components?.path = currentPath.replacingOccurrences(of: ".json", with: "")
            return components?.url ?? url
        }
        return url
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

actor RemoteRulesheetCache {
    private let fileManager = FileManager.default
    private let freshnessInterval: TimeInterval = 12 * 60 * 60

    fileprivate func loadFresh(url: URL) throws -> RemoteFetchedDocument? {
        guard let cached = try loadRaw(url: url) else { return nil }
        guard Date().timeIntervalSince1970 - cached.fetchedAt <= freshnessInterval else { return nil }
        return makeDocument(from: cached)
    }

    fileprivate func loadAny(url: URL) throws -> RemoteFetchedDocument? {
        guard let cached = try loadRaw(url: url) else { return nil }
        return makeDocument(from: cached)
    }

    fileprivate func save(_ document: RemoteFetchedDocument, for url: URL) throws {
        let cached = RemoteCachedDocument(
            text: document.text,
            mimeType: document.mimeType,
            finalURL: document.finalURL.absoluteString,
            fetchedAt: Date().timeIntervalSince1970
        )
        let data = try serialize(cached)
        let targetURL = try cacheFileURL(for: url)
        try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: targetURL, options: .atomic)
    }

    fileprivate func clear() throws {
        let cacheDirectoryURL = try self.cacheDirectoryURL()
        guard fileManager.fileExists(atPath: cacheDirectoryURL.path) else { return }
        try fileManager.removeItem(at: cacheDirectoryURL)
    }

    private func loadRaw(url: URL) throws -> RemoteCachedDocument? {
        let targetURL = try cacheFileURL(for: url)
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        let data = try Data(contentsOf: targetURL)
        return try deserialize(data)
    }

    private func makeDocument(from cached: RemoteCachedDocument) -> RemoteFetchedDocument? {
        guard let finalURL = URL(string: cached.finalURL) else { return nil }
        return RemoteFetchedDocument(text: cached.text, mimeType: cached.mimeType, finalURL: finalURL)
    }

    private func cacheFileURL(for url: URL) throws -> URL {
        let key = Insecure.SHA1.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return try cacheDirectoryURL()
            .appendingPathComponent("\(key).json")
    }

    private func cacheDirectoryURL() throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("remote-rulesheet-cache-v1", isDirectory: true)
    }

    private func serialize(_ cached: RemoteCachedDocument) throws -> Data {
        let jsonObject: [String: Any?] = [
            "text": cached.text,
            "mime_type": cached.mimeType,
            "final_url": cached.finalURL,
            "fetched_at": cached.fetchedAt,
        ]
        let compact = jsonObject.reduce(into: [String: Any]()) { result, item in
            if let value = item.value {
                result[item.key] = value
            }
        }
        return try JSONSerialization.data(withJSONObject: compact, options: [.prettyPrinted])
    }

    private func deserialize(_ data: Data) throws -> RemoteCachedDocument {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String,
              let finalURL = json["final_url"] as? String,
              let fetchedAt = json["fetched_at"] as? Double else {
            throw URLError(.cannotDecodeRawData)
        }
        return RemoteCachedDocument(
            text: text,
            mimeType: json["mime_type"] as? String,
            finalURL: finalURL,
            fetchedAt: fetchedAt
        )
    }
}

private extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
