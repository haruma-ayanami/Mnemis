import SwiftUI

/// Шрифтовые роли (ABOUT.md, раздел 23). Основной текст — SF Pro,
/// SF Mono только для IPA, счётчиков и коротких технических меток.
extension Font {
    /// Слово на карточке.
    static let mnemisWord = Font.largeTitle.bold()
    /// Транскрипция IPA.
    static let mnemisIPA = Font.body.monospaced()
    /// Счётчики и статистика.
    static let mnemisCounter = Font.title.monospacedDigit().bold()
    /// Маленькие метки вроде «TODAY».
    static let mnemisLabel = Font.caption.monospaced()
}
