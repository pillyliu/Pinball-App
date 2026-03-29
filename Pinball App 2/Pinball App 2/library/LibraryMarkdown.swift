import SwiftUI

struct NativeMarkdownView: View {
    let markdown: String
    var baseURL: URL? = nil

    private var blocks: [NativeMarkdownDocumentBlock] {
        NativeMarkdownDocumentBuilder.build(from: markdown)
    }

    var body: some View {
        NativeMarkdownDocumentView(blocks: blocks, baseURL: baseURL)
    }
}

struct NativeMarkdownDocumentView: View {
    let blocks: [NativeMarkdownDocumentBlock]
    var baseURL: URL? = nil
    var onBlockFramesChange: (([String: CGRect]) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                NativeMarkdownBlockView(block: block, baseURL: baseURL)
                    .id(block.id)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MarkdownBlockFramePreferenceKey.self,
                                value: [block.id: proxy.frame(in: .named(Self.coordinateSpaceName))]
                            )
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .onPreferenceChange(MarkdownBlockFramePreferenceKey.self) { frames in
            onBlockFramesChange?(frames)
        }
    }

    static let coordinateSpaceName = "NativeMarkdownDocumentView"
}
