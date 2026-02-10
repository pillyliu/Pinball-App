import SwiftUI

struct AppHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var horizontalPadding: CGFloat = 4
    var largeText: Bool = false

    var body: some View {
        let adjustedWidth = max(0, width - (horizontalPadding * 2))
        Text(title)
            .font((largeText ? Font.footnote : Font.caption).weight(.semibold))
            .foregroundStyle(Color(white: 0.75))
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}
