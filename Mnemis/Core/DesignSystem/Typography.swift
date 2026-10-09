import SwiftUI

/// Шрифтовые роли (ABOUT.md, раздел 23). Основной текст — SF Pro (системный),
/// SF Mono — только для IPA, счётчиков и коротких технических меток.
extension Font {
    /// Слово на карточке.
    static let mnemisWord = Font.system(size: 46, weight: .semibold)
    static let mnemisWordLarge = Font.system(size: 54, weight: .semibold)
    /// Заголовок экрана.
    static let mnemisTitle = Font.system(size: 34, weight: .semibold)
    /// Транскрипция IPA.
    static let mnemisIPA = Font.system(size: 16, design: .monospaced)
    /// Счётчики и статистика.
    static let mnemisCounter = Font.system(size: 26, weight: .medium, design: .monospaced)
    static let mnemisCounterLarge = Font.system(size: 64, weight: .medium, design: .monospaced)
    /// Короткие метки вроде «[ word of the day ]».
    static let mnemisLabel = Font.system(size: 11, design: .monospaced)
}

extension View {
    /// Подпись в квадратных скобках, как в дизайне: `[ word of the day ]`.
    func bracketLabel(_ color: Color = AppColor.smoke) -> some View {
        self
            .font(.mnemisLabel)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Плотный трекинг для крупных слов.
    func wordTracking() -> some View {
        self.tracking(-1.6)
    }
}
