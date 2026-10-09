import SwiftUI

extension View {
    /// Liquid Glass на карточке или панели. Стекло только на плавающих слоях, не на фоне.
    func glassCard(cornerRadius: CGFloat = 28) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    func glassCapsule() -> some View {
        self.glassEffect(.regular, in: .capsule)
    }

    func glassCircle() -> some View {
        self.glassEffect(.regular, in: .circle)
    }

    /// Декор на заднем плане: не влияет на раскладку и не выходит за пределы экрана.
    func decor<D: View>(alignment: Alignment = .center, @ViewBuilder _ decor: () -> D) -> some View {
        self.background(alignment: alignment) { decor() }.clipped()
    }

    /// ASCII-уголки `┌ ┐ └ ┘` помечают главную карточку экрана.
    func cornerMarks(inset: CGFloat = 12) -> some View {
        self.overlay {
            ZStack {
                Text("┌").position(x: inset + 4, y: inset + 4)
                Text("┐").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(inset - 4)
                Text("└").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(inset - 4)
                Text("┘").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(inset - 4)
            }
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(AppColor.faint)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Тонкая подпись-разделитель `──── · ────`.
struct AsciiDivider: View {
    var body: some View {
        Text("──── · ────")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(AppColor.faint)
            .accessibilityHidden(true)
    }
}

/// Слой декора: занимает ровно предложенное место, а содержимое только рисуется и обрезается по краям.
/// Нужен, чтобы широкие сферы и кольца не растягивали раскладку экрана.
struct DecorLayer<Content: View>: View {
    var alignment: Alignment = .center
    @ViewBuilder var content: Content

    var body: some View {
        Color.clear
            .overlay(alignment: alignment) { content }
            .clipped()
            .allowsHitTesting(false)
    }
}
