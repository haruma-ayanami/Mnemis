import SwiftUI

enum AppTab: Hashable, CaseIterable, Identifiable {
    case today
    case learn
    case words
    case statistics
    case settings

    var id: Self { self }
}

/// Состояние навигации верхнего уровня: какая вкладка открыта и показан ли онбординг.
@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .today
    var isOnboarded = false
    var colorScheme: ColorScheme?

    /// Повторное нажатие на активную вкладку (например, два тапа по «Words»): экран прокручивается к началу.
    private(set) var reselectedTab: AppTab?
    private(set) var reselectCount = 0

    /// Запрос «сразу начать сессию» (кнопка Start session на Today, уведомление о повторении).
    /// Learn открывает сессию поверх вкладки, когда видит новое значение.
    private(set) var sessionRequest = 0

    /// Новый день или возврат в приложение: экраны с дневными счётчиками перечитывают данные.
    private(set) var refreshRequest = 0

    /// Панель вкладок: сколько открытых экранов её прячут (вложенные экраны Настроек, карточка слова).
    private(set) var tabBarHiddenDepth = 0
    /// Панель свёрнута в круг у правого края: так при прокрутке вниз занимается меньше места.
    private(set) var isTabBarFolded = false

    var isTabBarVisible: Bool { tabBarHiddenDepth == 0 }

    func hideTabBar() { tabBarHiddenDepth += 1 }

    func showTabBar() { tabBarHiddenDepth = max(0, tabBarHiddenDepth - 1) }

    /// Пользователь раскрыл панель во время инерции списка: до нового касания прокрутка её не сворачивает.
    private(set) var foldSuppressed = false

    /// Прокрутка сворачивает панель, если её не раскрыли во время инерции.
    func foldTabBarOnScroll() {
        guard !foldSuppressed else { return }
        setTabBarFolded(true)
    }

    /// Раскрытие по нажатию на круг работает и во время инерции списка.
    func expandTabBarByUser() {
        foldSuppressed = true
        setTabBarFolded(false)
    }

    /// Новое касание пальцем снова разрешает сворачивание при прокрутке.
    func userStartedScrolling() {
        foldSuppressed = false
    }

    func setTabBarFolded(_ folded: Bool) {
        guard folded != isTabBarFolded else { return }
        isTabBarFolded = folded
    }

    func reselect(_ tab: AppTab) {
        reselectedTab = tab
        reselectCount += 1
    }

    func startSession() {
        selectedTab = .learn
        sessionRequest += 1
    }

    func requestRefresh() {
        refreshRequest += 1
    }
}
