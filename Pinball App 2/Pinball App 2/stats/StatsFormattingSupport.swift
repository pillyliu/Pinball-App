import Foundation

func formatStatsScore(_ value: Double?) -> String {
    guard let value, value.isFinite, value > 0 else { return "-" }
    return Int(value.rounded()).formatted(.number.grouping(.automatic))
}

func formatStatsPoints(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "-" }
    return Int(value.rounded()).formatted()
}

func abbreviatedStatsSeason(_ season: String) -> String {
    let digits = season.filter(\.isNumber)
    return digits.isEmpty ? season : "S\(digits)"
}
