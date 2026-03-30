import SwiftUI
import UIKit

private struct GameRoomAdaptivePopoverSourceFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextValue = nextValue()
        guard nextValue != .zero else { return }
        value = nextValue
    }
}

private struct GameRoomAdaptivePopoverModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let preferredHeight: CGFloat
    let popoverContent: (CGFloat) -> PopoverContent

    @State private var sourceFrame: CGRect = .zero
    @State private var arrowEdge: Edge = .top
    @State private var availableHeight: CGFloat

    init(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder popoverContent: @escaping (CGFloat) -> PopoverContent
    ) {
        _isPresented = isPresented
        self.preferredHeight = preferredHeight
        self.popoverContent = popoverContent
        _availableHeight = State(initialValue: preferredHeight)
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: GameRoomAdaptivePopoverSourceFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(GameRoomAdaptivePopoverSourceFramePreferenceKey.self) { frame in
                guard frame != .zero else { return }
                sourceFrame = frame
                recalculatePlacement()
            }
            .popover(
                isPresented: $isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: arrowEdge
            ) {
                popoverContent(availableHeight)
            }
            .onAppear {
                recalculatePlacement()
            }
            .onChange(of: isPresented) { _, _ in
                recalculatePlacement()
            }
    }

    private func recalculatePlacement() {
        guard sourceFrame != .zero else {
            arrowEdge = .top
            availableHeight = preferredHeight
            return
        }

        let viewport = gameRoomPopoverViewportRect()
        let spacingBuffer: CGFloat = 16
        let availableBelow = max(viewport.maxY - sourceFrame.maxY - spacingBuffer, 0)
        let availableAbove = max(sourceFrame.minY - viewport.minY - spacingBuffer, 0)
        let opensBelow = availableBelow >= preferredHeight || availableBelow >= availableAbove

        arrowEdge = opensBelow ? .top : .bottom
        availableHeight = max(opensBelow ? availableBelow : availableAbove, 0)
    }
}

extension View {
    func gameRoomAdaptivePopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder content: @escaping (CGFloat) -> PopoverContent
    ) -> some View {
        modifier(
            GameRoomAdaptivePopoverModifier(
                isPresented: isPresented,
                preferredHeight: preferredHeight,
                popoverContent: content
            )
        )
    }
}

private func gameRoomPopoverViewportRect() -> CGRect {
    let windowScenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
    let keyWindow = windowScenes
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)

    let fallbackRect = keyWindow?.windowScene?.screen.bounds
        ?? windowScenes.first(where: { $0.activationState == .foregroundActive })?.screen.bounds
        ?? windowScenes.first?.screen.bounds
        ?? CGRect(x: 0, y: 0, width: 1024, height: 1366)
    let baseRect = keyWindow?.bounds ?? fallbackRect
    let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
    let safeAreaHeight = max(baseRect.height - safeAreaInsets.top - safeAreaInsets.bottom, 0)
    let safeAreaRect = CGRect(
        x: baseRect.minX,
        y: baseRect.minY + safeAreaInsets.top,
        width: baseRect.width,
        height: safeAreaHeight
    )
    return safeAreaRect.insetBy(dx: 0, dy: 12)
}
