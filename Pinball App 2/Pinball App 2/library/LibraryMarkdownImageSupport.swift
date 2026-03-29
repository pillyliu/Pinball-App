import SwiftUI

struct MarkdownImageDescriptor {
    let urlString: String
    let alt: String?

    func resolvedURL(relativeTo baseURL: URL?) -> URL? {
        guard !urlString.hasPrefix("data:") else { return nil }
        if urlString.hasPrefix("//") {
            return URL(string: "https:\(urlString)")
        }
        if let absolute = URL(string: urlString), absolute.scheme != nil {
            return absolute
        }
        if let baseURL {
            return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
        }
        return URL(string: urlString)
    }

    static func first(in raw: String) -> MarkdownImageDescriptor? {
        guard let image = MarkdownImageParsing.firstImage(in: raw) else { return nil }
        return MarkdownImageDescriptor(urlString: image.url, alt: image.alt)
    }
}

struct NativeMarkdownRemoteImage: View {
    let descriptor: MarkdownImageDescriptor
    let baseURL: URL?
    var minHeight: CGFloat = 220

    var body: some View {
        if let url = descriptor.resolvedURL(relativeTo: baseURL) {
            FallbackAsyncImageView(
                candidates: [url],
                emptyMessage: descriptor.alt ?? "Image unavailable",
                contentMode: .fit
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
            )
        } else if let alt = descriptor.alt, !alt.isEmpty {
            Text(alt)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
