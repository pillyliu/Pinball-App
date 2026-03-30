import Foundation

struct Standing: Identifiable {
    let id: String
    let rawPlayer: String
    let seasonTotal: Double
    let eligible: String
    let nights: String
    let banks: [Double]
}

struct StandingsCSVRow {
    let season: Int
    let player: String
    let total: Double
    let rank: Int?
    let eligible: String
    let nights: String
    let banks: [Double]
}
