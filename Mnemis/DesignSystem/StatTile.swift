import SwiftUI

/// Плитка с числом и подписью: «Due 12», «Streak 5».
struct StatTile: View {
    let title: LocalizedStringKey
    let value: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(value, format: .number)
                .font(.mnemisCounter)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.quaternary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
