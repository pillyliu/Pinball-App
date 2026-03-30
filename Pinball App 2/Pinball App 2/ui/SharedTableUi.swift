import SwiftUI
import UIKit

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
