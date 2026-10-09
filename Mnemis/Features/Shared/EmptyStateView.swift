import SwiftUI

/// Пустое состояние с понятным действием. Например: «Нет слов на повторение».
struct EmptyStateView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
