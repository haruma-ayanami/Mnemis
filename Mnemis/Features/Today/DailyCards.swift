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
                        .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                        .padding(.horizontal, 14).frame(minHeight: 32)
                        .background {
                            if selected {
                                Capsule().fill(AppColor.primary).matchedGeometryEffect(id: "daily-pill", in: pill)
                            }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .glassCapsule()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Идиома дня из личного списка.
struct PhraseCard: View {
    let phrase: Phrase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("[ idiom of the day ]")
                .bracketLabel(AppColor.accent)
            Text(phrase.text)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("──── · ────")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColor.faint)
                .accessibilityHidden(true)
            Text(phrase.meaning)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let example = phrase.example, !example.isEmpty {
                Text(example)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(AppColor.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 32)
        .cornerMarks()
        .accessibilityElement(children: .combine)
    }
}
