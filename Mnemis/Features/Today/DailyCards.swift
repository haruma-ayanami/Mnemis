import SwiftUI

/// Что показывает карточка дня: слово дня или идиома дня из личного списка (ABOUT.md, раздел 5).
enum DailyCardTab: String, CaseIterable, Identifiable {
    case word
    case phrase

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .word: "Word"
        case .phrase: "Idiom"
        }
    }
}

/// Переключатель «Word | Idiom» над карточкой дня.
struct DailyCardTabs: View {
    @Binding var selection: DailyCardTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DailyCardTab.allCases) { tab in
                let selected = selection == tab
                Button { withAnimation(Motion.swap) { selection = tab } } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(selected ? AppColor.ink : AppColor.ash)
                        .frame(width: 68, height: 28)
                        .background {
                            if selected {
                                Capsule().fill(AppColor.glassLine).matchedGeometryEffect(id: "daily-pill", in: pill)
                            }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(AppColor.track, in: .capsule)
    }
}
