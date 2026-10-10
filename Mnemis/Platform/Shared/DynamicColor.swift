import SwiftUI
import UIKit

extension Color {
    /// Цвет, который сам переключается между светлой и тёмной темой.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Цвет с прозрачностью для обеих тем: токены стекла и линий из холста (`rgba(...)`).
    static func dynamic(light: (UInt32, Double), dark: (UInt32, Double)) -> Color {
        Color(UIColor { traits in
            let (hex, alpha) = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex, alpha: alpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}
