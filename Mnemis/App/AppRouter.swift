import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case today
    case learn
    case words
    case statistics
    case settings
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

    func reselect(_ tab: AppTab) {
        reselectedTab = tab
        reselectCount += 1
    }

    func startSession() {
        selectedTab = .learn
        sessionRequest += 1
    }
}
