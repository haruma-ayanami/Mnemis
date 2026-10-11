import SwiftUI

extension View {
    /// Экран поверх вкладки (настройки, карточка слова) прячет панель вкладок, пока он открыт.
    func hidesTabBar(_ router: AppRouter) -> some View {
        modifier(HidesTabBarWhileShown(router: router))
    }

    /// Любое движение списка сворачивает панель вкладок в круг; раскрывает её нажатие или возврат наверх.
    func foldsTabBarOnScroll(_ router: AppRouter) -> some View {
        modifier(FoldsTabBarOnScroll(router: router))
    }
}

private struct HidesTabBarWhileShown: ViewModifier {
    let router: AppRouter

    func body(content: Content) -> some View {
        content
            .onAppear { router.hideTabBar() }
            .onDisappear { router.showTabBar() }
    }
}

/// Любое движение списка (вверх или вниз) сворачивает панель. Раскрыть её можно нажатием в любой момент,
/// в том числе во время инерции. Мелкие движения (меньше порога) панель не трогают.
private struct FoldsTabBarOnScroll: ViewModifier {
    let router: AppRouter
    /// Точка, от которой считаем путь: после сворачивания или возврата наверх начинаем заново.
    @State private var reference: CGFloat = 0

    private static let threshold: CGFloat = 8
    /// Самый верх списка: здесь панель всегда раскрыта.
    private static let revealZone: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, new in
                if new < Self.revealZone {
                    router.setTabBarFolded(false)
                    reference = new
                } else if abs(new - reference) > Self.threshold {
                    router.foldTabBarOnScroll()
                    reference = new
                }
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { router.userStartedScrolling() }
            }
    }
}
