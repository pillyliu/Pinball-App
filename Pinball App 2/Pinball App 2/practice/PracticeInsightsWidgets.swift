import SwiftUI

struct HeadToHeadGameRow: View {
    let game: HeadToHeadGameStats

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.gameName)
                .font(.footnote.weight(.semibold))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mean")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(formatted(game.yourMean)) vs \(formatted(game.opponentMean))")
                        .font(.caption)
                }
                Spacer()
                Text(game.meanDelta >= 0 ? "+\(formatted(abs(game.meanDelta)))" : "-\(formatted(abs(game.meanDelta)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(game.meanDelta >= 0 ? .green : .orange)
            }
        }
        .padding(.vertical, 3)
    }
}

struct MechanicsTrendSparkline: View {
    let logs: [MechanicsSkillLog]

    var body: some View {
        GeometryReader { geo in
            let values = logs.compactMap(\.comfort).map(Double.init)
            if values.count < 2 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Text("Need 2+ comfort logs for trend")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            } else {
                let minV = values.min() ?? 1
                let maxV = values.max() ?? 5
                let span = max(0.1, maxV - minV)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    Path { path in
                        for (idx, value) in values.enumerated() {
                            let x = geo.size.width * CGFloat(idx) / CGFloat(max(values.count - 1, 1))
                            let yNorm = (value - minV) / span
                            let y = geo.size.height - (geo.size.height * CGFloat(yNorm))
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.green.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct ScoreTrendSparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            if values.count < 2 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Text("Need 2+ scores for trend")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            } else {
                let maxV = values.max() ?? 1
                let intervals = 6
                let step = niceStep(maxV / Double(intervals))
                let top = max(step * Double(intervals), step)
                let highlightedTick = floor(maxV / step) * step
                let ticks = (0...intervals).map { Double($0) * step }
                let leftAxisWidth: CGFloat = 56
                let edgePadding: CGFloat = 8
                let pointInset: CGFloat = 4
                let plotWidth = max(20, geo.size.width - leftAxisWidth - (edgePadding * 2) - (pointInset * 2))
                let plotHeight = max(20, geo.size.height - (edgePadding * 2))

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    ForEach(Array(ticks.enumerated()), id: \.offset) { _, tickValue in
                        let y = edgePadding + plotHeight - (plotHeight * CGFloat(tickValue / top))
                        let isHighlight = abs(tickValue - highlightedTick) < 0.0001 && tickValue > 0 && tickValue < top

                        Path { path in
                            path.move(to: CGPoint(x: edgePadding + leftAxisWidth, y: y))
                            path.addLine(to: CGPoint(x: edgePadding + leftAxisWidth + plotWidth, y: y))
                        }
                        .stroke(
                            isHighlight ? Color.white.opacity(0.30) : Color.white.opacity(0.16),
                            style: StrokeStyle(lineWidth: isHighlight ? 1.2 : 0.8)
                        )

                        Path { path in
                            let tickLength: CGFloat = isHighlight ? 10 : 6
                            path.move(to: CGPoint(x: edgePadding + leftAxisWidth - tickLength, y: y))
                            path.addLine(to: CGPoint(x: edgePadding + leftAxisWidth, y: y))
                        }
                        .stroke(
                            isHighlight ? Color.white.opacity(0.75) : Color.white.opacity(0.45),
                            style: StrokeStyle(lineWidth: isHighlight ? 1.4 : 1.0, lineCap: .round)
                        )

                        Text(axisLabel(for: tickValue))
                            .font(.caption2)
                            .foregroundStyle(isHighlight ? .primary : .secondary)
                            .frame(width: leftAxisWidth - 10, alignment: .trailing)
                            .position(x: edgePadding + (leftAxisWidth - 10) / 2, y: y)
                    }

                    Path { path in
                        for (idx, value) in values.enumerated() {
                            let x = edgePadding + leftAxisWidth + pointInset + (plotWidth * CGFloat(idx) / CGFloat(max(values.count - 1, 1)))
                            let yNorm = min(1, max(0, value / top))
                            let y = edgePadding + plotHeight - (plotHeight * CGFloat(yNorm))
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.cyan.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                        let x = edgePadding + leftAxisWidth + pointInset + (plotWidth * CGFloat(idx) / CGFloat(max(values.count - 1, 1)))
                        let yNorm = min(1, max(0, value / top))
                        let y = edgePadding + plotHeight - (plotHeight * CGFloat(yNorm))
                        Circle()
                            .fill(Color.cyan.opacity(0.95))
                            .frame(width: 3.5, height: 3.5)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private func niceStep(_ raw: Double) -> Double {
        let safeRaw = max(1, raw)
        let magnitude = pow(10, floor(log10(safeRaw)))
        let normalized = safeRaw / magnitude
        let niceNormalized: Double
        if normalized <= 1 {
            niceNormalized = 1
        } else if normalized <= 2 {
            niceNormalized = 2
        } else if normalized <= 5 {
            niceNormalized = 5
        } else {
            niceNormalized = 10
        }
        return niceNormalized * magnitude
    }

    private func axisLabel(for value: Double) -> String {
        if value >= 1_000_000_000 {
            let billions = value / 1_000_000_000
            let rounded = abs(billions.rounded() - billions) < 0.05 ? String(Int(billions.rounded())) : String(format: "%.1f", billions)
            return "\(rounded) bil"
        }
        if value >= 1_000_000 {
            let millions = value / 1_000_000
            let rounded = abs(millions.rounded() - millions) < 0.05 ? String(Int(millions.rounded())) : String(format: "%.1f", millions)
            return "\(rounded) mil"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}

struct HeadToHeadDeltaBars: View {
    let games: [HeadToHeadGameStats]

    var body: some View {
        GeometryReader { geo in
            let maxDelta = max(1, games.map { abs($0.meanDelta) }.max() ?? 1)
            let rowSpacing: CGFloat = 6
            let rowHeight = max(16, (geo.size.height - (CGFloat(max(games.count - 1, 0)) * rowSpacing)) / CGFloat(max(games.count, 1)))
            let totalWidth = geo.size.width
            let nameWidth = totalWidth * 0.34
            let valueWidth = totalWidth * 0.16
            let plotWidth = max(40, totalWidth - nameWidth - valueWidth - 12)
            let halfPlot = plotWidth / 2

            VStack(spacing: rowSpacing) {
                ForEach(games) { game in
                    HStack(spacing: 6) {
                        Text(game.gameName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .frame(width: nameWidth, alignment: .leading)

                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: plotWidth, height: rowHeight)

                            Rectangle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 1, height: rowHeight)
                                .offset(x: 0)

                            let ratio = min(1, abs(game.meanDelta) / maxDelta)
                            let deltaWidth = max(2, halfPlot * ratio)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(game.meanDelta >= 0 ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                                .frame(width: deltaWidth, height: rowHeight)
                                .offset(x: game.meanDelta >= 0 ? (deltaWidth / 2) : -(deltaWidth / 2))
                        }
                        .frame(width: plotWidth, alignment: .center)

                        Text(shortSigned(game.meanDelta))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(game.meanDelta >= 0 ? .green : .orange)
                            .frame(width: valueWidth, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func shortSigned(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "-" : "")
        return "\(sign)\(shortScore(abs(value)))"
    }

    private func shortScore(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return "\(String(format: "%.1f", value / 1_000_000_000))B"
        }
        if value >= 1_000_000 {
            return "\(String(format: "%.1f", value / 1_000_000))M"
        }
        if value >= 1_000 {
            return "\(String(format: "%.0f", value / 1_000))K"
        }
        return "\(Int(value.rounded()))"
    }
}
