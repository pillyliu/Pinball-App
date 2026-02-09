import SwiftUI

private func isValidLeftEdgeBackSwipe(_ value: DragGesture.Value) -> Bool {
    value.startLocation.x < 28 &&
    value.translation.width > 80 &&
    abs(value.translation.height) < 90
}

extension View {
    func appEdgeBackGesture(dismiss: DismissAction) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 14).onEnded { value in
                guard isValidLeftEdgeBackSwipe(value) else { return }
                dismiss()
            }
        )
    }
}
