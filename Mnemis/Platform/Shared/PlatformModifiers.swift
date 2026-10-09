import SwiftUI

// Модификаторы iPhone (iOS 27+). Платформенные различия живут здесь, а не в экранах (ARCHITECTURE.md, раздел 12).

enum MnemisFeedback {
    case selection
    case light
    case success
}

extension View {
    /// Тактильный отклик при изменении значения.
    func mnemisHaptic<T: Equatable>(_ feedback: MnemisFeedback, trigger: T) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger))
    }

    /// Отключает автозаглавные буквы в полях ввода слов.
    func mnemisNoAutocapitalization() -> some View {
        textInputAutocapitalization(.never)
    }

    /// Скрывает системную панель навигации: заголовки рисуем сами.
    func mnemisNavigationBarHidden() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }
}

private struct HapticModifier<T: Equatable>: ViewModifier {
    let feedback: MnemisFeedback
    let trigger: T

    func body(content: Content) -> some View {
        switch feedback {
        case .selection: content.sensoryFeedback(.selection, trigger: trigger)
        case .light: content.sensoryFeedback(.impact(weight: .light), trigger: trigger)
        case .success: content.sensoryFeedback(.success, trigger: trigger)
        }
    }
}
