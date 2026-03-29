import Foundation

enum MarkdownTableAlignment {
    case left
    case center
    case right
}

struct MarkdownOrderedItem {
    let number: Int
    let text: String
}

enum MarkdownBlock {
    case anchor(String)
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([MarkdownOrderedItem])
    case blockquote([String])
    case codeBlock(language: String?, code: String)
    case horizontalRule
    case image(url: String, alt: String?)
    case table(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
}
