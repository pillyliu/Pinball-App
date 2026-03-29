import Foundation

extension PinballGame {
    struct ReferenceLink: Identifiable, Decodable {
        let label: String
        let url: String

        var id: String {
            "\(label)|\(url)"
        }

        nonisolated var destinationURL: URL? {
            URL(string: url)
        }
    }

    struct PlayableVideo: Identifiable {
        let id: String
        let label: String

        var youtubeWatchURL: URL? {
            URL(string: "https://www.youtube.com/watch?v=\(id)")
        }

        var youtubeOEmbedURL: URL? {
            guard let watchURL = youtubeWatchURL else { return nil }
            var components = URLComponents(string: "https://www.youtube.com/oembed")
            components?.queryItems = [
                URLQueryItem(name: "url", value: watchURL.absoluteString),
                URLQueryItem(name: "format", value: "json")
            ]
            return components?.url
        }

        var thumbnailCandidates: [URL] {
            [
                URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"),
                URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg"),
                URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg"),
                URL(string: "https://img.youtube.com/vi/\(id)/0.jpg")
            ].compactMap { $0 }
        }
    }

    struct Video: Identifiable, Decodable {
        let kind: String?
        let label: String?
        let url: String?

        var id: String {
            [kind ?? "", label ?? "", url ?? UUID().uuidString].joined(separator: "|")
        }
    }

    struct YouTubeMetadata: Equatable {
        let title: String
        let channelName: String?
    }

    enum CodingKeys: String, CodingKey {
        case libraryId
        case libraryIdV2 = "library_id"
        case sourceId
        case libraryName
        case libraryNameV2 = "library_name"
        case sourceName
        case libraryType
        case libraryTypeV2 = "library_type"
        case sourceType
        case venueName
        case venue
        case area
        case areaOrder
        case areaOrderV2 = "area_order"
        case location
        case group
        case position
        case bank
        case name
        case game
        case variant
        case manufacturer
        case year
        case slug
        case opdbId = "opdb_id"
        case opdbMachineID = "opdb_machine_id"
        case libraryEntryId = "library_entry_id"
        case practiceIdentity = "practice_identity"
        case opdbName = "opdb_name"
        case opdbCommonName = "opdb_common_name"
        case opdbShortname = "opdb_shortname"
        case opdbDescription = "opdb_description"
        case opdbType = "opdb_type"
        case opdbDisplay = "opdb_display"
        case opdbPlayerCount = "opdb_player_count"
        case opdbManufactureDate = "opdb_manufacture_date"
        case opdbIpdbID = "opdb_ipdb_id"
        case opdbGroupShortname = "opdb_group_shortname"
        case opdbGroupDescription = "opdb_group_description"
        case playfieldImageUrl
        case playfieldImageUrlV2 = "playfield_image_url"
        case alternatePlayfieldImageUrl = "alternate_playfield_image_url"
        case primaryImageUrl = "primary_image_url"
        case primaryImageLargeUrl = "primary_image_large_url"
        case playfieldLocal
        case rulesheetUrl
        case rulesheetUrlV2 = "rulesheet_url"
        case rulesheetLinks = "rulesheet_links"
        case playfieldSourceLabel = "playfield_source_label"
        case assets
        case videos
    }

    struct Assets: Decodable {
        let playfieldLocalPractice: String?
        let rulesheetLocalPractice: String?
        let gameinfoLocalPractice: String?

        enum CodingKeys: String, CodingKey {
            case playfieldLocalPractice = "playfield_local_practice"
            case rulesheetLocalPractice = "rulesheet_local_practice"
            case gameinfoLocalPractice = "gameinfo_local_practice"
        }
    }
}
