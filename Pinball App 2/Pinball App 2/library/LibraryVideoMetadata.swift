import Foundation

actor YouTubeVideoMetadataService {
    static let shared = YouTubeVideoMetadataService()

    private struct YouTubeOEmbedResponse: Decodable {
        let title: String
        let author_name: String
    }

    private var cache: [String: PinballGame.YouTubeMetadata] = [:]

    nonisolated private static func decodeYouTubeOEmbedMetadata(from data: Data) throws -> PinballGame.YouTubeMetadata? {
        let decoded = try JSONDecoder().decode(YouTubeOEmbedResponse.self, from: data)
        let title = decoded.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let channelName = decoded.author_name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PinballGame.YouTubeMetadata(
            title: title,
            channelName: channelName.isEmpty ? nil : channelName
        )
    }

    func metadata(videoID: String, requestURL: URL) async -> PinballGame.YouTubeMetadata? {
        if let cached = cache[videoID] {
            return cached
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: requestURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode) else {
                return nil
            }
            guard let metadata = try Self.decodeYouTubeOEmbedMetadata(from: data) else {
                return nil
            }
            cache[videoID] = metadata
            return metadata
        } catch {
            return nil
        }
    }
}
