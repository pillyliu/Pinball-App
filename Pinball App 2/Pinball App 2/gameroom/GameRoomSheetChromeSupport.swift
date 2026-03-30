import SwiftUI

extension View {
    func gameRoomEntrySheetStyle() -> some View {
        appSheetChrome(detents: [.medium, .large], background: .clear)
    }

    func gameRoomMediaSheetStyle() -> some View {
        appSheetChrome(detents: [.medium, .large], background: .clear)
    }
}
