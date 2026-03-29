import Foundation
import CryptoKit

struct RemoteFetchedDocument {
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

actor RemoteRulesheetCache {
    private let fileManager = FileManager.default
    private let freshnessInterval: TimeInterval = 12 * 60 * 60

    func loadFresh(url: URL) throws -> RemoteFetchedDocument? {
        guard let cached = try loadRaw(url: url) else { return nil }
        guard Date().timeIntervalSince1970 - cached.fetchedAt <= freshnessInterval else { return nil }
        return makeDocument(from: cached)
    }

    func loadAny(url: URL) throws -> RemoteFetchedDocument? {
        guard let cached = try loadRaw(url: url) else { return nil }
        return makeDocument(from: cached)
    }

    func save(_ document: RemoteFetchedDocument, for url: URL) throws {
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

    func clear() throws {
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

extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
