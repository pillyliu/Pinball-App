import SwiftUI

struct AppToolbarFilterTriggerLabel: View {
    var body: some View {
        Image(systemName: "line.3.horizontal.decrease.circle.fill")
            .font(.title3)
            .frame(width: 34, height: 34)
            .foregroundStyle(AppTheme.shellSelectedContent)
    }
}

struct AppDropdownMenuLabel: View {
    let text: String
    let isLargeTablet: Bool
    var widestText: String? = nil
    var fillsWidth: Bool = true
    var embeddedInNavigation: Bool = false

    var body: some View {
        Group {
            if let widestText {
                ZStack {
                    labelRow(text: widestText)
                        .opacity(0)
                    labelRow(text: text)
                }
            } else {
                labelRow(text: text)
            }
        }
        .padding(.horizontal, AppLayout.dropdownHorizontalPadding(isLargeTablet: isLargeTablet))
        .padding(.vertical, AppLayout.dropdownVerticalPadding(isLargeTablet: isLargeTablet))
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            if embeddedInNavigation {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            if embeddedInNavigation {
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
            }
        }
    }

    private func labelRow(text: String) -> some View {
        HStack(spacing: AppLayout.dropdownContentSpacing) {
            Text(text)
                .lineLimit(1)
                .font(AppLayout.dropdownTextFont(isLargeTablet: isLargeTablet))
                .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
            Spacer(minLength: fillsWidth ? 0 : 4)
            Image(systemName: "chevron.down")
                .font(AppLayout.dropdownChevronFont(isLargeTablet: isLargeTablet))
                .foregroundStyle(AppTheme.shellUnselectedContent)
        }
    }
}
