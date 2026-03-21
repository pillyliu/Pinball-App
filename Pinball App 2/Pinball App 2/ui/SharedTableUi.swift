import SwiftUI
import UIKit

enum AppTableLayout {
    static func adjustedCellWidth(_ width: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        max(0, width - (horizontalPadding * 2))
    }
}

enum AppDividerStyle {
    static let tableHeader = AppTheme.brandChalk.opacity(0.38)
    static let tableRow = AppTheme.brandChalk.opacity(0.18)
    static let section = AppTheme.brandChalk.opacity(0.55)
}

struct AppTableHeaderDivider: View {
    var body: some View {
        Divider().overlay(AppDividerStyle.tableHeader)
    }
}

struct AppTableRowDivider: View {
    var body: some View {
        Divider().overlay(AppDividerStyle.tableRow)
    }
}

struct AppSectionDivider: View {
    var verticalPadding: CGFloat = 10

    var body: some View {
        Divider()
            .overlay(AppDividerStyle.section)
            .padding(.vertical, verticalPadding)
    }
}

struct AppHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var horizontalPadding: CGFloat = 4
    var largeText: Bool = false

    var body: some View {
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        Text(title)
            .font((largeText ? Font.footnote : Font.caption).weight(.semibold))
            .foregroundStyle(AppTheme.brandChalk)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}

struct AppSectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.brandGold, AppTheme.brandChalk],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 18)
            Text(text)
                .font(AppTheme.typography.sectionTitle)
                .foregroundStyle(AppTheme.brandInk)
            Spacer(minLength: 0)
        }
    }
}

struct AppCardSubheading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk)
    }
}

struct AppCardTitle: View {
    let text: String
    var lineLimit: Int? = nil

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AppTheme.brandInk)
            .lineLimit(lineLimit)
    }
}

struct AppMetricItem: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct AppMetricGrid: View {
    let items: [AppMetricItem]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.brandChalk)
                    Text(item.value)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.brandInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct AppInlineStatusMessage: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? .red : AppTheme.brandChalk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppInlineTaskStatus: View {
    let text: String
    var showsProgress: Bool = false
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(isError ? .red : AppTheme.brandGold)
            }
            AppInlineStatusMessage(text: text, isError: isError)
        }
    }
}

struct AppTablePlaceholder: View {
    let text: String
    var minHeight: CGFloat = 64

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppTheme.brandChalk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
    }
}

struct AppPanelStatusCard: View {
    let text: String
    var showsProgress: Bool = false
    var isError: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (isError ? Color.red : AppTheme.brandGold).opacity(0.82),
                            AppTheme.brandChalk.opacity(0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 2)

            AppInlineTaskStatus(
                text: text,
                showsProgress: showsProgress,
                isError: isError
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.panel)
                        .stroke(AppTheme.brandChalk.opacity(0.28), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous))
    }
}

struct AppPanelEmptyCard: View {
    let text: String

    var body: some View {
        AppTablePlaceholder(text: text, minHeight: 0)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandChalk.opacity(0.45), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
    }
}

enum AppNativeClearTextFieldStyle {
    case appControl
    case roundedBorder
}

enum AppNativeClearTextFieldSubmitLabel {
    case done
    case go
    case join
    case next
    case `return`
    case route
    case search
    case send
    case `continue`
}

enum AppNativeClearTextFieldAutocapitalization {
    case characters
    case words
    case sentences
    case never
}

struct AppNativeClearTextField: View {
    let placeholder: String
    @Binding var text: String
    var style: AppNativeClearTextFieldStyle = .appControl
    var keyboardType: UIKeyboardType = .default
    var submitLabel: AppNativeClearTextFieldSubmitLabel = .done
    var autocapitalization: AppNativeClearTextFieldAutocapitalization = .sentences
    var autocorrectionDisabled = false
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        switch style {
        case .appControl:
            AppNativeClearTextFieldBridge(
                placeholder: placeholder,
                text: $text,
                borderStyle: .none,
                keyboardType: keyboardType,
                submitLabel: submitLabel,
                autocapitalization: autocapitalization,
                autocorrectionDisabled: autocorrectionDisabled,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)
            .frame(height: 20)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        case .roundedBorder:
            AppNativeClearTextFieldBridge(
                placeholder: placeholder,
                text: $text,
                borderStyle: .roundedRect,
                keyboardType: keyboardType,
                submitLabel: submitLabel,
                autocapitalization: autocapitalization,
                autocorrectionDisabled: autocorrectionDisabled,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
    }
}

private struct AppNativeClearTextFieldBridge: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let borderStyle: UITextField.BorderStyle
    let keyboardType: UIKeyboardType
    let submitLabel: AppNativeClearTextFieldSubmitLabel
    let autocapitalization: AppNativeClearTextFieldAutocapitalization
    let autocorrectionDisabled: Bool
    let onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.clearButtonMode = .whileEditing
        textField.adjustsFontForContentSizeCategory = true
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        applyConfiguration(to: textField)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        applyConfiguration(to: uiView)
    }

    private func applyConfiguration(to textField: UITextField) {
        let font = UIFont.preferredFont(forTextStyle: .body)
        textField.placeholder = placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(AppTheme.brandChalk),
                .font: font
            ]
        )
        textField.font = font
        textField.textColor = UIColor(AppTheme.brandInk)
        textField.tintColor = UIColor(AppTheme.brandGold)
        textField.backgroundColor = .clear
        textField.borderStyle = borderStyle
        textField.keyboardType = keyboardType
        textField.returnKeyType = uiReturnKeyType(for: submitLabel)
        textField.autocapitalizationType = uiAutocapitalizationType(for: autocapitalization)
        textField.autocorrectionType = autocorrectionDisabled ? .no : .default
        textField.spellCheckingType = autocorrectionDisabled ? .no : .default
        textField.enablesReturnKeyAutomatically = false
    }

    private func uiReturnKeyType(for label: AppNativeClearTextFieldSubmitLabel) -> UIReturnKeyType {
        switch label {
        case .done:
            return .done
        case .go:
            return .go
        case .join:
            return .join
        case .next:
            return .next
        case .return:
            return .default
        case .route:
            return .route
        case .search:
            return .search
        case .send:
            return .send
        case .continue:
            return .continue
        }
    }

    private func uiAutocapitalizationType(for value: AppNativeClearTextFieldAutocapitalization) -> UITextAutocapitalizationType {
        switch value {
        case .characters:
            return .allCharacters
        case .words:
            return .words
        case .sentences:
            return .sentences
        case .never:
            return .none
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AppNativeClearTextFieldBridge

        init(parent: AppNativeClearTextFieldBridge) {
            self.parent = parent
        }

        @objc
        func textDidChange(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit?()
            return true
        }
    }
}
