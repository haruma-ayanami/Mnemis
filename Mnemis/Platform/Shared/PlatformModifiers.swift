import SwiftUI

// Платформенные различия живут здесь, а не в экранах (ARCHITECTURE.md, раздел 12).

extension View {
    /// Отключает автозаглавные буквы в полях ввода слов. На macOS модификатора нет, поэтому ничего не делаем.
    func mnemisNoAutocapitalization() -> some View {
        modifier(NoAutocapitalizationModifier())
    }

    /// Скрывает системную панель навигации: заголовки рисуем сами. На macOS её нет.
    func mnemisNavigationBarHidden() -> some View {
        modifier(NavigationBarHiddenModifier())
    }

    /// Скрывает панель вкладок в режиме фокуса (сессия обучения). На macOS панели вкладок нет.
    func mnemisTabBarHidden(_ hidden: Bool) -> some View {
        modifier(TabBarVisibilityModifier(hidden: hidden))
    }
}

private struct NoAutocapitalizationModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.textInputAutocapitalization(.never)
        #else
        content
        #endif
    }
}

private struct TabBarVisibilityModifier: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar(hidden ? .hidden : .automatic, for: .tabBar)
        #else
        content
        #endif
    }
}

private struct NavigationBarHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar(.hidden, for: .navigationBar)
        #else
        content
        #endif
    }
}
