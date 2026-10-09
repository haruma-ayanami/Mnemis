import SwiftUI

/// Цветовые токены из дизайна: тёмная и светлая темы. Акцент один — зелёный.
/// Статусы слов различаются яркостью, а не оттенком.
enum AppColor {
    static let background = Color(light: 0xF1F1EC, dark: 0x0A0A0B)
    static let surface = Color(light: 0xFFFFFF, dark: 0x141416)
    static let ink = Color(light: 0x111113, dark: 0xF2F2F0)
    static let ash = Color(light: 0x4F4F4A, dark: 0xA3A3A0)
    static let smoke = Color(light: 0x66665F, dark: 0x8F8F8C)
    static let faint = Color(light: 0xA6A69F, dark: 0x5C5C5A)

    /// Зелёный для текста и значков: Moss на светлом, Phosphor на тёмном.
    static let accent = Color(light: 0x157A40, dark: 0x4CE38A)
    /// Зелёный для заливок: Leaf на светлом, Phosphor на тёмном.
    static let fill = Color(light: 0x34C873, dark: 0x4CE38A)
    static let onFill = Color(light: 0x03140A, dark: 0x03140A)
    static let glow = Color(light: 0x34C873, dark: 0x4CE38A)

    static let primary = Color(light: 0x111113, dark: 0xF2F2F0)
    static let onPrimary = Color(light: 0xF6F6F2, dark: 0x0A0A0B)

    static let hairline = Color.primary.opacity(0.10)
    static let toggleOff = Color(light: 0xD6D6D0, dark: 0x3A3A3C)

    // Шкала памяти: чем лучше слово запомнено, тем контрастнее точка.
    static let statusLearning = Color(light: 0xC9C9C2, dark: 0x5C5C5A)
    static let statusReviewing = Color(light: 0x8A8A83, dark: 0xA3A3A0)
    static let statusRemembered = Color(light: 0x1A1A1B, dark: 0xF2F2F0)
}
