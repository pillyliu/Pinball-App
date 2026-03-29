import Foundation

struct NormalizedLibraryRoot: Decodable {
    let schemaVersion: Int?
    let generatedAt: String?
    let manufacturers: [CatalogManufacturerRecord]?
    let machines: [CatalogMachineRecord]?
    let sources: [CatalogSourceRecord]?
    let sourceMemberships: [CatalogMembershipRecord]?
    let memberships: [CatalogMembershipRecord]?
    let overrides: [CatalogOverrideRecord]?
    let rulesheetLinks: [CatalogRulesheetLinkRecord]?
    let videoLinks: [CatalogVideoLinkRecord]?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case manufacturers
        case machines
        case sources
        case sourceMemberships = "source_memberships"
        case memberships
        case overrides
        case rulesheetLinks = "rulesheet_links"
        case videoLinks = "video_links"
    }
}
