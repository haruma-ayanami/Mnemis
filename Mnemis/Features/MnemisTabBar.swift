import SwiftUI

/// Панель вкладок из холста: стеклянная капсула 66 pt, пять пунктов по 68 pt, активный — серая подложка и точка.
/// Свёрнутая: круг у правого края с иконкой текущей вкладки (холст: Words · scrolled). Тап раскрывает её.
struct MnemisTabBar: View {
    @Binding var selection: AppTab
    var folded: Bool
    var onUnfold: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if folded { Spacer(minLength: 0) }
            capsule
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 22)
        .animation(Motion.fold, value: folded)
    }

    private var capsule: some View {
        ZStack {
            fullBar
                .fixedSize()
                .opacity(folded ? 0 : 1)
                .allowsHitTesting(!folded)
            foldedButton
                .opacity(folded ? 1 : 0)
                .allowsHitTesting(folded)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: folded ? 66 : CGFloat.infinity)
        .frame(height: 66)
        .glassPanel()
        // Тонировка одинаковая у полной панели и у круга: тёмная подложка под стеклом, чтобы текст за панелью не просвечивал.
        .background {
            Capsule().fill(AppColor.surface.opacity(0.92))
        }
    }

    private var fullBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = selection == tab
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: .regular))
                            .frame(height: 22)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                        Circle()
                            .fill(AppColor.fill)
                            .frame(width: 4, height: 4)
                            .shadow(color: selected ? AppColor.glow : .clear, radius: 3)
                            .opacity(selected ? 1 : 0)
                    }
                    .foregroundStyle(selected ? AppColor.ink : AppColor.ash)
                    .frame(width: 68, height: 54)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 27, style: .circular).fill(AppColor.glassLine)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private var foldedButton: some View {
        Button(action: onUnfold) {
            Image(systemName: selection.symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(AppColor.ink)
                .frame(width: 52, height: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(selection.title))
        .accessibilityHint(Text("Shows the tab bar"))
    }
}

extension AppTab {
    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .learn: "Learn"
        case .words: "Words"
        case .statistics: "Stats"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .learn: "rectangle.stack"
        case .words: "list.bullet"
        case .statistics: "chart.bar"
        case .settings: "slider.horizontal.3"
        }
    }
}
