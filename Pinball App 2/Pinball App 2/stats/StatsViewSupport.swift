import SwiftUI

extension View {
    func readHeight(onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onChange(geo.size.height) }
                    .onChange(of: geo.size.height) { _, newValue in
                        onChange(newValue)
                    }
            }
        )
    }
}

struct TableRowView: View {
    let row: ScoreRow
    let seasonColWidth: CGFloat
    let playerColWidth: CGFloat
    let bankNumColWidth: CGFloat
    let machineColWidth: CGFloat
    let scoreColWidth: CGFloat
    let pointsColWidth: CGFloat
    let rowHeight: CGFloat
    let largeText: Bool
    let isHighlighted: Bool
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false

    var body: some View {
        let emphasizedColor: Color = AppTheme.statsMeanMedian
        let accentColor: Color = isHighlighted ? emphasizedColor : .primary
        let baseWeight: Font.Weight = isHighlighted ? .semibold : .regular

        HStack(spacing: 0) {
            rowCell(row.season, width: seasonColWidth, weight: baseWeight)
            rowCell(String(row.bankNumber), width: bankNumColWidth, weight: baseWeight)
            rowCell(displayLPLPlayerName(row.player), width: playerColWidth, color: accentColor, weight: baseWeight)
            rowCell(row.machine, width: machineColWidth, weight: baseWeight)
            rowCell(
                formatStatsScore(row.rawScore),
                width: scoreColWidth,
                color: accentColor,
                monospaced: true,
                weight: isHighlighted ? .semibold : .regular
            )
            rowCell(
                formatStatsPoints(row.points),
                width: pointsColWidth,
                color: accentColor,
                monospaced: true,
                weight: isHighlighted ? .semibold : .regular
            )
        }
        .frame(height: rowHeight)
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }

    private func rowCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .leading,
        color: Color = .primary,
        monospaced: Bool = false,
        weight: Font.Weight = .regular
    ) -> some View {
        let horizontalPadding: CGFloat = 4
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        return Text(text)
            .font(monospaced
                ? (largeText ? Font.callout.monospacedDigit().weight(weight) : Font.footnote.monospacedDigit().weight(weight))
                : (largeText ? Font.callout.weight(weight) : Font.footnote.weight(weight)))
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}

struct MachineStatsPanel: View {
    let machine: String
    let season: String
    let bankNumber: Int?
    let bankStats: StatResult
    let historicalStats: StatResult
    let largeText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if machine.isEmpty {
                Text("Select a machine to see machine stats")
                    .font(largeText ? .callout : .footnote)
                    .foregroundStyle(.secondary)
            } else {
                MachineStatsTable(
                    selectedLabel: selectedBankLabel,
                    selectedStats: bankStats,
                    allSeasonsStats: historicalStats,
                    largeText: largeText
                )
            }
        }
        .padding(largeText ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var selectedBankLabel: String {
        let seasonLabel = season.isEmpty ? "S?" : abbreviatedStatsSeason(season)
        return "\(seasonLabel) \(bankNumber.map { "B\($0)" } ?? "B?")"
    }
}

struct MachineStatsTable: View {
    let selectedLabel: String
    let selectedStats: StatResult
    let allSeasonsStats: StatResult
    let largeText: Bool
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false

    private let labels = ["High", "Low", "Avg", "Med", "Std", "Count"]
    private var labelColumnWidth: CGFloat { largeText ? 64 : 44 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                headerCell("", align: .leading)
                    .frame(width: labelColumnWidth, alignment: .leading)
                headerCell(selectedLabel, align: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                headerCell("All Seasons", align: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 4)

            ForEach(labels, id: \.self) { label in
                HStack(spacing: 8) {
                    Text(label)
                        .font((largeText ? Font.callout : Font.caption).weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: labelColumnWidth, alignment: .leading)
                        .padding(.vertical, largeText ? 5 : 3)
                    statCell(label: label, stats: selectedStats)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    statCell(label: label, stats: allSeasonsStats)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func headerCell(_ text: String, align: Alignment) -> some View {
        Text(text)
            .font((largeText ? Font.callout : Font.caption2).weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: align)
    }

    private func statCell(label: String, stats: StatResult) -> some View {
        let value: String = switch label {
        case "High": formatStatsScore(stats.high)
        case "Low": formatStatsScore(stats.low)
        case "Avg": formatStatsScore(stats.mean)
        case "Med": formatStatsScore(stats.median)
        case "Std": formatStatsScore(stats.std)
        case "Count": stats.count > 0 ? String(stats.count) : "-"
        default: "-"
        }
        let color: Color = switch label {
        case "High": AppTheme.statsHigh
        case "Low": AppTheme.statsLow
        case "Avg", "Med": AppTheme.statsMeanMedian
        default: .primary
        }
        let player: StatPlayerLabel? = switch label {
        case "High": stats.highPlayer
        case "Low": stats.lowPlayer
        default: nil
        }

        return VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font((largeText ? Font.body : Font.caption).monospacedDigit().weight(.medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if label == "High" || label == "Low" {
                Text(playerName(player))
                    .font(largeText ? .footnote : .caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, largeText ? 5 : 3)
    }

    private func playerName(_ player: StatPlayerLabel?) -> String {
        guard let player else { return "-" }
        let display = formatLPLPlayerNameForDisplay(
            player.rawPlayer,
            showFullLastNames: showFullLPLLastNames
        )
        guard let season = player.season, !season.isEmpty else {
            return display
        }
        return "\(display) (\(season))"
    }
}
