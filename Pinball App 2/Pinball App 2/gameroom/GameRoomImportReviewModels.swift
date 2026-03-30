import SwiftUI

enum ImportReviewFilter: String, CaseIterable, Identifiable {
    case all
    case needsReview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .needsReview: return "Needs Review"
        }
    }
}

struct ImportDraftRow: Identifiable {
    let id: String
    let sourceItemKey: String
    let rawTitle: String
    var rawPurchaseDateText: String?
    var normalizedPurchaseDate: Date?
    let matchConfidence: MachineImportMatchConfidence
    let suggestions: [GameRoomCatalogGame]
    let fingerprint: String
    var selectedCatalogGameID: String?
    var selectedVariant: String?
    var rawVariant: String?
}
