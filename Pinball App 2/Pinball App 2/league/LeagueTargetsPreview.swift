import SwiftUI

struct TargetsPreview: View {
    let rows: [LeagueTargetPreviewRow]
    let bankLabel: String
    let metric: LeagueTargetMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bankLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Game")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text("\(metric.title) highest")
                    .id("target-metric-\(metric.rawValue)")
                    .transition(.opacity)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(metric.color)
            }

            if rows.isEmpty {
                AppInlineStatusMessage(text: "No target preview available yet")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(rows.prefix(5).indices, id: \.self) { index in
                        let row = rows[index]
                        HStack(spacing: 8) {
                            Text(row.game)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 6)

                            Text(metric.value(for: row).leagueHubFormattedWithCommas)
                                .id("target-\(row.order)-\(metric.rawValue)")
                                .transition(.opacity)
                                .font(.footnote.monospacedDigit().weight(.semibold))
                                .foregroundStyle(metric.color)
                                .lineLimit(1)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: metric.rawValue)
    }
}
