import Foundation

enum RulesheetHTMLDocumentBuilder {
    static func html(for content: RulesheetRenderContent) -> String {
        let payloadJSON = (try? String(data: JSONEncoder().encode(content.body), encoding: .utf8)) ?? "\"\""
        let modeJSON = (try? String(data: JSONEncoder().encode(content.kind.rawValue), encoding: .utf8)) ?? "\"\""

        return rulesheetHTMLDocument(
            modeJSON: modeJSON,
            payloadJSON: payloadJSON
        )
    }
}
