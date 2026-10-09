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
}
