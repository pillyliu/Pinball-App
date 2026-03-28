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

struct AppCardTitleWithVariant: View {
    let text: String
    let variant: String?
    var lineLimit: Int = 2

    private var resolvedVariant: String? {
        let trimmed = variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        if let resolvedVariant {
            AppInlineTitleWithVariantLabel(
                title: text,
                variant: resolvedVariant,
                lineLimit: lineLimit,
                style: .card
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            AppCardTitle(text: text, lineLimit: lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum AppInlineTitleWithVariantStyle {
    case card
    case overlay
}

struct AppInlineTitleWithVariantLabel: UIViewRepresentable {
    let title: String
    let variant: String?
    var lineLimit: Int = 2
    var style: AppInlineTitleWithVariantStyle = .card

    func makeUIView(context: Context) -> AppInlineTitleWithVariantUILabel {
        let label = AppInlineTitleWithVariantUILabel()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: AppInlineTitleWithVariantUILabel, context: Context) {
        uiView.configure(
            title: title,
            variant: variant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            lineLimit: lineLimit,
            style: style
        )
        uiView.accessibilityLabel = variant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty.map {
            "\(title), \($0)"
        } ?? title
    }
}

private struct AppInlineTitleAppearance {
    let titleFont: UIFont
    let titleColor: UIColor
    let titleShadow: NSShadow?
    let pillFont: UIFont
    let pillForeground: UIColor
    let pillFill: UIColor
    let pillStroke: UIColor
    let pillHorizontalPadding: CGFloat
    let pillVerticalPadding: CGFloat
    let pillAttachmentVerticalInset: CGFloat
}

private extension AppInlineTitleWithVariantStyle {
    var appearance: AppInlineTitleAppearance {
        switch self {
        case .card:
            return AppInlineTitleAppearance(
                titleFont: .preferredFont(forTextStyle: .headline),
                titleColor: UIColor(AppTheme.brandInk),
                titleShadow: nil,
                pillFont: UIFont.preferredFont(forTextStyle: .footnote).withWeight(.semibold),
                pillForeground: UIColor(AppTheme.brandInk),
                pillFill: UIColor(AppTheme.brandGold).withAlphaComponent(0.16),
                pillStroke: UIColor(AppTheme.brandGold).withAlphaComponent(0.34),
                pillHorizontalPadding: 8,
                pillVerticalPadding: 3,
                pillAttachmentVerticalInset: 0
            )
        case .overlay:
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(1.0)
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = CGSize(width: 0, height: 3)
            return AppInlineTitleAppearance(
                titleFont: UIFont.systemFont(ofSize: 16, weight: .semibold),
                titleColor: .white,
                titleShadow: shadow,
                pillFont: UIFont.preferredFont(forTextStyle: .footnote).withWeight(.semibold),
                pillForeground: .white,
                pillFill: UIColor(AppTheme.brandGold).withAlphaComponent(0.20),
                pillStroke: UIColor(AppTheme.brandGold).withAlphaComponent(0.42),
                pillHorizontalPadding: 8,
                pillVerticalPadding: 2,
                pillAttachmentVerticalInset: 0
            )
        }
    }
}

final class AppInlineTitleWithVariantUILabel: UILabel {
    private var storedTitle = ""
    private var storedVariant: String?
    private var storedLineLimit = 2
    private var storedStyle: AppInlineTitleWithVariantStyle = .card
    private var lastAppliedSignature = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyCurrentContentIfNeeded()
    }

    func configure(
        title: String,
        variant: String?,
        lineLimit: Int,
        style: AppInlineTitleWithVariantStyle
    ) {
        storedTitle = title
        storedVariant = variant
        storedLineLimit = lineLimit
        storedStyle = style
        numberOfLines = lineLimit
        lineBreakMode = .byTruncatingTail
        applyCurrentContentIfNeeded(force: true)
    }

    private func applyCurrentContentIfNeeded(force: Bool = false) {
        let availableWidth = max(bounds.width, preferredMaxLayoutWidth)
        guard availableWidth > 0 else { return }
        let signature = "\(availableWidth)|\(storedTitle)|\(storedVariant ?? "")|\(storedLineLimit)|\(storedStyle)"
        guard force || signature != lastAppliedSignature else { return }
        lastAppliedSignature = signature
        preferredMaxLayoutWidth = availableWidth
        attributedText = makeAttributedText(maxWidth: availableWidth)
        invalidateIntrinsicContentSize()
    }

    private func makeAttributedText(maxWidth: CGFloat) -> NSAttributedString {
        guard let variant = storedVariant, !variant.isEmpty else {
            return baseAttributedText(storedTitle)
        }

        let resolved = resolveBestInlineLayout(maxWidth: maxWidth, variant: variant)
        return combinedAttributedText(title: resolved.title, variant: resolved.variant)
    }

    private func resolveBestInlineLayout(maxWidth: CGFloat, variant: String) -> (title: String, variant: String) {
        var bestTitleChars = -1
        var bestVariantChars = -1
        var bestTitle = storedTitle
        var bestVariant = variant

        for candidate in inlinePillCandidates(for: variant) {
            let visibleTitleChars = maxVisibleTitleCharacters(maxWidth: maxWidth, variant: candidate.label)
            if visibleTitleChars > bestTitleChars ||
                (visibleTitleChars == bestTitleChars && candidate.visibleCharacters > bestVariantChars) {
                bestTitleChars = visibleTitleChars
                bestVariantChars = candidate.visibleCharacters
                bestTitle = truncatedCandidateTitle(visibleCharacters: visibleTitleChars)
                bestVariant = candidate.label
            }
            if visibleTitleChars >= storedTitle.count && candidate.visibleCharacters >= variant.count {
                break
            }
        }

        return (bestTitle, bestVariant)
    }

    private func maxVisibleTitleCharacters(maxWidth: CGFloat, variant: String) -> Int {
        if combinedFits(title: storedTitle, variant: variant, maxWidth: maxWidth) {
            return storedTitle.count
        }
        var low = 0
        var high = storedTitle.count
        while low < high {
            let mid = (low + high + 1) / 2
            if combinedFits(title: truncatedCandidateTitle(visibleCharacters: mid), variant: variant, maxWidth: maxWidth) {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    private func combinedFits(title: String, variant: String, maxWidth: CGFloat) -> Bool {
        let attributed = combinedAttributedText(title: title, variant: variant)
        let measured = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let maxHeight = ceil(storedStyle.appearance.titleFont.lineHeight * CGFloat(max(storedLineLimit, 1)))
        return ceil(measured.height) <= maxHeight
    }

    private func truncatedCandidateTitle(visibleCharacters: Int) -> String {
        guard visibleCharacters < storedTitle.count else { return storedTitle }
        let prefix = String(storedTitle.prefix(visibleCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? "…" : "\(prefix)…"
    }

    private func baseAttributedText(_ title: String) -> NSAttributedString {
        let appearance = storedStyle.appearance
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.minimumLineHeight = appearance.titleFont.lineHeight
        paragraphStyle.maximumLineHeight = appearance.titleFont.lineHeight
        var attributes: [NSAttributedString.Key: Any] = [
            .font: appearance.titleFont,
            .foregroundColor: appearance.titleColor,
            .paragraphStyle: paragraphStyle,
        ]
        if let shadow = appearance.titleShadow {
            attributes[.shadow] = shadow
        }
        return NSAttributedString(
            string: title,
            attributes: attributes
        )
    }

    private func combinedAttributedText(title: String, variant: String) -> NSAttributedString {
        let combined = NSMutableAttributedString(attributedString: baseAttributedText(title))
        combined.append(NSAttributedString(string: " ", attributes: [.font: storedStyle.appearance.titleFont]))
        combined.append(NSAttributedString(attachment: pillAttachment(for: variant)))
        return combined
    }

    private func pillAttachment(for text: String) -> NSTextAttachment {
        let appearance = storedStyle.appearance
        let attributes: [NSAttributedString.Key: Any] = [
            .font: appearance.pillFont,
            .foregroundColor: appearance.pillForeground,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let pillSize = CGSize(
            width: ceil(textSize.width) + (appearance.pillHorizontalPadding * 2),
            height: ceil(textSize.height) + (appearance.pillVerticalPadding * 2)
        )
        let canvasSize = CGSize(
            width: pillSize.width,
            height: pillSize.height + (appearance.pillAttachmentVerticalInset * 2)
        )
        let pillRect = CGRect(
            x: 0,
            y: appearance.pillAttachmentVerticalInset,
            width: pillSize.width,
            height: pillSize.height
        ).integral
        let image = UIGraphicsImageRenderer(size: canvasSize).image { _ in
            let pathRect = pillRect.insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: pathRect, cornerRadius: pathRect.height / 2)
            appearance.pillFill.setFill()
            path.fill()
            appearance.pillStroke.setStroke()
            path.lineWidth = 0.8
            path.stroke()

            let textRect = CGRect(
                x: appearance.pillHorizontalPadding,
                y: pillRect.minY + ((pillRect.height - ceil(textSize.height)) / 2),
                width: ceil(textSize.width),
                height: ceil(textSize.height)
            )
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        let baselineOffset = floor((appearance.titleFont.capHeight - pillRect.height) / 2)
        attachment.bounds = CGRect(
            x: 0,
            y: baselineOffset,
            width: canvasSize.width,
            height: canvasSize.height
        )
        return attachment
    }

    private func inlinePillCandidates(for variant: String) -> [(label: String, visibleCharacters: Int)] {
        let trimmed = variant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var candidates: [(label: String, visibleCharacters: Int)] = []
        for visibleCharacters in stride(from: trimmed.count, through: 1, by: -1) {
            let label: String
            if visibleCharacters == trimmed.count {
                label = trimmed
            } else {
                let prefix = String(trimmed.prefix(visibleCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
                label = prefix.isEmpty ? "…" : "\(prefix)…"
            }
            if candidates.last?.label != label {
                candidates.append((label, visibleCharacters))
            }
        }
        return candidates
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
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
