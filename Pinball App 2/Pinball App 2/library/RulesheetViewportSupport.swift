import CoreGraphics

struct RulesheetViewportLayoutSnapshot: Decodable {
    let viewWidth: Double
    let viewHeight: Double
    let contentHeight: Double
    let scrollY: Double
}

struct RulesheetNativeViewportLayoutSnapshot {
    let webViewSize: CGSize
    let scrollViewSize: CGSize
    let contentHeight: CGFloat
    let contentOffsetY: CGFloat
}

struct RulesheetCombinedViewportLayoutSnapshot {
    let dom: RulesheetViewportLayoutSnapshot
    let native: RulesheetNativeViewportLayoutSnapshot
}

enum RulesheetViewportRestoreSupport {
    static func layoutIsStable(
        previous: RulesheetCombinedViewportLayoutSnapshot,
        current: RulesheetCombinedViewportLayoutSnapshot
    ) -> Bool {
        abs(previous.dom.viewWidth - current.dom.viewWidth) <= 1 &&
        abs(previous.dom.viewHeight - current.dom.viewHeight) <= 1 &&
        abs(previous.dom.contentHeight - current.dom.contentHeight) <= 1 &&
        abs(previous.dom.scrollY - current.dom.scrollY) <= 1 &&
        abs(previous.native.webViewSize.width - current.native.webViewSize.width) <= 1 &&
        abs(previous.native.webViewSize.height - current.native.webViewSize.height) <= 1 &&
        abs(previous.native.scrollViewSize.width - current.native.scrollViewSize.width) <= 1 &&
        abs(previous.native.scrollViewSize.height - current.native.scrollViewSize.height) <= 1 &&
        abs(previous.native.contentHeight - current.native.contentHeight) <= 1 &&
        abs(previous.native.contentOffsetY - current.native.contentOffsetY) <= 1
    }

    static func layoutIsCoherent(_ snapshot: RulesheetCombinedViewportLayoutSnapshot) -> Bool {
        abs(snapshot.dom.viewWidth - snapshot.native.webViewSize.width) <= 2 &&
        abs(snapshot.dom.viewHeight - snapshot.native.webViewSize.height) <= 2 &&
        abs(snapshot.dom.viewWidth - snapshot.native.scrollViewSize.width) <= 2 &&
        abs(snapshot.dom.viewHeight - snapshot.native.scrollViewSize.height) <= 2 &&
        abs(snapshot.dom.contentHeight - snapshot.native.contentHeight) <= 24 &&
        abs(snapshot.dom.scrollY - snapshot.native.contentOffsetY) <= 24
    }

    static func stateChanged(
        baseline: RulesheetCombinedViewportLayoutSnapshot,
        current: RulesheetCombinedViewportLayoutSnapshot
    ) -> Bool {
        abs(baseline.dom.viewWidth - current.dom.viewWidth) > 1 ||
        abs(baseline.dom.viewHeight - current.dom.viewHeight) > 1 ||
        abs(baseline.dom.contentHeight - current.dom.contentHeight) > 1 ||
        abs(baseline.dom.scrollY - current.dom.scrollY) > 24 ||
        abs(baseline.native.contentOffsetY - current.native.contentOffsetY) > 24
    }
}
