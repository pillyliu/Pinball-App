import Foundation

struct ScoreRow: Identifiable {
    let id: Int
    let season: String
    let bankNumber: Int
    let player: String
    let machine: String
    let rawScore: Double
    let points: Double
}

struct StatPlayerLabel {
    let rawPlayer: String
    let season: String?
}

struct StatResult {
    let count: Int
    let low: Double?
    let lowPlayer: StatPlayerLabel?
    let high: Double?
    let highPlayer: StatPlayerLabel?
    let mean: Double?
    let median: Double?
    let std: Double?

    static let empty = StatResult(
        count: 0,
        low: nil,
        lowPlayer: nil,
        high: nil,
        highPlayer: nil,
        mean: nil,
        median: nil,
        std: nil
    )
}
