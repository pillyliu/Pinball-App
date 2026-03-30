import SwiftUI

struct StandingsRowView: View {
    let standing: Standing
    let rank: Int
    let rankWidth: CGFloat
    let playerWidth: CGFloat
    let pointsWidth: CGFloat
    let eligibleWidth: CGFloat
    let nightsWidth: CGFloat
    let bankWidth: CGFloat
    let largeText: Bool
    let isHighlighted: Bool
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false

    var body: some View {
        let highlightedTextColor: Color = AppTheme.statsMeanMedian
        let playerColor: Color = isHighlighted ? highlightedTextColor : .primary
        let dataColor: Color = isHighlighted ? highlightedTextColor : .primary
        let dataWeight: Font.Weight = isHighlighted ? .semibold : .regular

        HStack(spacing: 0) {
            rowCell(
                rank.formatted(),
                width: rankWidth,
                color: resolvedRankColor,
                monospaced: true,
                weight: isHighlighted ? .bold : (rank <= 3 ? .bold : .regular)
            )
            rowCell(
                displayLPLPlayerName(standing.rawPlayer),
                width: playerWidth,
                color: playerColor,
                weight: isHighlighted ? .semibold : (rank <= 8 ? .semibold : .regular)
            )
            rowCell(
                formatStandingsRounded(standing.seasonTotal),
                width: pointsWidth,
                color: dataColor,
                monospaced: true,
                weight: isHighlighted ? .bold : .regular
            )
            rowCell(standing.eligible, width: eligibleWidth, color: dataColor, weight: dataWeight)
            rowCell(standing.nights, width: nightsWidth, color: dataColor, monospaced: true, weight: dataWeight)

            ForEach(standing.banks.indices, id: \.self) { index in
                rowCell(
                    formatStandingsRounded(standing.banks[index]),
                    width: bankWidth,
                    color: dataColor,
                    monospaced: true,
                    weight: dataWeight
                )
            }
        }
        .frame(height: largeText ? 40 : 36)
    }

    private var resolvedRankColor: Color {
        if isHighlighted && rank > 3 {
            return AppTheme.statsMeanMedian
        }
        return rankColor
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return AppTheme.podiumGold
        case 2: return AppTheme.podiumSilver
        case 3: return AppTheme.podiumBronze
        default: return .primary
        }
    }

    private func rowCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .leading,
        color: Color = .primary,
        monospaced: Bool = false,
        weight: Font.Weight = .regular
    ) -> some View {
        let horizontalPadding: CGFloat = 3
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        return Text(text)
            .font(monospaced
                ? (largeText ? Font.callout.monospacedDigit().weight(weight) : Font.footnote.monospacedDigit().weight(weight))
                : (largeText ? Font.callout.weight(weight) : Font.footnote.weight(weight)))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}
