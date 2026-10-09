import CoreGraphics

/// Отступы в одном месте, чтобы экраны выглядели одинаково.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    /// Минимальная высота касаемой области (Apple HIG, раздел 24 ABOUT.md).
    static let touchTarget: CGFloat = 44
}
