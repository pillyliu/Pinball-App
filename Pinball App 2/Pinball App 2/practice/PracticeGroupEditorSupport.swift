import SwiftUI
import UIKit

struct GroupProgressWheel: View {
    let taskProgress: [StudyTaskKind: Int]
    @Environment(\.colorScheme) private var colorScheme

    private let taskColors: [StudyTaskKind: Color] = [
        .playfield: .cyan,
        .rulesheet: .blue,
        .tutorialVideo: .orange,
        .gameplayVideo: .purple,
        .practice: .green
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size / 2) - 3
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let tasks = StudyTaskKind.allCases
            let segment = 360.0 / Double(tasks.count)
            let gap = 6.0
            let trackColor = colorScheme == .dark
                ? AppTheme.brandInk.opacity(0.26)
                : AppTheme.brandInk.opacity(0.30)

            ZStack {
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    let start = -90.0 + (Double(index) * segment) + (gap / 2)
                    let end = -90.0 + (Double(index + 1) * segment) - (gap / 2)
                    let progress = Double(taskProgress[task] ?? 0) / 100.0
                    let fillEnd = start + ((end - start) * progress)

                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(start),
                            endAngle: .degrees(end),
                            clockwise: false
                        )
                    }
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))

                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(start),
                            endAngle: .degrees(fillEnd),
                            clockwise: false
                        )
                    }
                    .stroke((taskColors[task] ?? .gray).opacity(progress > 0 ? 0.95 : 0.2), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
        }
    }
}

enum GroupCreationTemplateSource: String, CaseIterable, Identifiable {
    case none
    case bank
    case duplicate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .bank: return "LPL Bank Template"
        case .duplicate: return "Duplicate Group"
        }
    }
}

enum GroupEditorDateField {
    case start
    case end
}

struct PracticeAdaptivePopoverSourceFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextValue = nextValue()
        guard nextValue != .zero else { return }
        value = nextValue
    }
}

struct PracticeAdaptivePopoverModifier<PopoverContent: View>: ViewModifier {
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
                        key: PracticeAdaptivePopoverSourceFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(PracticeAdaptivePopoverSourceFramePreferenceKey.self) { frame in
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

        let viewport = practicePopoverViewportRect()
        let spacingBuffer: CGFloat = 16
        let availableBelow = max(viewport.maxY - sourceFrame.maxY - spacingBuffer, 0)
        let availableAbove = max(sourceFrame.minY - viewport.minY - spacingBuffer, 0)
        let opensBelow = availableBelow >= preferredHeight || availableBelow >= availableAbove

        arrowEdge = opensBelow ? .top : .bottom
        availableHeight = max(opensBelow ? availableBelow : availableAbove, 0)
    }
}

extension View {
    func practiceAdaptivePopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder content: @escaping (CGFloat) -> PopoverContent
    ) -> some View {
        modifier(
            PracticeAdaptivePopoverModifier(
                isPresented: isPresented,
                preferredHeight: preferredHeight,
                popoverContent: content
            )
        )
    }
}

func practicePopoverViewportRect() -> CGRect {
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
