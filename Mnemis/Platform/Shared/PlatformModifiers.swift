import SwiftUI
import UIKit

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
    /// Со скрытой панелью система отключает возврат свайпом от левого края, поэтому жест включается заново.
    func mnemisNavigationBarHidden() -> some View {
        toolbar(.hidden, for: .navigationBar)
            .background(SwipeBackEnabler())
    }
}

/// Невидимый помощник: возвращает экрану жест «свайп слева направо — назад» при скрытой панели навигации.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = SwipeBackDelegate.shared
        }
    }
}

/// Разрешает жест, когда в стеке есть куда возвращаться; на корневом экране жест не начинается.
private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackDelegate()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = gestureRecognizer.view
        while let current = responder {
            if let navigation = current as? UINavigationController {
                return navigation.viewControllers.count > 1
            }
            responder = current.next
        }
        return false
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
