import SwiftUI
import UIKit

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
