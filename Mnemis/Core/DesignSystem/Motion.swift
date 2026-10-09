import SwiftUI

/// Общие кривые движения (холст: Motion-Spec). Один набор на всё приложение, чтобы экраны двигались одинаково.
enum Motion {
    /// Появление экрана и карточек: мягкая пружина без отскока.
    static let enter = Animation.spring(response: 0.5, dampingFraction: 0.88)
    /// Переход между карточками и вкладками словаря.
    static let swap = Animation.spring(response: 0.42, dampingFraction: 0.9)
    /// Скрытие и показ панели вкладок.
    static let chrome = Animation.smooth(duration: 0.45)
    /// С Reduce Motion — только короткое затухание.
    static let reduced = Animation.easeInOut(duration: 0.2)
}

extension View {
    /// Экран при каждом открытии поднимается на несколько точек и проявляется.
    /// `delay` даёт лёгкую очерёдность блокам одного экрана.
    func screenEntrance(delay: Double = 0, distance: CGFloat = 18) -> some View {
        modifier(ScreenEntrance(delay: delay, distance: distance))
    }
}

private struct ScreenEntrance: ViewModifier {
    let delay: Double
    let distance: CGFloat

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : distance)
            .onAppear {
                withAnimation((reduceMotion ? Motion.reduced : Motion.enter).delay(delay)) {
                    isVisible = true
                }
            }
            .onDisappear { isVisible = false }
    }
}
