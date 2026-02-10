import SwiftUI

struct AppHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var horizontalPadding: CGFloat = 4
    var largeText: Bool = false

    var body: some View {
        Text(title)
            .font((largeText ? Font.footnote : Font.caption).weight(.semibold))
            .foregroundStyle(Color(white: 0.75))
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}
