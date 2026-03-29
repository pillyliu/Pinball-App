import SwiftUI

struct RulesheetProgressStore {
    let gameID: String

    private var storageKey: String {
        "rulesheet-last-progress-\(gameID)"
    }

    func load() -> CGFloat? {
        guard let number = UserDefaults.standard.object(forKey: storageKey) as? NSNumber else {
            return nil
        }
        return min(max(CGFloat(number.doubleValue), 0), 1)
    }

    func save(_ progress: CGFloat) {
        UserDefaults.standard.set(Double(progress), forKey: storageKey)
    }
}

struct RulesheetScreenLayoutMetrics {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    private let landscapeTopOffset: CGFloat = 17
    private let rulesheetHorizontalPadding: CGFloat = 16
    private let rulesheetMaxContentWidth: CGFloat = 44 * 16

    var isPortrait: Bool {
        size.height >= size.width
    }

    var topInset: CGFloat {
        max(safeAreaInsets.top, 44)
    }

    var anchorScrollInset: CGFloat {
        topInset + 12
    }

    var fullscreenChromeRowHeight: CGFloat {
        50
    }

    var backButtonTopPadding: CGFloat {
        isPortrait ? (topInset + 12) : landscapeTopOffset
    }

    var progressPillTopPadding: CGFloat {
        isPortrait ? backButtonTopPadding : landscapeTopOffset
    }

    var progressRowHeight: CGFloat? {
        isPortrait ? fullscreenChromeRowHeight : nil
    }

    var progressPillTrailingInset: CGFloat {
        let availableBodyWidth = max(size.width - (rulesheetHorizontalPadding * 2), 0)
        let renderedContentWidth = min(availableBodyWidth, rulesheetMaxContentWidth)
        return rulesheetHorizontalPadding + max((availableBodyWidth - renderedContentWidth) / 2, 0)
    }
}
