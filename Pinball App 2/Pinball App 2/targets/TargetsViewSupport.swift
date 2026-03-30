import SwiftUI

struct TargetsRowView: View {
    let row: LPLTargetRow
    let gameColumnWidth: CGFloat
    let bankColumnWidth: CGFloat
    let scoreColumnWidth: CGFloat
    let largeText: Bool

    var body: some View {
        HStack(spacing: 0) {
            rowCell(row.target.game, width: gameColumnWidth)
            rowCell(row.bank.map(String.init) ?? "-", width: bankColumnWidth, alignment: .leading)
            rowCell(row.target.great.formattedTargetScore, width: scoreColumnWidth, alignment: .leading, color: AppTheme.targetGreat, monospaced: true, weight: .medium)
            rowCell(row.target.main.formattedTargetScore, width: scoreColumnWidth, alignment: .leading, color: AppTheme.targetMain, monospaced: true)
            rowCell(row.target.floor.formattedTargetScore, width: scoreColumnWidth, alignment: .leading, color: AppTheme.targetFloor, monospaced: true)
        }
        .frame(height: largeText ? 38 : 32)
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

struct TargetsHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var largeText: Bool = false

    var body: some View {
        let horizontalPadding: CGFloat = 4
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        return Text(title)
            .font((largeText ? Font.footnote : Font.caption2).weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}
