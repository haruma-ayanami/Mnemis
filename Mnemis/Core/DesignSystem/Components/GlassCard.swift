import SwiftUI

/// Стекло по формуле холста (`.glass`): градиент из токенов, блик слева вверху, тонкая граница и тень.
/// Системный Liquid Glass на тёмном фоне светлее, поэтому здесь свой, тот же, что в дизайне.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content.background {
            shape
                .fill(LinearGradient(colors: [AppColor.glassTop, AppColor.glassBottom], startPoint: .top, endPoint: .bottom))
                .shadow(color: AppColor.glassShadow, radius: 24, x: 0, y: 12)
                .overlay {
                    shape.fill(RadialGradient(colors: [AppColor.glassSpec, .clear], center: UnitPoint(x: 0.15, y: 0), startRadius: 0, endRadius: 240))
                }
                .overlay {
                    shape.stroke(AppColor.glassLine, lineWidth: 1)
                }
                .overlay {
                    // Внутренний блик по верхнему краю: `inset 0 1px 0 var(--hl)`.
                    shape.stroke(AppColor.glassHighlight, lineWidth: 1)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.15)))
                }
        }
    }
}

extension View {
    /// Стеклянная карточка с круговыми углами, как в холсте.
    func glassCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .circular)))
    }

    func glassCapsule() -> some View {
        modifier(GlassSurface(shape: Capsule()))
    }

    func glassCircle() -> some View {
        modifier(GlassSurface(shape: Circle()))
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
