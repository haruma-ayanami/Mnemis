import SwiftUI

/// Основная кнопка: плотная заливка цветом текста, инвертированный текст.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(AppColor.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColor.primary, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Стеклянная кнопка второго уровня.
struct GlassButtonStyle: ButtonStyle {
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .glassCapsule()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Текстовая кнопка без фона.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppColor.ash)
            .frame(maxWidth: .infinity, minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Круглая стеклянная кнопка с иконкой, 44 pt.
struct RoundGlassButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(AppColor.ink)
                .frame(width: size, height: size)
                .glassCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Фон экрана: цвет темы.
extension View {
    func screenBackground() -> some View {
        self.background(AppColor.background.ignoresSafeArea())
    }
}
