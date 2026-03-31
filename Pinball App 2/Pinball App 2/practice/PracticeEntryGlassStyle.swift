import SwiftUI
import UIKit

private struct PracticeEntrySheetKeyboardResetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            practiceEntryDismissKeyboard()
        }
    }
}

private func practiceEntryDismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct PracticeEntryGlassCard<Content: View>: View {
    let maxHeight: CGFloat
    let content: Content

    init(maxHeight: CGFloat = 560, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxHeight: maxHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func practiceEntrySheetStyle() -> some View {
        practiceEntrySheetStyle(detents: [.medium, .large])
    }

    func practiceEntrySheetStyle(detents: Set<PresentationDetent>) -> some View {
        modifier(PracticeEntrySheetKeyboardResetModifier())
            .appSheetChrome(detents: detents, dismissesKeyboardOnTap: false, background: .clear)
    }
}
