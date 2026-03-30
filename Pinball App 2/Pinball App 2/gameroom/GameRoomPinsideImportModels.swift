import Foundation

struct PinsideImportedMachine: Identifiable, Hashable {
    let id: String
    let slug: String
    let rawTitle: String
    let rawVariant: String?
    let manufacturerLabel: String?
    let manufactureYear: Int?
    let rawPurchaseDateText: String?
    let normalizedPurchaseDate: Date?

    var fingerprint: String {
        "pinside:\(slug.lowercased())"
    }
}

enum GameRoomPinsideImportError: LocalizedError {
    case invalidInput
    case invalidURL
    case httpError(Int)
    case userNotFound
    case privateOrUnavailableCollection
    case parseFailed
    case noMachinesFound

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Enter a Pinside username or public collection URL."
        case .invalidURL:
            return "Could not build a valid Pinside collection URL."
        case let .httpError(code):
            return "Pinside request failed (\(code))."
        case .userNotFound:
            return "Could not find that Pinside user/profile."
        case .privateOrUnavailableCollection:
            return "This Pinside collection appears private or unavailable publicly."
        case .parseFailed:
            return "Could not parse that collection page. Try a different public collection URL."
        case .noMachinesFound:
            return "No machine entries were found on that public collection page."
        }
    }
}
