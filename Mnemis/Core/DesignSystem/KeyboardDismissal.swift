import SwiftUI
import UIKit

extension View {
    /// Клавиатура закрывается везде одинаково: свайпом вниз по прокручиваемому содержимому
    /// и касанием любого свободного места экрана. Кнопки и поля ввода работают как обычно.
    func dismissesKeyboard() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { KeyboardDismissal.dismiss() }
    }

    /// Прокрутка внутри формы отзывается на свайп, даже когда содержимое короче экрана: клавиатура уходит вниз за пальцем.
    func scrollsToDismissKeyboard() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.always)
    }

    /// Пока открыта клавиатура, форму не закрыть свайпом: первый свайп убирает клавиатуру, второй закрывает лист.
    func dismissesKeyboardBeforeSheet() -> some View {
        modifier(KeyboardBeforeSheet())
    }
}

private struct KeyboardBeforeSheet: ViewModifier {
    @State private var isKeyboardUp = false

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(isKeyboardUp)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardUp = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardUp = false }
    }
}

enum KeyboardDismissal {
    /// Снимает фокус с текущего поля ввода, где бы оно ни находилось.
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
