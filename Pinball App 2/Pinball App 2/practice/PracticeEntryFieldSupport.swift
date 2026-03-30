import SwiftUI

@ViewBuilder
func practiceEntryStyledTextField(
    _ placeholder: String,
    text: Binding<String>,
    axis: Axis = .horizontal,
    keyboard: UIKeyboardType = .default,
    textAlignment: TextAlignment = .leading,
    monospacedDigits: Bool = false
) -> some View {
    let field = TextField(placeholder, text: text, axis: axis)
        .font(.subheadline)
        .keyboardType(keyboard)
        .lineLimit(axis == .vertical ? 2 ... 4 : 1 ... 1)
        .multilineTextAlignment(textAlignment)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .appControlStyle()
    if monospacedDigits { field.monospacedDigit() } else { field }
}

@ViewBuilder
func practiceEntryStyledMultilineTextEditor(_ placeholder: String, text: Binding<String>) -> some View {
    ZStack(alignment: .topLeading) {
        if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(placeholder)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .allowsHitTesting(false)
        }
        TextEditor(text: text)
            .font(.subheadline)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }
    .frame(minHeight: 88, maxHeight: 96)
    .appControlStyle()
}

func practiceEntrySliderRow(title: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text(title)
            Spacer()
            Text("\(Int(value.wrappedValue.rounded()))%")
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        Slider(value: value, in: 0...100, step: 1)
            .tint(.white.opacity(0.92))
            .padding(.horizontal, 2)
    }
}
