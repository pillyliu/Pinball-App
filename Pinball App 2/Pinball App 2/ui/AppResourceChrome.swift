import SwiftUI

@ViewBuilder
func PinballResourceRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(alignment: .center, spacing: 8) {
        Text("\(title):")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
    }
}

@ViewBuilder
func PinballUnavailableResourceChip(_ title: String = "Unavailable") -> some View {
    Text(title)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.secondary.opacity(0.9))
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .opacity(0.7)
        .allowsHitTesting(false)
}

func PinballShortRulesheetTitle(for link: PinballGame.ReferenceLink) -> String {
    let label = link.label.lowercased()
    if label.contains("(tf)") { return "TF" }
    if label.contains("(pp)") { return "PP" }
    if label.contains("(papa)") { return "PAPA" }
    if label.contains("(bob)") { return "Bob" }
    if label.contains("(local)") || label.contains("(source)") { return "Local" }
    if link.destinationURL == nil && link.embeddedRulesheetSource == nil { return "Local" }
    return "Local"
}

@ViewBuilder
func PinballMediaPreviewPlaceholder(
    message: String? = nil,
    showsProgress: Bool = false
) -> some View {
    ZStack {
        Color(uiColor: .tertiarySystemBackground)

        VStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
    }
}
