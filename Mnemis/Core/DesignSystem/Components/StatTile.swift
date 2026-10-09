import SwiftUI

/// Стеклянная плитка «моно-число и подпись»: «014 to review», «1/5 new today».
struct StatTile: View {
    let title: LocalizedStringKey
    let text: String
    var secondary: String?

    init(title: LocalizedStringKey, value: Int) {
        self.title = title
        self.text = value.formatted()
        self.secondary = nil
    }

    init(title: LocalizedStringKey, text: String, secondary: String? = nil) {
        self.title = title
        self.text = text
        self.secondary = secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                // Числа меняются плавно: цифры «прокручиваются», а не прыгают.
                Text(text)
                    .font(.mnemisCounter)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.4), value: text)
                if let secondary {
                    Text(secondary)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(AppColor.smoke)
                }
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppColor.ash)
        }
        .foregroundStyle(AppColor.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}
