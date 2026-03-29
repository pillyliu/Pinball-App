import Foundation

struct TiltForumsTopicResponse: Decodable {
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

struct TiltForumsPostResponse: Decodable {
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

extension RemoteRulesheetLoader {
    static func tiltForumsAPIURL(from url: URL) -> URL {
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

    static func tiltForumsCanonicalURL(from post: TiltForumsTopicResponse.Post) -> URL? {
        guard let slug = post.topicSlug,
              let id = post.topicID else {
            return nil
        }
        return URL(string: "https://tiltforums.com/t/\(slug)/\(id)")
    }

    static func tiltForumsCanonicalURL(from post: TiltForumsPostResponse) -> URL? {
        guard let slug = post.topicSlug,
              let id = post.topicID else {
            return nil
        }
        return URL(string: "https://tiltforums.com/t/\(slug)/\(id)")
    }

    static func parseTiltForumsPayload(
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

    static func canonicalTopicURL(from url: URL) -> URL {
        if url.path.lowercased().hasSuffix(".json") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.query = nil
            let currentPath = components?.path ?? url.path
            components?.path = currentPath.replacingOccurrences(of: ".json", with: "")
            return components?.url ?? url
        }
        return url
    }
}
