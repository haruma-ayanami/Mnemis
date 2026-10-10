import SwiftUI

/// Панель вкладок из холста: стеклянная капсула 66 pt, пять пунктов по 68 pt, активный — серая подложка и точка.
struct MnemisTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
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
        .padding(.horizontal, 7)
        .frame(height: 66)
        .glassCapsule()
        .padding(.horizontal, 14)
        .padding(.bottom, 22)
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
